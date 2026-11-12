import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme.dart';
import '../../domain/entities/conversion_job.dart';

/// Área exibida quando a lista está vazia: clique abre o diálogo de arquivos.
class EmptyDropArea extends StatelessWidget {
  const EmptyDropArea({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppTheme.borderRadius,
      child: InkWell(
        key: const Key('empty-drop-area'),
        borderRadius: AppTheme.borderRadius,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppTheme.borderRadius,
            border: Border.all(color: scheme.outlineVariant, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.upload_file_outlined, size: 56, color: scheme.primary),
              const SizedBox(height: 12),
              Text(
                'Arraste arquivos ou pastas para cá',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'ou clique aqui para escolher  ·  Ctrl+V para colar do Explorer',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista de arquivos com nome, tipo, pasta, status colorido e hora.
class FileList extends StatefulWidget {
  const FileList({
    required this.jobs,
    required this.selectedIds,
    required this.onSelect,
    required this.onOpen,
    super.key,
  });

  final List<ConversionJob> jobs;
  final Set<int> selectedIds;

  /// Clique simples, com Ctrl ([toggle]) ou com Shift ([range]).
  final void Function(int id, {required bool toggle, required bool range})
      onSelect;

  /// Clique duplo.
  final void Function(ConversionJob job) onOpen;

  @override
  State<FileList> createState() => _FileListState();
}

class _FileListState extends State<FileList> {
  static const _doubleClick = Duration(milliseconds: 400);

  final _scroll = ScrollController();
  int? _lastTapId;
  DateTime _lastTapAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void didUpdateWidget(FileList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mantém visível o item em conversão.
    final running =
        widget.jobs.indexWhere((j) => j.state == JobState.running);
    if (running >= 0 && _scroll.hasClients) {
      final offset = running * _FileRow.height;
      final position = _scroll.position;
      if (offset < position.pixels ||
          offset + _FileRow.height >
              position.pixels + position.viewportDimension) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scroll.hasClients) return;
          _scroll.jumpTo(
            offset.clamp(0, _scroll.position.maxScrollExtent).toDouble(),
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _tap(ConversionJob job) {
    final now = DateTime.now();
    final isDouble =
        _lastTapId == job.id && now.difference(_lastTapAt) < _doubleClick;
    _lastTapId = job.id;
    _lastTapAt = now;
    if (isDouble) {
      widget.onOpen(job);
      return;
    }
    final keyboard = HardwareKeyboard.instance;
    widget.onSelect(
      job.id,
      toggle: keyboard.isControlPressed,
      range: keyboard.isShiftPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 32,
            color: scheme.surfaceContainerHigh,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DefaultTextStyle.merge(
              style: Theme.of(context)
                  .textTheme
                  .labelMedium!
                  .copyWith(color: scheme.onSurfaceVariant),
              child: const _Columns(
                name: Text('Arquivo'),
                type: Text('Tipo'),
                folder: Text('Pasta'),
                status: Text('Status'),
                time: Text('Hora'),
              ),
            ),
          ),
          Expanded(
            child: Tooltip(
              waitDuration: const Duration(seconds: 2),
              message: 'Selecione itens para converter só eles (inclusive do '
                  'histórico). Clique duplo: mostrar o arquivo na pasta.',
              child: ListView.builder(
                controller: _scroll,
                itemExtent: _FileRow.height,
                itemCount: widget.jobs.length,
                itemBuilder: (context, index) {
                  final job = widget.jobs[index];
                  return _FileRow(
                    key: ValueKey(job.id),
                    job: job,
                    selected: widget.selectedIds.contains(job.id),
                    onTap: () => _tap(job),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Columns extends StatelessWidget {
  const _Columns({
    required this.name,
    required this.type,
    required this.folder,
    required this.status,
    required this.time,
  });

  final Widget name;
  final Widget type;
  final Widget folder;
  final Widget status;
  final Widget time;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 5, child: name),
        const SizedBox(width: 12),
        SizedBox(width: 92, child: type),
        const SizedBox(width: 12),
        Expanded(flex: 4, child: folder),
        const SizedBox(width: 12),
        Expanded(flex: 4, child: status),
        const SizedBox(width: 12),
        SizedBox(width: 44, child: time),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.job,
    required this.selected,
    required this.onTap,
    super.key,
  });

  static const double height = 34;

  final ConversionJob job;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.statusColors;
    final statusColor = switch (job.state) {
      JobState.done => colors.done,
      JobState.error => colors.error,
      JobState.running => colors.running,
      JobState.skipped => colors.muted,
      JobState.pending || JobState.queued => scheme.onSurface,
    };
    final time = job.finishedAt;
    final hour = time == null
        ? ''
        : '${time.hour.toString().padLeft(2, '0')}:'
            '${time.minute.toString().padLeft(2, '0')}';
    const ellipsis = TextOverflow.ellipsis;

    return Material(
      color: selected ? scheme.secondaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _Columns(
            name: Tooltip(
              waitDuration: const Duration(milliseconds: 800),
              message: job.path,
              child: Text(job.fileName, maxLines: 1, overflow: ellipsis),
            ),
            type: Text(
              job.category.label,
              maxLines: 1,
              overflow: ellipsis,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            folder: Text(
              job.folder,
              maxLines: 1,
              overflow: ellipsis,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            status: Text(
              job.statusText,
              maxLines: 1,
              overflow: ellipsis,
              style: TextStyle(
                color: statusColor,
                fontWeight: job.state == JobState.running
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
            time: Text(
              hour,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}
