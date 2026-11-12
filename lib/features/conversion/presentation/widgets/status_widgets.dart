import 'package:flutter/material.dart';

import '../../../../core/theme.dart';

import '../cubit/conversion_state.dart';

/// Barra de progresso com botão cancelar e o botão do registro.
class ProgressRow extends StatelessWidget {
  const ProgressRow({
    required this.state,
    required this.logVisible,
    required this.onCancel,
    required this.onToggleLog,
    super.key,
  });

  final ConversionState state;
  final bool logVisible;
  final VoidCallback onCancel;
  final VoidCallback onToggleLog;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: AppTheme.borderRadius,
            child: LinearProgressIndicator(
              minHeight: 10,
              value: state.running && state.progressDone == 0
                  ? null
                  : state.progress,
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          key: const Key('cancel-button'),
          onPressed: state.running && !state.cancelling ? onCancel : null,
          child: const Text('Cancelar (Esc)'),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 150),
          child: Text(
            state.statusLabel,
            key: const Key('status-label'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        TextButton.icon(
          key: const Key('log-toggle'),
          onPressed: onToggleLog,
          icon: Icon(logVisible ? Icons.expand_less : Icons.expand_more),
          label: Text(logVisible ? 'Ocultar registro' : 'Mostrar registro'),
        ),
      ],
    );
  }
}

/// Registro (log) das conversões, com rolagem automática para o fim.
class LogPanel extends StatefulWidget {
  const LogPanel({required this.entries, super.key});

  final List<LogEntry> entries;

  @override
  State<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<LogPanel> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToEnd();
  }

  @override
  void didUpdateWidget(LogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries.length != widget.entries.length) _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static String _time(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('log-panel'),
      child: SizedBox(
        height: 140,
        child: SelectionArea(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            itemCount: widget.entries.length,
            itemBuilder: (context, index) {
              final entry = widget.entries[index];
              return Text(
                '${_time(entry.time)}  ${entry.text}',
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 12.5,
                  height: 1.35,
                  color: entry.isError ? scheme.error : scheme.onSurface,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

