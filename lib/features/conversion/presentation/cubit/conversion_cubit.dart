import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../../../core/cancellation.dart';
import '../../../../core/errors.dart';
import '../../../../core/path_utils.dart';
import '../../domain/contracts/repositories.dart';
import '../../domain/entities/conversion_job.dart';
import '../../domain/entities/conversion_options.dart';
import '../../domain/entities/engine_availability.dart';
import '../../domain/entities/file_category.dart';
import '../../domain/usecases/convert_files.dart';
import 'conversion_state.dart';

/// Lista de arquivos, seleção, progresso, registro e cancelamento.
class ConversionCubit extends Cubit<ConversionState> {
  ConversionCubit({
    required ConvertFiles convertFiles,
    required ClipboardFiles clipboard,
    DateTime Function()? clock,
  })  : _convertFiles = convertFiles,
        _clipboard = clipboard,
        _clock = clock ?? DateTime.now,
        super(const ConversionState());

  final ConvertFiles _convertFiles;
  final ClipboardFiles _clipboard;
  final DateTime Function() _clock;

  CancellationToken? _cancel;
  int _nextId = 1;
  int _runSequence = 0;
  int? _selectionAnchor;

  // --- Registro -----------------------------------------------------------

  void addLog(String text, {bool isError = false}) {
    emit(
      state.copyWith(
        log: [...state.log, LogEntry(_clock(), text, isError: isError)],
      ),
    );
  }

  // --- Lista --------------------------------------------------------------

  /// Adiciona arquivos (pastas são expandidas só no primeiro nível). Quem já
  /// está no histórico volta a ficar pendente.
  void addPaths(Iterable<String> paths) {
    if (state.running) return;
    final jobs = [...state.jobs];
    final indexByPath = {
      for (var i = 0; i < jobs.length; i++) jobs[i].path.toLowerCase(): i,
    };
    final unsupported = <String>[];
    for (final file in expandFirstLevel(paths)) {
      final key = file.toLowerCase();
      final existing = indexByPath[key];
      if (existing != null) {
        if (jobs[existing].state != JobState.pending) {
          jobs[existing] = jobs[existing].asPending();
        }
        continue;
      }
      final category = FileCategory.fromPath(file);
      if (category == null) {
        unsupported.add(p.basename(file));
        continue;
      }
      indexByPath[key] = jobs.length;
      jobs.add(ConversionJob(id: _nextId++, path: file, category: category));
    }
    _selectionAnchor = null;
    emit(state.copyWith(jobs: jobs, selectedIds: const {}));
    if (unsupported.isNotEmpty) {
      addLog('Formato não suportado (ignorado): ${unsupported.join(', ')}');
    }
  }

  Future<void> addFromClipboard() async {
    if (state.running) return;
    List<String> paths;
    try {
      paths = await _clipboard.readFilePaths();
    } on Object catch (e) {
      addLog(
        'Não foi possível ler a área de transferência: ${describeError(e)}',
        isError: true,
      );
      return;
    }
    if (paths.isEmpty) {
      addLog(
        'A área de transferência não tem arquivos. Copie arquivos no '
        'Explorer (Ctrl+C) e cole aqui (Ctrl+V).',
      );
      return;
    }
    addPaths(paths);
  }

  void removeSelected() {
    if (state.running || !state.hasSelection) return;
    _selectionAnchor = null;
    emit(
      state.copyWith(
        jobs: state.jobs
            .where((j) => !state.selectedIds.contains(j.id))
            .toList(),
        selectedIds: const {},
      ),
    );
  }

  void clearList() {
    if (state.running) return;
    _selectionAnchor = null;
    emit(
      state.copyWith(
        jobs: const [],
        selectedIds: const {},
        progressDone: 0,
        progressTotal: 0,
        statusLabel: 'Pronto.',
      ),
    );
  }

  // --- Seleção ------------------------------------------------------------

  /// Clique em um item: simples seleciona só ele; com Ctrl alterna; com
  /// Shift seleciona o intervalo desde o último clique.
  void select(int id, {bool toggle = false, bool range = false}) {
    if (state.running) return;
    final ids = state.jobs.map((j) => j.id).toList();
    final anchor = _selectionAnchor;
    if (range && anchor != null && ids.contains(anchor)) {
      final a = ids.indexOf(anchor);
      final b = ids.indexOf(id);
      final from = a < b ? a : b;
      final to = a < b ? b : a;
      emit(state.copyWith(selectedIds: ids.sublist(from, to + 1).toSet()));
      return;
    }
    _selectionAnchor = id;
    if (toggle) {
      final next = {...state.selectedIds};
      if (!next.remove(id)) next.add(id);
      emit(state.copyWith(selectedIds: next));
    } else {
      emit(state.copyWith(selectedIds: {id}));
    }
  }

  void selectAll() {
    if (state.running) return;
    emit(state.copyWith(selectedIds: state.jobs.map((j) => j.id).toSet()));
  }

  void clearSelection() {
    if (!state.hasSelection) return;
    _selectionAnchor = null;
    emit(state.copyWith(selectedIds: const {}));
  }

  // --- Conversão ----------------------------------------------------------

  /// Converte os itens selecionados (ou os pendentes) para o formato das
  /// [options].
  Future<void> start(
    ConversionOptions options,
    EngineAvailability engines, {
    void Function(String engine)? onEngineDisabled,
  }) async {
    if (state.running) return;

    var items = state.jobsToConvert;
    final missing = items.where((j) => !File(j.path).existsSync()).toList();
    if (missing.isNotEmpty) {
      addLog(
        'Original não encontrado (movido, excluído ou na Lixeira): '
        '${missing.map((j) => j.fileName).join(', ')}',
        isError: true,
      );
      items = items.where((j) => !missing.contains(j)).toList();
    }
    if (items.isEmpty) return;

    final outputDir = options.outputDir;
    if (outputDir != null) {
      try {
        Directory(outputDir).createSync(recursive: true);
      } on FileSystemException {
        addLog('Não foi possível usar a pasta: $outputDir', isError: true);
        return;
      }
    }

    final token = _cancel = CancellationToken();
    final queuedIds = items.map((j) => j.id).toSet();
    emit(
      state.copyWith(
        jobs: [
          for (final job in state.jobs)
            if (queuedIds.contains(job.id))
              job.copyWith(
                state: JobState.queued,
                statusText: 'Na fila',
                outputPath: () => null,
                finishedAt: () => null,
              )
            else
              job,
        ],
        running: true,
        cancelling: false,
        progressDone: 0,
        progressTotal: items.length,
        statusLabel: '0 de ${items.length}',
      ),
    );
    addLog('Iniciando: ${items.length} arquivo(s) -> ${options.target.label}');

    BatchFinished? finished;
    try {
      await for (final event
          in _convertFiles(items, options, engines, cancel: token)) {
        switch (event) {
          case JobStatusChanged():
            _applyStatus(event);
          case LogEmitted():
            addLog(event.text, isError: event.isError);
          case ProgressChanged():
            emit(
              state.copyWith(
                progressDone: event.done,
                statusLabel: '${event.done} de ${state.progressTotal}',
              ),
            );
          case EngineDisabled():
            onEngineDisabled?.call(event.engine);
            addLog(
              '${event.engine} desativado nesta sessão: ${event.reason} '
              'Usando os outros motores.',
              isError: true,
            );
          case BatchFinished():
            finished = event;
        }
      }
    } on Object catch (e) {
      addLog('Erro interno: ${describeError(e)}', isError: true);
    }

    _cancel = null;
    final summary = finished;
    if (summary == null) {
      emit(
        state.copyWith(
          running: false,
          cancelling: false,
          selectedIds: const {},
          statusLabel: 'Interrompido.',
        ),
      );
      return;
    }
    addLog('Fim: ${summary.ok} concluído(s), ${summary.failed} com erro.');
    emit(
      state.copyWith(
        running: false,
        cancelling: false,
        selectedIds: const {},
        statusLabel: summary.cancelled
            ? 'Cancelado: ${summary.ok} ok, ${summary.failed} com erro'
            : 'Concluído: ${summary.ok} ok, ${summary.failed} com erro',
        lastRun: RunSummary(
          sequence: ++_runSequence,
          ok: summary.ok,
          failed: summary.failed,
          folders: summary.folders,
          cancelled: summary.cancelled,
        ),
      ),
    );
  }

  /// Termina o arquivo atual e para.
  void cancel() {
    final token = _cancel;
    if (!state.running || token == null || token.isCancelled) return;
    token.cancel();
    emit(state.copyWith(cancelling: true));
    addLog('Cancelando... (o arquivo atual será concluído primeiro)');
  }

  void _applyStatus(JobStatusChanged event) {
    final finishedNow =
        event.state == JobState.done || event.state == JobState.error;
    emit(
      state.copyWith(
        jobs: [
          for (final job in state.jobs)
            if (job.id == event.jobId)
              job.copyWith(
                state: event.state,
                statusText: event.text,
                outputPath: event.outputPath != null
                    ? () => event.outputPath
                    : null,
                finishedAt: finishedNow ? _clock : null,
              )
            else
              job,
        ],
      ),
    );
  }
}
