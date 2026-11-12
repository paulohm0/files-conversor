import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

/// Opções da tela, gravadas a cada mudança.
class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit(this._repository, {AppSettings initial = const AppSettings()})
      : super(initial);

  final SettingsRepository _repository;

  Future<void> load() async => emit(await _repository.load());

  Future<void> update(AppSettings Function(AppSettings current) change) async {
    final next = change(state);
    if (next == state) return;
    emit(next);
    await _repository.save(next);
  }
}
