import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/errors.dart';
import '../../../../core/process_runner.dart';
import '../../domain/contracts/conversion_engine.dart';
import '../../domain/entities/conversion_result.dart';
import '../../domain/entities/engine_availability.dart';
import '../../domain/entities/file_category.dart';
import '../../domain/entities/target_format.dart';

const _documentTargets = {
  TargetFormat.pdf,
  TargetFormat.docx,
  TargetFormat.doc,
  TargetFormat.odt,
  TargetFormat.rtf,
  TargetFormat.txt,
};
const _sheetTargets = {
  TargetFormat.pdf,
  TargetFormat.xlsx,
  TargetFormat.ods,
  TargetFormat.csv,
};
const _slideTargets = {TargetFormat.pdf, TargetFormat.pptx, TargetFormat.odp};

/// O par categoria/destino pertence à família de documentos de escritório?
bool isOfficeConversion(FileCategory category, TargetFormat target) =>
    switch (category) {
      FileCategory.document => _documentTargets.contains(target),
      FileCategory.sheet => _sheetTargets.contains(target),
      FileCategory.slides => _slideTargets.contains(target),
      FileCategory.pdf => target == TargetFormat.docx,
      FileCategory.image => false,
    };

/// `soffice --headless --convert-to`, com perfil próprio em %TEMP% para
/// funcionar mesmo com o LibreOffice aberto pelo usuário.
class LibreOfficeEngine implements ConversionEngine {
  const LibreOfficeEngine(
    this._runner, {
    this.timeout = const Duration(minutes: 5),
    String? tempDir,
  }) : _tempDir = tempDir;

  static const _filters = {
    TargetFormat.pdf: 'pdf',
    TargetFormat.docx: 'docx',
    TargetFormat.doc: 'doc',
    TargetFormat.odt: 'odt',
    TargetFormat.rtf: 'rtf',
    TargetFormat.txt: 'txt:Text (encoded):UTF8',
    TargetFormat.xlsx: 'xlsx',
    TargetFormat.ods: 'ods',
    TargetFormat.csv: 'csv:Text - txt - csv (StarCalc):44,34,76',
    TargetFormat.pptx: 'pptx',
    TargetFormat.odp: 'odp',
  };

  final ProcessRunner _runner;
  final Duration timeout;
  final String? _tempDir;

  String get _temp => _tempDir ?? Directory.systemTemp.path;

  @override
  String get name => EngineNames.libreOffice;

  @override
  bool canConvert(ConversionRequest request, EngineAvailability engines) =>
      engines.libreOffice &&
      isOfficeConversion(request.category, request.target);

  @override
  Future<ConversionResult> convert(
    ConversionRequest request,
    EngineAvailability engines,
  ) async {
    final output = request.output.allocate(request.target.extension);
    final workDir = Directory(_temp).createTempSync('conversor_');
    try {
      final profile = p.join(_temp, 'ConversorArquivos_LOProfile');
      final arguments = [
        '-env:UserInstallation=${Uri.file(profile, windows: true)}',
        '--headless',
        '--norestore',
        '--nologo',
        '--nodefault',
        '--nolockcheck',
        // PDF só vira DOCX pelo filtro de importação do Writer.
        if (request.category == FileCategory.pdf)
          '--infilter=writer_pdf_import',
        '--convert-to',
        _filters[request.target]!,
        '--outdir',
        workDir.path,
        request.inputPath,
      ];
      final result = await _runner.run(
        engines.libreOfficePath!,
        arguments,
        timeout: timeout,
      );
      final produced = workDir.listSync().whereType<File>().toList();
      if (produced.isEmpty) {
        final detail = '${result.stderr} ${result.stdout}'.trim();
        throw ConversionException(
          'O LibreOffice não gerou o arquivo. $detail'.trim(),
        );
      }
      // Copiar em vez de mover: %TEMP% e o destino podem estar em discos
      // diferentes.
      produced.first.copySync(output);
    } finally {
      try {
        workDir.deleteSync(recursive: true);
      } on FileSystemException {
        // Fica para a limpeza do Windows.
      }
    }
    return ConversionResult(outputs: [output], engineName: name);
  }
}

/// PDF para DOCX com a ferramenta `pdf2docx` (Python).
class Pdf2DocxEngine implements ConversionEngine {
  const Pdf2DocxEngine(
    this._runner, {
    this.timeout = const Duration(minutes: 10),
  });

  final ProcessRunner _runner;
  final Duration timeout;

  @override
  String get name => EngineNames.pdf2Docx;

  @override
  bool canConvert(ConversionRequest request, EngineAvailability engines) =>
      engines.pdf2Docx &&
      request.category == FileCategory.pdf &&
      request.target == TargetFormat.docx;

  @override
  Future<ConversionResult> convert(
    ConversionRequest request,
    EngineAvailability engines,
  ) async {
    final output = request.output.allocate('docx');
    final result = await _runner.run(
      engines.pdf2DocxPath!,
      ['convert', request.inputPath, output],
      timeout: timeout,
    );
    if (!File(output).existsSync()) {
      throw ConversionException('pdf2docx falhou. ${result.stderr}'.trim());
    }
    return ConversionResult(outputs: [output], engineName: name);
  }
}
