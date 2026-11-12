import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'errors.dart';

class ProcessOutput {
  const ProcessOutput(this.exitCode, this.stdout, this.stderr);

  final int exitCode;
  final String stdout;
  final String stderr;
}

/// Executa programas externos. Abstraído para os motores serem testáveis.
abstract interface class ProcessRunner {
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    Duration timeout,
  });
}

class SystemProcessRunner implements ProcessRunner {
  const SystemProcessRunner();

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final process = await Process.start(executable, arguments);
    final stdout = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .join();
    final stderr = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .join();
    final int exitCode;
    try {
      exitCode = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill();
      throw ConversionException('Tempo esgotado (${timeout.inSeconds} s).');
    }
    return ProcessOutput(exitCode, await stdout, await stderr);
  }
}
