import 'dart:io';

import 'package:path/path.dart' as p;

import '../../conversion/data/bridge/office_bridge.dart';
import '../domain/system_integration.dart';

/// "Enviar para" pela ponte PowerShell (WScript.Shell).
class WindowsSystemIntegration implements SystemIntegration {
  WindowsSystemIntegration(this._bridge, {String? sendToDir})
      : _sendToDir = sendToDir;

  static const shortcutName = 'Conversor de Arquivos.lnk';

  final OfficeBridge _bridge;
  final String? _sendToDir;

  String get _shortcutPath {
    final dir = _sendToDir ??
        p.join(
          Platform.environment['APPDATA'] ?? '',
          'Microsoft',
          'Windows',
          'SendTo',
        );
    return p.join(dir, shortcutName);
  }

  @override
  bool sendToShortcutExists() => File(_shortcutPath).existsSync();

  @override
  Future<void> installSendToShortcut(String executable) async {
    try {
      await _bridge.send('sendto', {'exe': executable});
    } finally {
      await _bridge.close();
    }
  }
}
