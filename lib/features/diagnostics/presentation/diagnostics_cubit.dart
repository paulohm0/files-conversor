import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cancellation.dart';
import '../../../core/errors.dart';
import '../../conversion/domain/entities/engine_availability.dart';
import '../domain/diagnostic_models.dart';
import '../domain/run_diagnostics.dart';

class DiagnosticsState extends Equatable {
  const DiagnosticsState({
    this.running = false,
    this.cancelling = false,
    this.messages = const [],
    this.rows = const [],
    this.folder,
    this.reportPath,
  });

  final bool running;
  final bool cancelling;
  final List<String> messages;
  final List<DiagnosticRow> rows;
  final String? folder;
  final String? reportPath;

  bool get finished => !running && reportPath != null;

  int count(DiagnosticOutcome outcome) =>
      rows.where((r) => r.outcome == outcome).length;

  DiagnosticsState copyWith({
    bool? running,
    bool? cancelling,
    List<String>? messages,
    List<DiagnosticRow>? rows,
    String? folder,
    String? reportPath,
  }) =>
      DiagnosticsState(
        running: running ?? this.running,
        cancelling: cancelling ?? this.cancelling,
        messages: messages ?? this.messages,
        rows: rows ?? this.rows,
        folder: folder ?? this.folder,
        reportPath: reportPath ?? this.reportPath,
      );

  @override
  List<Object?> get props =>
      [running, cancelling, messages, rows, folder, reportPath];
}

/// Executa o autoteste e acumula as linhas do relatório.
class DiagnosticsCubit extends Cubit<DiagnosticsState> {
  DiagnosticsCubit(this._runDiagnostics) : super(const DiagnosticsState());

  final RunDiagnostics _runDiagnostics;
  CancellationToken? _cancel;

  Future<void> run(EngineAvailability engines) async {
    if (state.running) return;
    final token = _cancel = CancellationToken();
    emit(const DiagnosticsState(running: true));
    try {
      await for (final event in _runDiagnostics(engines, cancel: token)) {
        if (isClosed) return;
        switch (event) {
          case DiagnosticMessage():
            emit(state.copyWith(messages: [...state.messages, event.text]));
          case DiagnosticRowAdded():
            emit(state.copyWith(rows: [...state.rows, event.row]));
          case DiagnosticFinished():
            emit(
              state.copyWith(
                folder: event.folder,
                reportPath: event.reportPath,
              ),
            );
        }
      }
    } on Object catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          messages: [...state.messages, 'Erro interno: ${describeError(e)}'],
        ),
      );
    } finally {
      _cancel = null;
      if (!isClosed) emit(state.copyWith(running: false, cancelling: false));
    }
  }

  void cancel() {
    final token = _cancel;
    if (token == null || token.isCancelled) return;
    token.cancel();
    emit(state.copyWith(cancelling: true));
  }

  @override
  Future<void> close() {
    _cancel?.cancel();
    return super.close();
  }
}
