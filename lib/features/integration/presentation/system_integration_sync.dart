import '../../conversion/presentation/cubit/conversion_cubit.dart';
import '../../settings/presentation/settings_cubit.dart';
import '../domain/ensure_system_integration.dart';

/// Ao abrir o app, garante o atalho "Enviar para" e registra no log o que
/// foi feito.
class SystemIntegrationSync {
  const SystemIntegrationSync(this._ensure, this._settings, this._conversion);

  final EnsureSystemIntegration _ensure;
  final SettingsCubit _settings;
  final ConversionCubit _conversion;

  Future<void> start() async {
    final result = await _ensure.ensureSendTo(_settings.state.sendToTarget);
    final target = result.newTarget;
    if (target != null) {
      await _settings.update((s) => s.copyWith(sendToTarget: target));
    }
    final message = result.message;
    if (message != null) _conversion.addLog(message, isError: target == null);
  }
}
