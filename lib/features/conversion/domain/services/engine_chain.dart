import '../../../../core/errors.dart';
import '../contracts/conversion_engine.dart';
import '../entities/conversion_result.dart';
import '../entities/engine_availability.dart';

/// Chamado quando um motor se declara inutilizável nesta sessão.
typedef EngineDisabledCallback = void Function(String engine, String reason);

/// Chain of Responsibility: tenta os motores na ordem; se um falha, apaga o
/// arquivo parcial e passa para o próximo; se todos falham, junta os erros.
class EngineChain {
  const EngineChain(this.engines);

  /// Motores em ordem de prioridade.
  final List<ConversionEngine> engines;

  /// Existe algum motor para este pedido?
  bool canConvert(ConversionRequest request, EngineAvailability available) =>
      engines.any((e) => e.canConvert(request, available));

  Future<ConversionResult> convert(
    ConversionRequest request,
    EngineAvailability available, {
    EngineDisabledCallback? onEngineDisabled,
  }) async {
    final errors = <String>[];
    var current = available;
    for (final engine in engines) {
      if (!engine.canConvert(request, current)) continue;
      try {
        final result = await engine.convert(request, current);
        if (!request.output.allOutputsValid) {
          throw const ConversionException('arquivo de saída não foi criado.');
        }
        return result;
      } on CancelledException {
        request.output.discardAll();
        rethrow;
      } on EngineUnavailableException catch (e) {
        request.output.discardAll();
        current = current.without(e.engineName);
        onEngineDisabled?.call(e.engineName, e.message);
        errors.add('${engine.name}: ${e.message}');
      } on Object catch (e) {
        request.output.discardAll();
        errors.add('${engine.name}: ${describeError(e)}');
      }
    }
    if (errors.isEmpty) {
      throw const ConversionException(
        'Nenhum motor disponível para esta conversão.',
      );
    }
    throw ConversionException(errors.join(' | '));
  }
}
