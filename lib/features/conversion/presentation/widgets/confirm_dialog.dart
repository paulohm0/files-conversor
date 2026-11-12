import 'package:flutter/material.dart';

import '../../domain/entities/target_format.dart';

class ConfirmResult {
  const ConfirmResult({required this.confirmed, this.dontAskAgain = false});

  final bool confirmed;
  final bool dontAskAgain;
}

/// Confirmação antes de converter: lista de arquivos, aviso em vermelho
/// quando os originais vão para a Lixeira e "não perguntar novamente".
Future<ConfirmResult> showConfirmDialog(
  BuildContext context, {
  required TargetFormat target,
  required List<String> fileNames,
  required bool deleteOriginal,
}) async {
  final result = await showDialog<ConfirmResult>(
    context: context,
    builder: (_) => _ConfirmDialog(
      target: target,
      fileNames: fileNames,
      deleteOriginal: deleteOriginal,
    ),
  );
  return result ?? const ConfirmResult(confirmed: false);
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({
    required this.target,
    required this.fileNames,
    required this.deleteOriginal,
  });

  final TargetFormat target;
  final List<String> fileNames;
  final bool deleteOriginal;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  static const _maxNames = 6;

  bool _dontAskAgain = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final names = widget.fileNames;
    return AlertDialog(
      title: Text(
        'Converter ${names.length} arquivo(s) para ${widget.target.label}?',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final name in names.take(_maxNames))
              Text('•  $name', maxLines: 1, overflow: TextOverflow.ellipsis),
            if (names.length > _maxNames)
              Text('   ... e mais ${names.length - _maxNames} arquivo(s)'),
            if (widget.deleteOriginal) ...[
              const SizedBox(height: 12),
              Text(
                'Os arquivos originais serão movidos para a Lixeira.',
                key: const Key('recycle-warning'),
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            CheckboxListTile(
              key: const Key('dont-ask-again'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              value: _dontAskAgain,
              onChanged: (v) => setState(() => _dontAskAgain = v ?? false),
              title: const Text(
                'Não perguntar novamente (converter direto nas próximas vezes)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context)
              .pop(const ConfirmResult(confirmed: false)),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirm-convert'),
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(
            ConfirmResult(confirmed: true, dontAskAgain: _dontAskAgain),
          ),
          child: const Text('Converter'),
        ),
      ],
    );
  }
}
