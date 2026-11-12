import 'package:path/path.dart' as p;

import '../../../../core/cancellation.dart';
import '../../../../core/errors.dart';
import '../../../../core/path_utils.dart';
import '../../../../core/result.dart';
import '../contracts/conversion_engine.dart';
import '../contracts/repositories.dart';
import '../entities/conversion_job.dart';
import '../entities/conversion_options.dart';
import '../entities/engine_availability.dart';
import '../entities/file_category.dart';
import '../entities/target_format.dart';
import '../services/engine_chain.dart';
import '../services/output_allocator.dart';
import 'merge_images_to_pdf.dart';

/// O que acontece durante um lote, na ordem em que acontece.
sealed class ConversionEvent {
  const ConversionEvent();
}

class JobStatusChanged extends ConversionEvent {
  const JobStatusChanged(this.jobId, this.state, this.text, {this.outputPath});

  final int jobId;
  final JobState state;
  final String text;
  final String? outputPath;
}

class LogEmitted extends ConversionEvent {
  const LogEmitted(this.text, {this.isError = false});

  final String text;
  final bool isError;
}

class ProgressChanged extends ConversionEvent {
  const ProgressChanged(this.done);

  final int done;
}

class EngineDisabled extends ConversionEvent {
  const EngineDisabled(this.engine, this.reason);

  final String engine;
  final String reason;
}

class BatchFinished extends ConversionEvent {
  const BatchFinished({
    required this.ok,
    required this.failed,
    required this.folders,
    required this.cancelled,
  });

  final int ok;
  final int failed;
  final List<String> folders;
  final bool cancelled;
}

/// Converte um lote de arquivos, um por vez, emitindo eventos de progresso.
class ConvertFiles {
  const ConvertFiles({
    required EngineChain chain,
    required MergeImagesToPdf mergeImages,
    required RecycleBin recycleBin,
    required EngineSession session,
  })  : _chain = chain,
        _mergeImages = mergeImages,
        _recycleBin = recycleBin,
        _session = session;

  final EngineChain _chain;
  final MergeImagesToPdf _mergeImages;
  final RecycleBin _recycleBin;
  final EngineSession _session;

  Stream<ConversionEvent> call(
    List<ConversionJob> jobs,
    ConversionOptions options,
    EngineAvailability engines, {
    CancellationToken? cancel,
  }) async* {
    final token = cancel ?? CancellationToken();
    final folders = <String>[];
    var available = engines;
    var done = 0;
    var ok = 0;
    var failed = 0;

    void addFolder(String dir) {
      if (!folders.contains(dir)) folders.add(dir);
    }

    try {
      var remaining = jobs;

      // Modo "juntar imagens em um único PDF".
      final images =
          jobs.where((j) => j.category == FileCategory.image).toList();
      if (options.mergeImages &&
          options.target == TargetFormat.pdf &&
          images.length > 1) {
        remaining =
            jobs.where((j) => j.category != FileCategory.image).toList();
        for (final job in images) {
          yield JobStatusChanged(job.id, JobState.running, 'Convertendo...');
        }
        final merged = await _mergeImages(
          [for (final j in images) j.path],
          jpgQuality: options.jpgQuality,
          outputDir: options.outputDir,
        );
        switch (merged) {
          case Success(:final value):
            addFolder(p.dirname(value.path));
            var suffix = '';
            if (options.deleteOriginal) {
              final warnings = <String>[];
              final moved = await _recycleAll(
                [for (final j in images) j.path],
                warnings,
              );
              for (final w in warnings) {
                yield LogEmitted(w, isError: true);
              }
              if (moved) suffix = ' - originais na Lixeira';
            }
            for (final job in images) {
              yield JobStatusChanged(
                job.id,
                JobState.done,
                'Concluído (PDF único)$suffix',
                outputPath: value.path,
              );
            }
            yield LogEmitted(
              'OK  ${images.length} imagens -> ${p.basename(value.path)} '
              '(${value.pageCount} página(s))',
            );
            ok += images.length;
          case Failure(:final message):
            for (final job in images) {
              yield JobStatusChanged(job.id, JobState.error, 'Erro');
            }
            yield LogEmitted('ERRO ao juntar imagens: $message', isError: true);
            failed += images.length;
        }
        done += images.length;
        yield ProgressChanged(done);
      }

      for (final job in remaining) {
        final name = job.fileName;
        if (token.isCancelled) {
          yield JobStatusChanged(job.id, JobState.pending, 'Cancelado');
          continue;
        }

        // Já está no formato pedido (imagens podem ser regravadas).
        if (job.category != FileCategory.image &&
            normalizedExtension(job.path) == options.target.extension) {
          yield JobStatusChanged(
            job.id,
            JobState.skipped,
            'Ignorado (já é .${options.target.extension})',
          );
          yield LogEmitted('--  $name ignorado: já está no formato escolhido.');
          done++;
          yield ProgressChanged(done);
          continue;
        }

        yield JobStatusChanged(job.id, JobState.running, 'Convertendo...');
        final allocator = OutputAllocator(
          sourcePath: job.path,
          outputDir: options.outputDir,
        );
        final request = ConversionRequest(
          inputPath: job.path,
          category: job.category,
          options: options,
          output: allocator,
          cancel: token,
        );
        final disabled = <EngineDisabled>[];
        try {
          final result = await _chain.convert(
            request,
            available,
            onEngineDisabled: (engine, reason) =>
                disabled.add(EngineDisabled(engine, reason)),
          );
          for (final event in disabled) {
            available = available.without(event.engine);
            yield event;
          }
          addFolder(allocator.directory);

          final first = result.outputs.isEmpty ? null : result.outputs.first;
          var description = result.detail ??
              (first == null ? '' : p.basename(first));
          if (result.engineName != null) {
            description += ' (${result.engineName})';
          }
          var status = 'Concluído';
          if (options.deleteOriginal) {
            if (allocator.allOutputsValid) {
              final warnings = <String>[];
              if (await _recycleAll([job.path], warnings)) {
                status = 'Concluído - original na Lixeira';
                description += ' [original enviado para a Lixeira]';
              }
              for (final w in warnings) {
                yield LogEmitted(w, isError: true);
              }
            } else {
              yield LogEmitted(
                'AVISO  $name : original mantido '
                '(arquivo convertido não confirmado).',
                isError: true,
              );
            }
          }
          yield JobStatusChanged(
            job.id,
            JobState.done,
            status,
            outputPath: first,
          );
          yield LogEmitted('OK  $name -> $description');
          ok++;
        } on CancelledException {
          allocator.discardAll();
          yield JobStatusChanged(job.id, JobState.pending, 'Cancelado');
          yield LogEmitted(
            '--  $name cancelado: os arquivos parciais foram apagados.',
          );
        } on Object catch (e) {
          for (final event in disabled) {
            available = available.without(event.engine);
            yield event;
          }
          allocator.discardAll();
          yield JobStatusChanged(job.id, JobState.error, 'Erro');
          yield LogEmitted('ERRO  $name : ${describeError(e)}', isError: true);
          failed++;
        }
        done++;
        yield ProgressChanged(done);
      }
    } finally {
      try {
        await _session.close();
      } on Object {
        // Fechar os aplicativos é melhor esforço.
      }
      yield BatchFinished(
        ok: ok,
        failed: failed,
        folders: folders,
        cancelled: token.isCancelled,
      );
    }
  }

  /// Envia para a Lixeira; para no primeiro que falhar.
  Future<bool> _recycleAll(List<String> paths, List<String> warnings) async {
    for (final path in paths) {
      if (!await _recycleBin.moveToRecycleBin(path)) {
        warnings.add(
          'AVISO  não foi possível mover para a Lixeira: ${p.basename(path)}',
        );
        return false;
      }
    }
    return true;
  }
}
