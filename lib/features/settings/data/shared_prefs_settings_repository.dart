import 'package:shared_preferences/shared_preferences.dart';

import '../../conversion/domain/entities/target_format.dart';
import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

class SharedPrefsSettingsRepository implements SettingsRepository {
  const SharedPrefsSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _jpgPreset = 'jpgPreset';
  static const _dpiPreset = 'dpiPreset';
  static const _merge = 'mergeImages';
  static const _otherFolder = 'useOtherFolder';
  static const _outputDir = 'outputDir';
  static const _openFolder = 'openFolderWhenDone';
  static const _deleteOriginal = 'deleteOriginal';
  static const _lastTarget = 'lastTarget';
  static const _confirm = 'confirmBeforeConvert';
  static const _showLog = 'showLog';
  static const _showOptions = 'showOptions';
  static const _startWithWindows = 'startWithWindows';
  static const _sendToTarget = 'sendToTarget';

  @override
  Future<AppSettings> load() async {
    const d = AppSettings();
    return AppSettings(
      jpgPreset: (_prefs.getInt(_jpgPreset) ?? d.jpgPreset).clamp(0, 2),
      dpiPreset: (_prefs.getInt(_dpiPreset) ?? d.dpiPreset).clamp(0, 2),
      mergeImages: _prefs.getBool(_merge) ?? d.mergeImages,
      useOtherFolder: _prefs.getBool(_otherFolder) ?? d.useOtherFolder,
      outputDir: _prefs.getString(_outputDir) ?? d.outputDir,
      openFolderWhenDone: _prefs.getBool(_openFolder) ?? d.openFolderWhenDone,
      deleteOriginal: _prefs.getBool(_deleteOriginal) ?? d.deleteOriginal,
      lastTarget:
          TargetFormat.fromName(_prefs.getString(_lastTarget)) ?? d.lastTarget,
      confirmBeforeConvert: _prefs.getBool(_confirm) ?? d.confirmBeforeConvert,
      showLog: _prefs.getBool(_showLog) ?? d.showLog,
      showOptions: _prefs.getBool(_showOptions) ?? d.showOptions,
      startWithWindows:
          _prefs.getBool(_startWithWindows) ?? d.startWithWindows,
      sendToTarget: _prefs.getString(_sendToTarget) ?? d.sendToTarget,
    );
  }

  @override
  Future<void> save(AppSettings s) async {
    await Future.wait([
      _prefs.setInt(_jpgPreset, s.jpgPreset),
      _prefs.setInt(_dpiPreset, s.dpiPreset),
      _prefs.setBool(_merge, s.mergeImages),
      _prefs.setBool(_otherFolder, s.useOtherFolder),
      _prefs.setString(_outputDir, s.outputDir),
      _prefs.setBool(_openFolder, s.openFolderWhenDone),
      _prefs.setBool(_deleteOriginal, s.deleteOriginal),
      _prefs.setString(_lastTarget, s.lastTarget.name),
      _prefs.setBool(_confirm, s.confirmBeforeConvert),
      _prefs.setBool(_showLog, s.showLog),
      _prefs.setBool(_showOptions, s.showOptions),
      _prefs.setBool(_startWithWindows, s.startWithWindows),
      _prefs.setString(_sendToTarget, s.sendToTarget),
    ]);
  }
}
