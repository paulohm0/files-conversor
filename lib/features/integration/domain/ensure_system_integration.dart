import '../../../core/errors.dart';
import 'system_integration.dart';

/// Mantém o "Enviar para" sempre instalado.
class EnsureSystemIntegration {
  const EnsureSystemIntegration(this._system, {required this.executable});

  final SystemIntegration _system;

  /// Caminho do executável atual.
  final String executable;

  /// O "Enviar para" é obrigatório: recria se faltar ou se o app mudou de
  /// pasta desde a última instalação ([installedTarget]). Devolve o novo
  /// destino gravado, ou `null` se nada mudou.
  Future<({String? newTarget, String? message})> ensureSendTo(
    String installedTarget,
  ) async {
    final current = _system.sendToShortcutExists() &&
        installedTarget.toLowerCase() == executable.toLowerCase();
    if (current) return (newTarget: null, message: null);
    try {
      await _system.installSendToShortcut(executable);
      return (
        newTarget: executable,
        message: 'Atalho "Enviar para → Conversor de Arquivos" instalado.',
      );
    } on Object catch (e) {
      return (
        newTarget: null,
        message: 'Não foi possível criar o atalho "Enviar para": '
            '${describeError(e)}',
      );
    }
  }
}
