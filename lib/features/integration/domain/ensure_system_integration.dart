import '../../../core/errors.dart';
import 'system_integration.dart';

/// Argumento passado pelo registro de inicialização: abre minimizado.
const startupArgument = '--minimizado';

/// Mantém o "Enviar para" sempre instalado e o registro de inicialização de
/// acordo com a opção do usuário. Devolve mensagens para o registro (log).
class EnsureSystemIntegration {
  const EnsureSystemIntegration(this._system, {required this.executable});

  final SystemIntegration _system;

  /// Caminho do executável atual.
  final String executable;

  String get startupCommandLine => '"$executable" $startupArgument';

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

  /// Liga ou desliga a inicialização com o Windows. Devolve a mensagem para
  /// o log quando algo mudou.
  String? syncStartup({required bool enabled}) {
    try {
      final registered = _system.startupCommand();
      if (enabled) {
        if (registered == startupCommandLine) return null;
        _system.registerStartup(startupCommandLine);
        return 'O Conversor vai abrir minimizado junto com o Windows.';
      }
      if (registered == null) return null;
      _system.unregisterStartup();
      return 'O Conversor não abre mais junto com o Windows.';
    } on Object catch (e) {
      return 'Não foi possível ajustar a inicialização com o Windows: '
          '${describeError(e)}';
    }
  }
}
