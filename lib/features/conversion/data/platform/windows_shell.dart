import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:win32/win32.dart';

import '../../domain/contracts/repositories.dart';
import '../bridge/office_bridge.dart';

/// Lixeira do Windows via `SHFileOperation` com `FOF_ALLOWUNDO`: o arquivo
/// fica recuperável. Sem `FOF_ALLOWUNDO` seria exclusão permanente, então a
/// flag nunca é opcional aqui.
class WindowsRecycleBin implements RecycleBin {
  const WindowsRecycleBin();

  @override
  Future<bool> moveToRecycleBin(String path) async {
    if (!File(path).existsSync()) return false;
    // pFrom é uma lista terminada por dois nulos.
    final units = '$path\u0000\u0000'.codeUnits;
    final from = calloc<Uint16>(units.length);
    final operation = calloc<SHFILEOPSTRUCT>();
    try {
      from.asTypedList(units.length).setAll(0, units);
      operation.ref
        ..wFunc = FO_DELETE
        ..pFrom = from.cast<Utf16>()
        ..fFlags = FOF_ALLOWUNDO |
            FOF_NOCONFIRMATION |
            FOF_SILENT |
            FOF_NOERRORUI;
      final status = SHFileOperation(operation);
      final aborted = operation.ref.fAnyOperationsAborted != 0;
      return status == 0 && !aborted && !File(path).existsSync();
    } finally {
      calloc
        ..free(from)
        ..free(operation);
    }
  }
}

class WindowsShellIntegration implements ShellIntegration {
  const WindowsShellIntegration(this._bridge);

  final OfficeBridge _bridge;

  @override
  Future<void> revealInExplorer(String path) async {
    await Process.start('explorer.exe', ['/select,$path']);
  }

  @override
  Future<void> openFolder(String path) async {
    await Process.start('explorer.exe', [path]);
  }

  @override
  Future<void> installSendToShortcut() async {
    try {
      await _bridge.send('sendto', {'exe': Platform.resolvedExecutable});
    } finally {
      await _bridge.close();
    }
  }
}

/// Arquivos copiados no Explorer, lidos pelo pacote super_clipboard.
class SuperClipboardFiles implements ClipboardFiles {
  const SuperClipboardFiles();

  @override
  Future<List<String>> readFilePaths() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return const [];
    final reader = await clipboard.read();
    final paths = <String>[];
    for (final item in reader.items) {
      if (!item.canProvide(Formats.fileUri)) continue;
      final uri = await item.readValue(Formats.fileUri);
      if (uri != null) paths.add(uri.toFilePath(windows: true));
    }
    return paths;
  }
}
