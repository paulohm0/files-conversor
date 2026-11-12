import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme.dart';
import '../../conversion/domain/entities/engine_availability.dart';
import 'diagnostics_cubit.dart';
import 'diagnostics_summary.dart';

/// Caixa "Testar conversões": roda o autoteste e mostra um resumo simples.
/// O relatório técnico fica em arquivo, acessível por "Ver relatório
/// completo".
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
        final folder = state.folder;
        final Widget body;
        if (state.running) {
          body = _Running(state: state);
        } else if (state.finished) {
          body = _Result(summary: DiagnosticsSummary(state.rows));
        } else if (state.messages.isNotEmpty) {
          body = const Text(
            'O teste foi interrompido antes de terminar. Tente de novo.',
          );
        } else {
          body = const _Intro();
        }
        return AlertDialog(
          title: const Text('Testar conversões'),
          content: SizedBox(width: 560, child: body),
          actions: [
            if (state.finished && folder != null)
              TextButton(
                onPressed: () => onOpenFolder(folder),
                child: const Text('Ver relatório completo'),
              ),
            if (state.running)
              TextButton(
                onPressed: state.cancelling ? null : cubit.cancel,
                child: Text(state.cancelling ? 'Parando...' : 'Parar teste'),
              )
            else
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            if (!state.running && !state.finished)
              FilledButton(
                key: const Key('run-diagnostics'),
                onPressed: () => cubit.run(engines),
                child: const Text('Começar teste'),
              ),
          ],
        );
      },
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confira se as conversões funcionam neste computador.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 12),
        Text(
          'O teste cria alguns arquivos de exemplo e tenta convertê-los para '
          'todos os formatos. Seus arquivos não são alterados.',
        ),
        SizedBox(height: 8),
        Text(
          'Leva alguns minutos. Enquanto isso, evite usar o Word, o Excel e o '
          'PowerPoint.',
        ),
        SizedBox(height: 8),
        Text(
          'Um dos arquivos de exemplo vai para a Lixeira, só para testar '
          'essa opção. Você pode apagá-lo depois.',
        ),
      ],
    );
  }
}

class _Running extends StatelessWidget {
  const _Running({required this.state});

  final DiagnosticsState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(DiagnosticsSummary.currentStep(state.messages)),
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          state.rows.isEmpty
              ? 'Isso pode levar alguns minutos.'
              : '${state.rows.length} conversões testadas até agora.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.summary});

  final DiagnosticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.statusColors;
    final scheme = Theme.of(context).colorScheme;
    final allGood = summary.failed == 0;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 440),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allGood ? Icons.check_circle : Icons.info,
                color: allGood ? colors.done : scheme.primary,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  summary.headline,
                  key: const Key('diagnostics-headline'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(summary.subtitle),
          const SizedBox(height: 14),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: summary.groups.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _GroupTile(group: summary.groups[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final SummaryGroup group;

  @override
  Widget build(BuildContext context) {
    final colors = context.statusColors;
    final (icon, color) = switch (group.status) {
      GroupStatus.working => (Icons.check_circle_outline, colors.done),
      GroupStatus.partial => (Icons.error_outline, colors.running),
      GroupStatus.notWorking => (Icons.cancel_outlined, colors.error),
    };
    final explanation = group.explanation;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.title),
                Text(
                  group.statusText,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
                if (explanation != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    explanation,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
