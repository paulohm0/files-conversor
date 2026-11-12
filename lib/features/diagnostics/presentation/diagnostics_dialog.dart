import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme.dart';
import '../../conversion/domain/entities/engine_availability.dart';
import '../domain/diagnostic_models.dart';
import 'diagnostics_cubit.dart';

/// Tela de diagnóstico: roda o autoteste e mostra o relatório.
Future<void> showDiagnosticsDialog(
  BuildContext context, {
  required DiagnosticsCubit Function() createCubit,
  required EngineAvailability engines,
  required void Function(String folder) onOpenFolder,
}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider(
        create: (_) => createCubit(),
        child: _DiagnosticsDialog(engines: engines, onOpenFolder: onOpenFolder),
      ),
    );

class _DiagnosticsDialog extends StatelessWidget {
  const _DiagnosticsDialog({required this.engines, required this.onOpenFolder});

  final EngineAvailability engines;
  final void Function(String folder) onOpenFolder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiagnosticsCubit, DiagnosticsState>(
      builder: (context, state) {
        final cubit = context.read<DiagnosticsCubit>();
        final started = state.running || state.finished;
        final folder = state.folder;
        return AlertDialog(
          title: const Text('Diagnóstico (autoteste)'),
          content: SizedBox(
            width: 720,
            height: 440,
            child: started
                ? _Report(state: state)
                : const Text(
                    'O autoteste cria arquivos de exemplo em uma pasta '
                    'temporária e testa todas as conversões com cada motor '
                    'instalado, um de cada vez.\n\n'
                    'Pode levar alguns minutos. Não use o Word, o Excel nem o '
                    'PowerPoint enquanto o teste roda.\n\n'
                    'Um arquivo de teste ("teste_lixeira.png") é enviado para '
                    'a Lixeira para conferir essa função.',
                  ),
          ),
          actions: [
            if (state.finished && folder != null)
              TextButton(
                onPressed: () => onOpenFolder(folder),
                child: const Text('Abrir pasta do relatório'),
              ),
            if (state.running)
              TextButton(
                onPressed: state.cancelling ? null : cubit.cancel,
                child: Text(state.cancelling ? 'Cancelando...' : 'Cancelar'),
              )
            else
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            if (!started)
              FilledButton(
                key: const Key('run-diagnostics'),
                onPressed: () => cubit.run(engines),
                child: const Text('Iniciar teste'),
              ),
          ],
        );
      },
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({required this.state});

  final DiagnosticsState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.statusColors;
    final lastMessage = state.messages.isEmpty ? '' : state.messages.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.running) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
        ] else
          Text(
            '${state.count(DiagnosticOutcome.ok)} OK   |   '
            '${state.count(DiagnosticOutcome.error)} com erro   |   '
            '${state.count(DiagnosticOutcome.skipped)} ignorados',
            key: const Key('diagnostics-summary'),
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  color: state.count(DiagnosticOutcome.error) > 0
                      ? colors.error
                      : colors.done,
                ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectionArea(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                reverse: state.running,
                itemCount: state.rows.length,
                itemBuilder: (context, index) {
                  final row = state.running
                      ? state.rows[state.rows.length - 1 - index]
                      : state.rows[index];
                  final color = switch (row.outcome) {
                    DiagnosticOutcome.ok => colors.done,
                    DiagnosticOutcome.error => colors.error,
                    DiagnosticOutcome.skipped => colors.muted,
                  };
                  return Text(
                    '[${row.outcome.label.padRight(8)}] '
                    '${row.test.padRight(12)} '
                    '${row.input.padRight(5)} -> ${row.output.padRight(5)} '
                    '${row.detail}',
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12.5,
                      height: 1.35,
                      color: color,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (state.reportPath != null) ...[
          const SizedBox(height: 8),
          Text(
            'Relatório salvo em: ${state.reportPath}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
