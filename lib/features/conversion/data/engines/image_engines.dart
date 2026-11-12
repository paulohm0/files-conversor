import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../../../core/path_utils.dart';
import '../../domain/contracts/conversion_engine.dart';
import '../../domain/contracts/repositories.dart';
import '../../domain/entities/conversion_result.dart';
import '../../domain/entities/engine_availability.dart';
import '../../domain/entities/file_category.dart';
import '../../domain/entities/target_format.dart';
import '../bridge/office_bridge.dart';
import '../codecs/image_codec.dart';

/// Converte, pelo WIC do Windows, uma imagem que o Dart não lê em um PNG
/// temporário.
abstract interface class WicImageReader {
  /// Devolve o caminho do PNG temporário; quem chama apaga.
  Future<String> toTemporaryPng(String path);
}

class BridgeWicImageReader implements WicImageReader {
  const BridgeWicImageReader(this._bridge);

  final OfficeBridge _bridge;

  @override
  Future<String> toTemporaryPng(String path) async {
    final temp = uniquePath(
      Directory.systemTemp.path,
      'conversor_wic_${DateTime.now().microsecondsSinceEpoch}',
      'png',
    );
    try {
      await _bridge.send('wic', {'in': path, 'out': temp});
    } on Object {
      deleteQuietly(temp);
      rethrow;
    }
    return temp;
  }
}

/// Entrega um caminho que o decodificador em Dart consegue ler: HEIC/HEIF
/// passam sempre pelo WIC; os demais só se a leitura em Dart falhar.
class ImageSourceResolver {
  const ImageSourceResolver(this._wic);

  static const wicOnlyExtensions = {'heic', 'heif'};

  final WicImageReader _wic;

  static bool needsWic(String path) =>
      wicOnlyExtensions.contains(extensionOf(path));

  Future<T> use<T>(
    String path,
    Future<T> Function(String readablePath) body,
  ) async {
    if (needsWic(path)) return _viaWic(path, body);
    try {
      return await body(path);
    } on ImageDecodeException {
      return _viaWic(path, body);
    }
  }

  /// Resolve vários caminhos de uma vez (modo juntar em PDF).
  Future<T> useAll<T>(
    List<String> paths,
    Future<T> Function(List<String> readablePaths) body,
  ) async {
    final temporaries = <String>[];
    try {
      final readable = <String>[];
      for (final path in paths) {
        if (needsWic(path)) {
          final temp = await _wic.toTemporaryPng(path);
          temporaries.add(temp);
          readable.add(temp);
        } else {
          readable.add(path);
        }
      }
      return await body(readable);
    } finally {
      temporaries.forEach(deleteQuietly);
    }
  }

  Future<T> _viaWic<T>(
    String path,
    Future<T> Function(String readablePath) body,
  ) async {
    final temp = await _wic.toTemporaryPng(path);
    try {
      return await body(temp);
    } finally {
      deleteQuietly(temp);
    }
  }
}

/// Imagem para PNG, JPG, BMP, GIF, TIFF ou ICO, em Dart puro.
class ImageEngine implements ConversionEngine {
  const ImageEngine(this._sources);

  final ImageSourceResolver _sources;

  @override
  String get name => nativeName;

  @override
  bool canConvert(ConversionRequest request, EngineAvailability engines) =>
      request.category == FileCategory.image && request.target.isRasterImage;

  @override
  Future<ConversionResult> convert(
    ConversionRequest request,
    EngineAvailability engines,
  ) async {
    final format = request.target.extension;
    final quality = request.options.jpgQuality;
    final output = request.output.allocate(format);
    await _sources.use(
      request.inputPath,
      (readable) => Isolate.run(
        () => convertImageFile(readable, output, format, quality),
      ),
    );
    return ConversionResult(outputs: [output]);
  }
}

/// Monta o PDF em um isolate.
class IsolateImagePdfWriter implements ImagePdfWriter {
  const IsolateImagePdfWriter(this._sources);

  final ImageSourceResolver _sources;

  @override
  Future<int> write(
    List<String> imagePaths,
    String outputPath, {
    required int jpgQuality,
  }) =>
      _sources.useAll(
        imagePaths,
        (readable) => Isolate.run(
          () => writeImagesPdf(readable, outputPath, jpgQuality),
        ),
      );
}

/// Uma imagem para um PDF A4 de uma página (ou uma por quadro).
class ImagePdfEngine implements ConversionEngine {
  const ImagePdfEngine(this._writer);

  final ImagePdfWriter _writer;

  @override
  String get name => nativeName;

  @override
  bool canConvert(ConversionRequest request, EngineAvailability engines) =>
      request.category == FileCategory.image &&
      request.target == TargetFormat.pdf;

  @override
  Future<ConversionResult> convert(
    ConversionRequest request,
    EngineAvailability engines,
  ) async {
    final output = request.output.allocate('pdf');
    await _writer.write(
      [request.inputPath],
      output,
      jpgQuality: request.options.jpgQuality,
    );
    return ConversionResult(outputs: [output], detail: p.basename(output));
  }
}
