import 'package:flutter/material.dart';

import '../../domain/entities/target_format.dart';

/// Botões de formato: um clique converte; o último usado fica em destaque.
class FormatBar extends StatelessWidget {
  const FormatBar({
    required this.targets,
    required this.lastTarget,
    required this.title,
    required this.emptyMessage,
    required this.enabled,
    required this.onConvert,
    super.key,
  });

  final List<TargetFormat> targets;
  final TargetFormat lastTarget;
  final String title;

  /// Texto mostrado quando não há formato disponível.
  final String emptyMessage;
  final bool enabled;
  final void Function(TargetFormat target) onConvert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge!
                  .copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            if (targets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  emptyMessage,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final target in targets)
                    Tooltip(
                      message: 'Converter para ${target.label}',
                      waitDuration: const Duration(milliseconds: 600),
                      child: target == lastTarget
                          ? FilledButton(
                              key: Key('format-${target.name}'),
                              onPressed:
                                  enabled ? () => onConvert(target) : null,
                              child: Text(target.buttonLabel),
                            )
                          : OutlinedButton(
                              key: Key('format-${target.name}'),
                              onPressed:
                                  enabled ? () => onConvert(target) : null,
                              child: Text(target.buttonLabel),
                            ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
