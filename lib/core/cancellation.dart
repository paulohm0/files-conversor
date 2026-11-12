import 'errors.dart';

/// Sinal de cancelamento cooperativo: quem executa consulta entre etapas.
class CancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw const CancelledException();
  }
}
