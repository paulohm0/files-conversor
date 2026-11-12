import 'package:equatable/equatable.dart';

import '../../domain/entities/conversion_job.dart';

class LogEntry extends Equatable {
  const LogEntry(this.time, this.text, {this.isError = false});

  final DateTime time;
  final String text;
  final bool isError;

  @override
  List<Object?> get props => [time, text, isError];
}

/// Resultado do último lote. [sequence] muda a cada lote, para a tela reagir
/// uma única vez.
class RunSummary extends Equatable {
  const RunSummary({
    required this.sequence,
    required this.ok,
    required this.failed,
    required this.folders,
    required this.cancelled,
  });

  final int sequence;
  final int ok;
  final int failed;
  final List<String> folders;
  final bool cancelled;

  @override
  List<Object?> get props => [sequence, ok, failed, folders, cancelled];
}

class ConversionState extends Equatable {
  const ConversionState({
    this.jobs = const [],
    this.selectedIds = const {},
    this.running = false,
    this.cancelling = false,
    this.progressDone = 0,
    this.progressTotal = 0,
    this.statusLabel = 'Pronto.',
    this.log = const [],
    this.lastRun,
  });

  final List<ConversionJob> jobs;
  final Set<int> selectedIds;
  final bool running;
  final bool cancelling;
  final int progressDone;
  final int progressTotal;
  final String statusLabel;
  final List<LogEntry> log;
  final RunSummary? lastRun;

  bool get hasSelection => selectedIds.isNotEmpty;

  /// Itens selecionados (permite reconverter do histórico); sem seleção, os
  /// pendentes e os que deram erro.
  List<ConversionJob> get jobsToConvert => hasSelection
      ? jobs.where((j) => selectedIds.contains(j.id)).toList()
      : jobs.where((j) => j.needsConversion).toList();

  double get progress =>
      progressTotal == 0 ? 0 : (progressDone / progressTotal).clamp(0, 1);

  ConversionState copyWith({
    List<ConversionJob>? jobs,
    Set<int>? selectedIds,
    bool? running,
    bool? cancelling,
    int? progressDone,
    int? progressTotal,
    String? statusLabel,
    List<LogEntry>? log,
    RunSummary? lastRun,
  }) =>
      ConversionState(
        jobs: jobs ?? this.jobs,
        selectedIds: selectedIds ?? this.selectedIds,
        running: running ?? this.running,
        cancelling: cancelling ?? this.cancelling,
        progressDone: progressDone ?? this.progressDone,
        progressTotal: progressTotal ?? this.progressTotal,
        statusLabel: statusLabel ?? this.statusLabel,
        log: log ?? this.log,
        lastRun: lastRun ?? this.lastRun,
      );

  @override
  List<Object?> get props => [
        jobs,
        selectedIds,
        running,
        cancelling,
        progressDone,
        progressTotal,
        statusLabel,
        log,
        lastRun,
      ];
}
