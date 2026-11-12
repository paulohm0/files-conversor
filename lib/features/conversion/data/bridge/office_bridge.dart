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
/// instâncias do Office. Protocolo: uma linha base64(JSON UTF-8) por pedido e
/// uma linha `@@base64(JSON)` por resposta.
class PowerShellOfficeBridge implements OfficeBridge {
  PowerShellOfficeBridge(
    this._locator, {
    this.callTimeout = const Duration(minutes: 10),
  });

  static const acrobatBrokenCode = 'ACROBAT_BROKEN';
  static const _marker = '@@';

  final BridgeScriptLocator _locator;
  final Duration callTimeout;

  Process? _process;
  StreamIterator<String>? _lines;
  Future<void> _queue = Future.value();

  @override
  Future<Map<String, Object?>> send(
    String action, [
    Map<String, Object?> args = const {},
  ]) {
    // Um pedido por vez: o processo responde na ordem em que recebe.
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
    final process = await _ensureStarted();
    final payload = base64.encode(utf8.encode(jsonEncode({'action': action, ...args})));
    process.stdin.writeln(payload);
    await process.stdin.flush();

    final Map<String, Object?> response;
    try {
      response = await _readResponse().timeout(callTimeout);
    } on TimeoutException {
      _kill();
      throw ConversionException('Tempo esgotado (${callTimeout.inSeconds} s).');
    }
    if (response['ok'] == true) {
      final data = response['data'];
      return data is Map<String, Object?> ? data : const {};
    }
    final message = (response['error'] as String?) ?? 'Falha na ponte PowerShell.';
    if (response['code'] == acrobatBrokenCode) {
      throw EngineUnavailableException(EngineNames.acrobat, message);
    }
    throw ConversionException(message);
  }

  Future<Map<String, Object?>> _readResponse() async {
    final lines = _lines!;
    while (await lines.moveNext()) {
      final line = lines.current.trim();
      if (!line.startsWith(_marker)) continue;
      final json = utf8.decode(base64.decode(line.substring(_marker.length)));
      return (jsonDecode(json) as Map).cast<String, Object?>();
    }
    _kill();
    throw const ConversionException(
      'A ponte PowerShell encerrou inesperadamente.',
    );
  }

  Future<Process> _ensureStarted() async {
    final existing = _process;
    if (existing != null) return existing;

    final script = await _locator.locate();
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
    ]);
    // Drena o stderr para o processo nunca bloquear por buffer cheio.
    unawaited(process.stderr.drain<void>());
    _lines = StreamIterator(
      process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter()),
    );
    return _process = process;
  }

  /// Pede para a ponte fechar os aplicativos (só os que não têm documentos
  /// do usuário abertos) e encerra o processo.
  @override
  Future<void> close() {
    final done = _queue.then((_) async {
      final process = _process;
      if (process == null) return;
      try {
        process.stdin.writeln(
          base64.encode(utf8.encode(jsonEncode({'action': 'close'}))),
        );
        await process.stdin.flush();
        await process.stdin.close();
        await process.exitCode.timeout(const Duration(seconds: 30));
      } on Object {
        process.kill();
      } finally {
        await _lines?.cancel();
        _lines = null;
        _process = null;
      }
    });
    _queue = done.catchError((Object _) {});
    return done;
  }

  void _kill() {
    _process?.kill();
    unawaited(_lines?.cancel());
    _lines = null;
    _process = null;
  }
}
