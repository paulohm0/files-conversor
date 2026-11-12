import 'dart:async';

import '../../conversion/presentation/cubit/conversion_cubit.dart';
import '../../settings/presentation/settings_cubit.dart';
import '../domain/ensure_system_integration.dart';

/// Ao abrir o app: garante o "Enviar para" e ajusta a inicialização com o
/// Windows. Depois, acompanha a opção "Iniciar com o Windows".
/// As mensagens vão para o registro (log) da tela.
class SystemIntegrationSync {
  SystemIntegrationSync(this._ensure, this._settings, this._conversion);

  final EnsureSystemIntegration _ensure;
  final SettingsCubit _settings;
  final ConversionCubit _conversion;
  StreamSubscription<bool>? _subscription;

  Future<void> start() async {
    final sendTo = await _ensure.ensureSendTo(_settings.state.sendToTarget);
    final target = sendTo.newTarget;
    if (target != null) {
      await _settings.update((s) => s.copyWith(sendToTarget: target));
    }
    _log(sendTo.message, isError: target == null);

    _log(_ensure.syncStartup(enabled: _settings.state.startWithWindows));
    _subscription = _settings.stream
        .map((s) => s.startWithWindows)
        .distinct()
        .listen((enabled) => _log(_ensure.syncStartup(enabled: enabled)));
  }

  Future<void> dispose() async => _subscription?.cancel();

  void _log(String? message, {bool isError = false}) {
    if (message == null) return;
    _conversion.addLog(
      message,
      isError: isError || message.startsWith('Não foi possível'),
    );
  }
}
