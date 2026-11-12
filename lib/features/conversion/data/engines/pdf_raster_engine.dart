import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import '../../../../core/errors.dart';
import '../../domain/contracts/conversion_engine.dart';
import '../../domain/entities/conversion_result.dart';
import '../../domain/entities/engine_availability.dart';
import '../../domain/entities/file_category.dart';
import '../../domain/entities/target_format.dart';
import '../codecs/image_codec.dart';

/// Página renderizada em pixels BGRA.
class RenderedPage {
  const RenderedPage(this.bgra, this.width, this.height);

  final Uint8List bgra;
  final int width;
  final int height;
}

/// Um PDF aberto para renderização.
abstract interface class PdfRenderSession {
  int get pageCount;

  Future<RenderedPage> render(int pageIndex, int dpi);

  Future<void> close();
}

abstract interface class PdfRenderer {
  Future<PdfRenderSession> open(String path);
}

/// Renderização com PDFium (pacote pdfrx).
class PdfrxRenderer implements PdfRenderer {
  const PdfrxRenderer();

  @override
  Future<PdfRenderSession> open(String path) async {
    try {
      return _PdfrxSession(await PdfDocument.openFile(path));
    } on Object {
      throw const ConversionException(
        'Não foi possível abrir o PDF '
        '(pode estar protegido por senha ou corrompido).',
      );
    }
  }
}

class _PdfrxSession implements PdfRenderSession {
  _PdfrxSession(this._document);

  final PdfDocument _document;

  @override
  int get pageCount => _document.pages.length;

  @override
  Future<RenderedPage> render(int pageIndex, int dpi) async {
    final page = _document.pages[pageIndex];
    // O tamanho da página vem em pontos (72 por polegada).
    final width = math.max(1, (page.width * dpi / 72).round());
    final height = math.max(1, (page.height * dpi / 72).round());
    final image = await page.render(
      width: width,
      height: height,
      fullWidth: width.toDouble(),
      fullHeight: height.toDouble(),
      backgroundColor: 0xFFFFFFFF,
    );
    if (image == null) {
      throw ConversionException(
        'Não foi possível renderizar a página ${pageIndex + 1}.',
      );
    }
    try {
      return RenderedPage(
        Uint8List.fromList(image.pixels),
        image.width,
        image.height,
      );
    } finally {
      image.dispose();
    }
  }

  @override
  Future<void> close() => _document.dispose();
}

/// PDF para PNG ou JPG, uma imagem por página: `nome_pagina01.ext`.
class PdfRasterEngine implements ConversionEngine {
  const PdfRasterEngine(this._renderer);

  final PdfRenderer _renderer;

  @override
  String get name => nativeName;

  @override
  bool canConvert(ConversionRequest request, EngineAvailability engines) =>
      engines.nativePdf &&
      request.category == FileCategory.pdf &&
      (request.target == TargetFormat.png ||
          request.target == TargetFormat.jpg);

  @override
  Future<ConversionResult> convert(
    ConversionRequest request,
    EngineAvailability engines,
  ) async {
    final format = request.target.extension;
    final quality = request.options.jpgQuality;
    final session = await _renderer.open(request.inputPath);
    try {
      final count = session.pageCount;
      final digits = math.max(2, '$count'.length);
      final outputs = <String>[];
      for (var i = 0; i < count; i++) {
        // Ao cancelar, quem chamou apaga as páginas já gravadas.
        request.cancel.throwIfCancelled();
        final page = await session.render(i, request.options.dpi);
        final output = request.output.allocate(
          format,
          suffix: '_pagina${'${i + 1}'.padLeft(digits, '0')}',
        );
        final bytes = await Isolate.run(
          () => encodeBgraPage(
            page.bgra,
            page.width,
            page.height,
            format,
            quality,
          ),
        );
        await File(output).writeAsBytes(bytes, flush: true);
        outputs.add(output);
      }
      return ConversionResult(outputs: outputs, detail: '$count página(s)');
    } finally {
      await session.close();
    }
  }
}
