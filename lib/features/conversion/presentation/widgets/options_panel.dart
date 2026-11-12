import 'package:flutter/material.dart';

import '../../../settings/domain/app_settings.dart';

/// Painel de opções recolhível.
class OptionsPanel extends StatelessWidget {
  const OptionsPanel({
    required this.settings,
    required this.enabled,
    required this.onChanged,
    required this.onBrowse,
    super.key,
  });

  final AppSettings settings;
  final bool enabled;
  final void Function(AppSettings Function(AppSettings current) change)
      onChanged;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final expanded = settings.showOptions;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('options-header'),
            onTap: () => onChanged((s) => s.copyWith(showOptions: !expanded)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.tune, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Opções',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge!
                        .copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            IgnorePointer(
              ignoring: !enabled,
              child: Opacity(
                opacity: enabled ? 1 : 0.5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 20,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Preset(
                            label: 'Qualidade JPG:',
                            tooltip: 'Compressão ao gerar JPG e ao colocar '
                                'imagens em PDF.\n'
                                'Baixa: 70%   Média: 85%   Alta: 95%',
                            options: AppSettings.jpgPresetLabels,
                            value: settings.jpgPreset,
                            onChanged: (v) =>
                                onChanged((s) => s.copyWith(jpgPreset: v)),
                          ),
                          _Preset(
                            label: 'Resolução PDF → imagem:',
                            tooltip: 'Nitidez das imagens geradas a partir de '
                                'páginas de PDF.\n100 DPI: tela/e-mail   '
                                '150 DPI: uso geral   300 DPI: impressão',
                            options: AppSettings.dpiPresetLabels,
                            value: settings.dpiPreset,
                            onChanged: (v) =>
                                onChanged((s) => s.copyWith(dpiPreset: v)),
                          ),
                          _Check(
                            label: 'Juntar imagens em um só PDF',
                            value: settings.mergeImages,
                            onChanged: (v) =>
                                onChanged((s) => s.copyWith(mergeImages: v)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Salvar em:'),
                          SegmentedButton<bool>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Mesma pasta do original'),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Outra pasta'),
                              ),
                            ],
                            selected: {settings.useOtherFolder},
                            onSelectionChanged: (v) => onChanged(
                              (s) => s.copyWith(useOtherFolder: v.first),
                            ),
                          ),
                          if (settings.useOtherFolder) ...[
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360),
                              child: Text(
                                settings.outputDir.isEmpty
                                    ? '(nenhuma pasta escolhida)'
                                    : settings.outputDir,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: settings.outputDir.isEmpty
                                      ? scheme.error
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                            OutlinedButton(
                              onPressed: onBrowse,
                              child: const Text('Procurar...'),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 20,
                        runSpacing: 0,
                        children: [
                          _Check(
                            key: const Key('option-delete-original'),
                            label: 'Mover o arquivo original para a Lixeira '
                                'após converter',
                            tooltip: 'O original só é removido se a conversão '
                                'der certo. Ele vai para a Lixeira e pode ser '
                                'restaurado.',
                            value: settings.deleteOriginal,
                            color:
                                settings.deleteOriginal ? scheme.error : null,
                            onChanged: (v) =>
                                onChanged((s) => s.copyWith(deleteOriginal: v)),
                          ),
                          _Check(
                            label: 'Abrir a pasta ao terminar',
                            value: settings.openFolderWhenDone,
                            onChanged: (v) => onChanged(
                              (s) => s.copyWith(openFolderWhenDone: v),
                            ),
                          ),
                          _Check(
                            key: const Key('option-confirm'),
                            label: 'Pedir confirmação antes de converter',
                            value: settings.confirmBeforeConvert,
                            onChanged: (v) => onChanged(
                              (s) => s.copyWith(confirmBeforeConvert: v),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Preset extends StatelessWidget {
  const _Preset({
    required this.label,
    required this.tooltip,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String tooltip;
  final List<String> options;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: value.clamp(0, options.length - 1),
            isDense: true,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(8),
            items: [
              for (var i = 0; i < options.length; i++)
                DropdownMenuItem(value: i, child: Text(options[i])),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.label,
    required this.value,
    required this.onChanged,
    this.tooltip,
    this.color,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final row = InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
    final message = tooltip;
    if (message == null) return row;
    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 600),
      child: row,
    );
  }
}
