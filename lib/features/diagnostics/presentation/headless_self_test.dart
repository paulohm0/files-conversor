import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/di.dart';
import '../../conversion/domain/contracts/repositories.dart';
import '../../conversion/domain/usecases/convert_files.dart';
import '../../conversion/domain/usecases/get_available_targets.dart';
import '../data/file_sample_factory.dart';
import '../domain/diagnostic_models.dart';
import '../domain/run_diagnostics.dart';

/// Roda o autoteste sem interface (`conversor_arquivos.exe --autoteste`).
/// O relatório fica na pasta do teste e o caminho dela é gravado em
/// `ultimo_autoteste.txt` dentro de [baseDir] (ou da pasta temporária).
/// Devolve 0 se tudo deu certo, 1 se alguma conversão falhou.
Future<int> runHeadlessSelfTest(String? baseDir) async {
  final base = baseDir ?? Directory.systemTemp.path;
  Directory(base).createSync(recursive: true);
  final log = File(p.join(base, 'ultimo_autoteste.txt'))..writeAsStringSync('');
  void write(String line) =>
      log.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);

  final engines = await sl<EngineDetector>().detect();
  final run = RunDiagnostics(
    convertFiles: sl<ConvertFiles>(),
    getTargets: sl<GetAvailableTargets>(),
    samples: FileSampleFactory(sl()),
    tempDir: base,
  );
  var errors = 0;
  try {
    await for (final event in run(engines)) {
      switch (event) {
        case DiagnosticMessage(:final text):
          write(text);
        case DiagnosticRowAdded(:final row):
          if (row.outcome == DiagnosticOutcome.error) errors++;
          write(
            '[${row.outcome.label}] ${row.test} ${row.input} -> '
            '${row.output} ${row.detail}',
          );
        case DiagnosticFinished(:final reportPath):
          write('RELATORIO $reportPath');
      }
    }
  } on Object catch (e, s) {
    write('FALHA INTERNA: $e\n$s');
    return 2;
  }
  write('FIM erros=$errors');
  return errors == 0 ? 0 : 1;
}
