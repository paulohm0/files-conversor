import '../../../../core/errors.dart';
import '../../domain/contracts/conversion_engine.dart';
import '../../domain/entities/conversion_result.dart';
import '../../domain/entities/engine_availability.dart';
import '../../domain/entities/file_category.dart';
import '../../domain/entities/target_format.dart';
import '../bridge/office_bridge.dart';
import 'external_engines.dart';

/// Base dos motores que convertem pela ponte PowerShell (COM).
abstract class _BridgeEngine implements ConversionEngine {
  const _BridgeEngine(this._bridge);

  final OfficeBridge _bridge;

  /// Ação da ponte (`word`, `excel`, `powerpoint`, `acrobat`).
  String get action;

  @override
  Future<ConversionResult> convert(
    ConversionRequest request,
    EngineAvailability engines,
  ) async {
    final output = request.output.allocate(request.target.extension);
    await _bridge.send(action, {
      'in': request.inputPath,
      'out': output,
      'fmt': request.target.extension,
    });
    return ConversionResult(outputs: [output], engineName: name);
  }
}

/// Microsoft Word: documentos e PDF para DOCX.
class WordEngine extends _BridgeEngine {
  const WordEngine(super.bridge);

  @override
  String get name => EngineNames.word;

  @override
  String get action => 'word';

  @override
  bool canConvert(ConversionRequest request, EngineAvailability engines) =>
      engines.word &&
      (request.category == FileCategory.document ||
          request.category == FileCategory.pdf) &&
      isOfficeConversion(request.category, request.target);
}

/// Microsoft Excel: planilhas.
class ExcelEngine extends _BridgeEngine {
  const ExcelEngine(super.bridge);

  @override
  String get name => EngineNames.excel;

  @override
  String get action => 'excel';

  @override
  bool canConvert(ConversionRequest request, EngineAvailability engines) =>
      engines.excel &&
      request.category == FileCategory.sheet &&
      isOfficeConversion(request.category, request.target);
}

/// Microsoft PowerPoint: apresentações.
class PowerPointEngine extends _BridgeEngine {
  const PowerPointEngine(super.bridge);

  @override
  String get name => EngineNames.powerPoint;

  @override
  String get action => 'powerpoint';

  @override
  bool canConvert(ConversionRequest request, EngineAvailability engines) =>
      engines.powerPoint &&
      request.category == FileCategory.slides &&
      isOfficeConversion(request.category, request.target);
}

/// Adobe Acrobat Pro/Standard: PDF para DOCX, XLSX e PPTX. Se a automação
/// falhar uma vez, o motor fica desativado até o app fechar.
class AcrobatEngine extends _BridgeEngine {
  AcrobatEngine(super.bridge);

  static const _targets = {
    TargetFormat.docx,
    TargetFormat.xlsx,
    TargetFormat.pptx,
  };

  String? _brokenReason;

  @override
  String get name => EngineNames.acrobat;

  @override
  String get action => 'acrobat';

  @override
  bool canConvert(ConversionRequest request, EngineAvailability engines) =>
      engines.acrobat &&
      request.category == FileCategory.pdf &&
      _targets.contains(request.target);

  @override
  Future<ConversionResult> convert(
    ConversionRequest request,
    EngineAvailability engines,
  ) async {
    final reason = _brokenReason;
    if (reason != null) throw EngineUnavailableException(name, reason);
    try {
      return await super.convert(request, engines);
    } on EngineUnavailableException catch (e) {
      _brokenReason = e.message;
      rethrow;
    }
  }
}
