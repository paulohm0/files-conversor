import '../../../../core/cancellation.dart';
import '../entities/conversion_options.dart';
import '../entities/conversion_result.dart';
import '../entities/engine_availability.dart';
import '../entities/file_category.dart';
import '../entities/target_format.dart';
import '../services/output_allocator.dart';

/// Pedido de conversão de um único arquivo.
class ConversionRequest {
  ConversionRequest({
    required this.inputPath,
    required this.category,
    required this.options,
    required this.output,
    CancellationToken? cancel,
  }) : cancel = cancel ?? CancellationToken();

  final String inputPath;
  final FileCategory category;
  final ConversionOptions options;
  final OutputAllocator output;
  final CancellationToken cancel;

  TargetFormat get target => options.target;
}

/// Strategy: cada motor sabe o que converte e como.
abstract interface class ConversionEngine {
  /// Nome para o log. Motores nativos usam [nativeName].
  String get name;

  /// O motor aceita este pedido com o que está instalado?
  bool canConvert(ConversionRequest request, EngineAvailability engines);

  /// Converte e devolve os arquivos gerados. Lança em caso de falha; os
  /// arquivos parciais são apagados por quem chamou, via [OutputAllocator].
  Future<ConversionResult> convert(
    ConversionRequest request,
    EngineAvailability engines,
  );
}

const nativeName = 'Nativo';
