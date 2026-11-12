import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

import '../../conversion/data/bridge/office_bridge.dart';
import '../domain/system_integration.dart';

/// "Enviar para" pela ponte PowerShell (WScript.Shell) e inicialização pela
/// chave Run do usuário (HKCU), que não exige administrador.
class WindowsSystemIntegration implements SystemIntegration {
  WindowsSystemIntegration(this._bridge, {String? sendToDir})
      : _sendToDir = sendToDir;

  static const runKey = r'Software\Microsoft\Windows\CurrentVersion\Run';
  static const runValue = 'ConversorArquivos';
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

  @override
  String? startupCommand() {
    final key = runKey.toNativeUtf16();
    final name = runValue.toNativeUtf16();
    final size = calloc<DWORD>();
    try {
      var status = RegGetValue(
        HKEY_CURRENT_USER,
        key,
        name,
        RRF_RT_REG_SZ,
        nullptr,
        nullptr,
        size,
      );
      if (status != ERROR_SUCCESS || size.value == 0) return null;
      final buffer = calloc<Uint8>(size.value);
      try {
        status = RegGetValue(
          HKEY_CURRENT_USER,
          key,
          name,
          RRF_RT_REG_SZ,
          nullptr,
          buffer.cast(),
          size,
        );
        if (status != ERROR_SUCCESS) return null;
        return buffer.cast<Utf16>().toDartString();
      } finally {
        calloc.free(buffer);
      }
    } finally {
      calloc
        ..free(key)
        ..free(name)
        ..free(size);
    }
  }

  @override
  void registerStartup(String command) {
    _withRunKey((hKey) {
      final name = runValue.toNativeUtf16();
      final data = command.toNativeUtf16();
      try {
        final bytes = (command.length + 1) * 2;
        final status =
            RegSetValueEx(hKey, name, 0, REG_SZ, data.cast(), bytes);
        if (status != ERROR_SUCCESS) {
          throw WindowsException(status);
        }
      } finally {
        calloc
          ..free(name)
          ..free(data);
      }
    });
  }

  @override
  void unregisterStartup() {
    _withRunKey((hKey) {
      final name = runValue.toNativeUtf16();
      try {
        final status = RegDeleteValue(hKey, name);
        if (status != ERROR_SUCCESS && status != ERROR_FILE_NOT_FOUND) {
          throw WindowsException(status);
        }
      } finally {
        calloc.free(name);
      }
    });
  }

  void _withRunKey(void Function(int hKey) body) {
    final key = runKey.toNativeUtf16();
    final handle = calloc<HKEY>();
    try {
      final status = RegOpenKeyEx(
        HKEY_CURRENT_USER,
        key,
        0,
        KEY_SET_VALUE | KEY_QUERY_VALUE,
        handle,
      );
      if (status != ERROR_SUCCESS) throw WindowsException(status);
      try {
        body(handle.value);
      } finally {
        RegCloseKey(handle.value);
      }
    } finally {
      calloc
        ..free(key)
        ..free(handle);
    }
  }
}
