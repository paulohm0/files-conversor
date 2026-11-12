import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/cancellation.dart';
import '../../../core/errors.dart';
import '../../../core/path_utils.dart';
import '../../conversion/domain/entities/conversion_job.dart';
import '../../conversion/domain/entities/conversion_options.dart';
import '../../conversion/domain/entities/engine_availability.dart';
import '../../conversion/domain/entities/file_category.dart';
import '../../conversion/domain/entities/target_format.dart';
import '../../conversion/domain/usecases/convert_files.dart';
import '../../conversion/domain/usecases/get_available_targets.dart';
import 'diagnostic_models.dart';

sealed class DiagnosticEvent {
  const DiagnosticEvent();
}

class DiagnosticMessage extends DiagnosticEvent {
  const DiagnosticMessage(this.text);

  final String text;
}

class DiagnosticRowAdded extends DiagnosticEvent {
  const DiagnosticRowAdded(this.row);

  final DiagnosticRow row;
}

class DiagnosticFinished extends DiagnosticEvent {
  const DiagnosticFinished({required this.folder, required this.reportPath});

  final String folder;
  final String reportPath;
}

/// Autoteste: cria arquivos de exemplo e testa todas as conversões com cada
/// motor instalado, um de cada vez, gerando um relatório.
class RunDiagnostics {
  const RunDiagnostics({
    required ConvertFiles convertFiles,
    required GetAvailableTargets getTargets,
    required SampleFactory samples,
    DateTime Function()? clock,
    String? tempDir,
  })  : _convertFiles = convertFiles,
        _getTargets = getTargets,
        _samples = samples,
        _clock = clock ?? DateTime.now,
        _tempDir = tempDir;

  final ConvertFiles _convertFiles;
  final GetAvailableTargets _getTargets;
  final SampleFactory _samples;
  final DateTime Function() _clock;
  final String? _tempDir;

  Stream<DiagnosticEvent> call(
    EngineAvailability engines, {
    CancellationToken? cancel,
  }) async* {
    final token = cancel ?? CancellationToken();
    final now = _clock();
    final root = p.join(
      _tempDir ?? Directory.systemTemp.path,
      'ConversorTeste_${_stamp(now)}',
    );
    final samplesDir = p.join(root, 'amostras');
    final outRoot = p.join(root, 'saida');
    Directory(samplesDir).createSync(recursive: true);
    Directory(outRoot).createSync(recursive: true);
    final rows = <DiagnosticRow>[];
    final found = EngineNames.all.where(engines.has).toList();

    yield DiagnosticMessage('Pasta do teste: $root');
    yield DiagnosticMessage(
      'Motores encontrados: ${found.isEmpty ? 'nenhum' : found.join(', ')}',
    );

    // 1. Arquivos de exemplo -------------------------------------------------
    yield const DiagnosticMessage('Criando arquivos de exemplo...');
    await _samples.createBasicSamples(samplesDir);
    for (final warning
        in await _samples.createOfficeSamples(samplesDir, engines)) {
      yield DiagnosticMessage(warning);
    }

    String sample(String name) => p.join(samplesDir, name);
    Future<String?> derive(String? source, TargetFormat format) async {
      if (source == null || !File(source).existsSync() || token.isCancelled) {
        return null;
      }
      final result = await _batch(
        [source],
        format,
        engines,
        p.join(root, 'preparo'),
        'Preparo',
      );
      final row = result.single;
      final file = row.file;
      if (row.outcome != DiagnosticOutcome.ok || file == null) return null;
      final destination = sample('amostra_${format.extension}.${format.extension}');
      deleteQuietly(destination);
      File(file).renameSync(destination);
      return destination;
    }

    final png = sample('amostra_png.png');
    final html = sample('amostra_html.html');
    final csv = sample('amostra_csv.csv');
    await derive(png, TargetFormat.ico);
    final docx = await derive(html, TargetFormat.docx);
    for (final f in const [TargetFormat.doc, TargetFormat.odt, TargetFormat.rtf]) {
      await derive(html, f);
    }
    // PDF de texto a partir do DOCX; sem motor de documentos, PDF de imagem.
    await derive(docx, TargetFormat.pdf) ?? await derive(png, TargetFormat.pdf);
    for (final f in const [TargetFormat.xlsx, TargetFormat.ods]) {
      await derive(csv, f);
    }
    await derive(sample('amostra_pptx.pptx'), TargetFormat.odp);

    final byCategory = <FileCategory, List<String>>{};
    final created = Directory(samplesDir)
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .toList()
      ..sort();
    for (final file in created) {
      final category = FileCategory.fromPath(file);
      if (category != null) byCategory.putIfAbsent(category, () => []).add(file);
    }
    yield DiagnosticMessage(
      'Amostras criadas: ${created.map(extensionOf).join(', ')}',
    );

    // 2. Cada motor sozinho, com tudo o que ele oferece ----------------------
    final passes = <(String, EngineAvailability, List<FileCategory>)>[
      (
        'Nativo',
        engines.nativeOnly,
        const [FileCategory.image, FileCategory.pdf],
      ),
      for (final name in found)
        (
          name,
          engines.only(name),
          const [
            FileCategory.pdf,
            FileCategory.document,
            FileCategory.sheet,
            FileCategory.slides,
          ],
        ),
    ];
    for (final (label, available, categories) in passes) {
      if (token.isCancelled) break;
      yield DiagnosticMessage('Testando: $label');
      for (final category in categories) {
        final files = byCategory[category] ?? const <String>[];
        if (files.isEmpty) continue;
        for (final target in _getTargets.forCategory(category, available)) {
          if (token.isCancelled) break;
          final result = await _batch(
            files,
            target,
            available,
            p.join(outRoot, label, target.extension),
            label,
          );
          for (final row in result) {
            rows.add(row);
            yield DiagnosticRowAdded(row);
          }
        }
      }
    }

    // 3. Extras: juntar imagens em PDF e mover o original para a Lixeira -----
    if (!token.isCancelled) {
      yield const DiagnosticMessage('Testes extras');
      final images = byCategory[FileCategory.image] ?? const <String>[];
      if (images.length >= 2) {
        final result = await _batch(
          images,
          TargetFormat.pdf,
          engines.nativeOnly,
          p.join(outRoot, 'Extra', 'juntar'),
          'Juntar PDF',
          mergeImages: true,
        );
        for (final row in result) {
          rows.add(row);
          yield DiagnosticRowAdded(row);
        }
      }
      if (File(png).existsSync()) {
        final copy = sample('teste_lixeira.png');
        File(png).copySync(copy);
        final result = await _batch(
          [copy],
          TargetFormat.jpg,
          engines.nativeOnly,
          p.join(outRoot, 'Extra', 'lixeira'),
          'Lixeira',
          deleteOriginal: true,
        );
        var row = result.single;
        if (File(copy).existsSync()) {
          row = row.failed('o arquivo original não foi enviado para a Lixeira');
        } else if (row.outcome == DiagnosticOutcome.ok) {
          row = DiagnosticRow(
            test: row.test,
            input: row.input,
            output: row.output,
            outcome: row.outcome,
            detail: 'original na Lixeira (pode apagar "teste_lixeira.png" de lá)',
            file: row.file,
          );
        }
        rows.add(row);
        yield DiagnosticRowAdded(row);
      }
    }

    // 4. Relatório -----------------------------------------------------------
    final reportPath = p.join(root, 'relatorio.txt');
    File(reportPath).writeAsStringSync(
      buildReport(rows, found, now, cancelled: token.isCancelled),
    );
    File(p.join(root, 'relatorio.csv')).writeAsStringSync(buildCsv(rows));
    yield DiagnosticFinished(folder: root, reportPath: reportPath);
  }

  /// Converte um lote com [ConvertFiles] e transforma o resultado em linhas.
  Future<List<DiagnosticRow>> _batch(
    List<String> paths,
    TargetFormat target,
    EngineAvailability engines,
    String outputDir,
    String label, {
    bool mergeImages = false,
    bool deleteOriginal = false,
  }) async {
    Directory(outputDir).createSync(recursive: true);
    final jobs = [
      for (var i = 0; i < paths.length; i++)
        ConversionJob(
          id: i,
          path: paths[i],
          category: FileCategory.fromPath(paths[i])!,
        ),
    ];
    final options = ConversionOptions(
      target: target,
      dpi: 100,
      outputDir: outputDir,
      mergeImages: mergeImages,
      deleteOriginal: deleteOriginal,
    );
    final status = <int, JobStatusChanged>{};
    final logs = <String>[];
    try {
      await for (final event in _convertFiles(jobs, options, engines)) {
        if (event is JobStatusChanged && event.state != JobState.running) {
          status[event.jobId] = event;
        } else if (event is LogEmitted) {
          logs.add(event.text);
        }
      }
    } on Object catch (e) {
      logs.add('Falha inesperada no lote: ${describeError(e)}');
    }

    return [
      for (final job in jobs)
        _rowFor(job, status[job.id], logs, target, label),
    ];
  }

  DiagnosticRow _rowFor(
    ConversionJob job,
    JobStatusChanged? status,
    List<String> logs,
    TargetFormat target,
    String label,
  ) {
    final name = job.fileName;
    var outcome = DiagnosticOutcome.error;
    var detail = 'sem resposta';
    final file = status?.outputPath;
    if (status != null) {
      switch (status.state) {
        case JobState.done:
          final problem = validateOutputFile(file, target.extension);
          if (problem != null) {
            detail = problem;
          } else {
            outcome = DiagnosticOutcome.ok;
            detail = '';
            final okLine = logs.lastWhere(
              (l) => l.startsWith('OK  $name ->'),
              orElse: () => '',
            );
            for (final engine in EngineNames.all) {
              if (okLine.contains(' ($engine)')) detail = 'via $engine';
            }
          }
        case JobState.skipped:
          outcome = DiagnosticOutcome.skipped;
          detail = status.text;
        default:
          final prefix = 'ERRO  $name : ';
          final line = logs.lastWhere(
            (l) => l.startsWith(prefix),
            orElse: () => logs.lastWhere(
              (l) => l.startsWith('ERRO'),
              orElse: () => '',
            ),
          );
          detail = line.startsWith(prefix)
              ? line.substring(prefix.length)
              : (line.isEmpty ? status.text : line);
      }
    }
    return DiagnosticRow(
      test: label,
      input: extensionOf(name),
      output: target.extension,
      outcome: outcome,
      detail: detail,
      file: file,
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _stamp(DateTime t) =>
      '${t.year}${_two(t.month)}${_two(t.day)}_'
      '${_two(t.hour)}${_two(t.minute)}${_two(t.second)}';

  /// Relatório em texto, alinhado em colunas.
  static String buildReport(
    List<DiagnosticRow> rows,
    List<String> engines,
    DateTime when, {
    bool cancelled = false,
  }) {
    int count(DiagnosticOutcome o) => rows.where((r) => r.outcome == o).length;
    final buffer = StringBuffer()
      ..writeln(
        'Autoteste do Conversor - ${_two(when.day)}/${_two(when.month)}/'
        '${when.year} ${_two(when.hour)}:${_two(when.minute)}',
      )
      ..writeln('Motores: ${engines.isEmpty ? 'nenhum' : engines.join(', ')}')
      ..writeln(
        'Resumo: ${count(DiagnosticOutcome.ok)} OK, '
        '${count(DiagnosticOutcome.error)} com erro, '
        '${count(DiagnosticOutcome.skipped)} ignorados (mesmo formato)',
      );
    if (cancelled) buffer.writeln('Teste cancelado antes do fim.');
    buffer
      ..writeln()
      ..writeln(
        '${'Teste'.padRight(12)} ${'Entrada'.padRight(8)} '
        '${'Saída'.padRight(6)} ${'Resultado'.padRight(10)} Detalhe',
      )
      ..writeln('-' * 70);
    for (final r in rows) {
      buffer.writeln(
        '${r.test.padRight(12)} ${r.input.padRight(8)} '
        '${r.output.padRight(6)} ${r.outcome.label.padRight(10)} ${r.detail}',
      );
    }
    return buffer.toString();
  }

  /// Relatório em CSV (ponto e vírgula, com BOM para abrir direto no Excel).
  static String buildCsv(List<DiagnosticRow> rows) {
    String cell(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';
    final buffer = StringBuffer('﻿')
      ..writeln('"Teste";"Entrada";"Saida";"Resultado";"Detalhe";"Arquivo"');
    for (final r in rows) {
      buffer.writeln(
        [r.test, r.input, r.output, r.outcome.label, r.detail, r.file]
            .map(cell)
            .join(';'),
      );
    }
    return buffer.toString();
  }
}
