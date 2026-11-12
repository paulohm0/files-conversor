import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../../../../core/errors.dart';
import '../../domain/contracts/repositories.dart';
import '../../domain/entities/engine_availability.dart';

/// Ponte para o que só existe via COM/WIC: Word, Excel, PowerPoint, Acrobat,
/// leitura de HEIC e o atalho "Enviar para".
abstract interface class OfficeBridge implements EngineSession {
  /// Executa uma ação e devolve os dados da resposta.
  Future<Map<String, Object?>> send(String action, [Map<String, Object?> args]);
}

/// Onde está o `office_bridge.ps1` embutido como asset.
abstract interface class BridgeScriptLocator {
  Future<String> locate();
}

class AssetBridgeScriptLocator implements BridgeScriptLocator {
  String? _cached;

  @override
  Future<String> locate() async {
    final cached = _cached;
    if (cached != null && File(cached).existsSync()) return cached;

    // No Windows os assets são arquivos ao lado do executável.
    final bundled = p.join(
      p.dirname(Platform.resolvedExecutable),
      'data',
      'flutter_assets',
      'assets',
      'office_bridge.ps1',
    );
    if (File(bundled).existsSync()) return _cached = bundled;

    // Em desenvolvimento/teste: extrai o asset para a pasta temporária.
    // Em bytes, para preservar o BOM UTF-8 que o PowerShell 5.1 exige.
    final script = await rootBundle.load('assets/office_bridge.ps1');
    final extracted = File(
      p.join(Directory.systemTemp.path, 'ConversorArquivos_office_bridge.ps1'),
    );
    await extracted.writeAsBytes(
      script.buffer.asUint8List(script.offsetInBytes, script.lengthInBytes),
      flush: true,
    );
    return _cached = extracted.path;
  }
}

/// Mantém um PowerShell 5.1 (STA) vivo durante o lote, para reaproveitar as
/// instâncias do Office. A conversa é por arquivos numa pasta temporária
/// (`req_N.json` / `resp_N.json`): o stdin do PowerShell 5.1 iniciado pelo
/// Dart entrega só a primeira linha, então não serve como canal.
class PowerShellOfficeBridge implements OfficeBridge {
  PowerShellOfficeBridge(
    this._locator, {
    this.callTimeout = const Duration(minutes: 10),
    this.pollInterval = const Duration(milliseconds: 40),
  });

  static const acrobatBrokenCode = 'ACROBAT_BROKEN';

  final BridgeScriptLocator _locator;
  final Duration callTimeout;
  final Duration pollInterval;

  Process? _process;
  Directory? _mailbox;
  int _next = 1;
  bool _exited = false;
  Future<void> _queue = Future.value();

  @override
  Future<Map<String, Object?>> send(
    String action, [
    Map<String, Object?> args = const {},
  ]) {
    // Um pedido por vez: a ponte processa na ordem dos números.
    final completer = Completer<Map<String, Object?>>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await _send(action, args));
      } on Object catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  Future<Map<String, Object?>> _send(
    String action,
    Map<String, Object?> args,
  ) async {
    await _ensureStarted();
    final number = _next++;
    _writeRequest(number, {'action': action, ...args});

    final Map<String, Object?> response;
    try {
      response = await _awaitResponse(number).timeout(callTimeout);
    } on TimeoutException {
      _kill();
      throw ConversionException('Tempo esgotado (${callTimeout.inSeconds} s).');
    }
    if (response['ok'] == true) {
      final data = response['data'];
      return data is Map ? data.cast<String, Object?>() : const {};
    }
    final message =
        (response['error'] as String?) ?? 'Falha na ponte PowerShell.';
    if (response['code'] == acrobatBrokenCode) {
      throw EngineUnavailableException(EngineNames.acrobat, message);
    }
    throw ConversionException(message);
  }

  void _writeRequest(int number, Map<String, Object?> request) {
    final dir = _mailbox!.path;
    final tmp = File(p.join(dir, 'req_$number.tmp'))
      ..writeAsStringSync(jsonEncode(request), flush: true);
    tmp.renameSync(p.join(dir, 'req_$number.json'));
  }

  Future<Map<String, Object?>> _awaitResponse(int number) async {
    final file = File(p.join(_mailbox!.path, 'resp_$number.json'));
    while (!file.existsSync()) {
      if (_exited) {
        _kill();
        throw const ConversionException(
          'A ponte PowerShell encerrou inesperadamente.',
        );
      }
      await Future<void>.delayed(pollInterval);
    }
    final text = file.readAsStringSync();
    try {
      file.deleteSync();
    } on FileSystemException {
      // A pasta inteira é apagada no fim.
    }
    return (jsonDecode(text) as Map).cast<String, Object?>();
  }

  Future<void> _ensureStarted() async {
    if (_process != null) return;

    final script = await _locator.locate();
    final mailbox = _mailbox =
        Directory.systemTemp.createTempSync('conversor_ponte_');
    _next = 1;
    _exited = false;
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final powershell = p.join(
      systemRoot,
      'System32',
      'WindowsPowerShell',
      'v1.0',
      'powershell.exe',
    );
    final process = await Process.start(powershell, [
      '-NoProfile',
      '-NonInteractive',
      '-STA',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      script,
      '-Mailbox',
      mailbox.path,
      '-ParentPid',
      '$pid',
    ]);
    // Drena as saídas para o processo nunca bloquear por buffer cheio.
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    unawaited(process.exitCode.then((_) {
      if (identical(_process, process)) _exited = true;
    }));
    _process = process;
  }

  /// Pede para a ponte fechar os aplicativos (só os que não têm documentos
  /// do usuário abertos) e encerra o processo.
  @override
  Future<void> close() {
    final done = _queue.then((_) async {
      final process = _process;
      if (process == null) return;
      try {
        _writeRequest(_next++, const {'action': 'close'});
        await process.exitCode.timeout(const Duration(seconds: 60));
      } on Object {
        process.kill();
      } finally {
        _process = null;
        _deleteMailbox();
      }
    });
    _queue = done.catchError((Object _) {});
    return done;
  }

  void _kill() {
    _process?.kill();
    _process = null;
    _deleteMailbox();
  }

  void _deleteMailbox() {
    try {
      _mailbox?.deleteSync(recursive: true);
    } on FileSystemException {
      // Fica para a limpeza do Windows.
    }
    _mailbox = null;
  }
}
