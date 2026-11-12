import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../settings/domain/app_settings.dart';

/// Painel de opções recolhível: qualidades em cima, caixas de marcar no
/// meio e "Salvar em" por último. Todos os textos usam o mesmo estilo.
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
                child: DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.bodyMedium,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _qualities(),
                        const SizedBox(height: 6),
                        _checks(scheme),
                        const SizedBox(height: 6),
                        _saveIn(scheme),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _qualities() => Wrap(
        spacing: 28,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Preset(
            key: const Key('option-jpg-quality'),
            label: 'Qualidade JPG:',
            tooltip: 'Compressão ao gerar JPG e ao colocar imagens em PDF.\n'
                'Baixa: 70%   Média: 85%   Alta: 95%',
            options: AppSettings.jpgPresetLabels,
            value: settings.jpgPreset,
            onChanged: (v) => onChanged((s) => s.copyWith(jpgPreset: v)),
          ),
          _Preset(
            label: 'Resolução PDF → imagem:',
            tooltip: 'Nitidez das imagens geradas a partir de páginas de '
                'PDF.\n100 DPI: tela/e-mail   150 DPI: uso geral   '
                '300 DPI: impressão',
            options: AppSettings.dpiPresetLabels,
            value: settings.dpiPreset,
            onChanged: (v) => onChanged((s) => s.copyWith(dpiPreset: v)),
          ),
        ],
      );

  Widget _checks(ColorScheme scheme) => Wrap(
        spacing: 20,
        runSpacing: 4,
        children: [
          _Check(
            label: 'Juntar imagens em um só PDF',
            value: settings.mergeImages,
            onChanged: (v) => onChanged((s) => s.copyWith(mergeImages: v)),
          ),
          _Check(
            key: const Key('option-delete-original'),
            label: 'Mover o original para a Lixeira',
            tooltip: 'Depois de converter, o original vai para a Lixeira. Só '
                'acontece se a conversão der certo, e ele pode ser '
                'restaurado.',
            value: settings.deleteOriginal,
            color: settings.deleteOriginal ? scheme.error : null,
            onChanged: (v) => onChanged((s) => s.copyWith(deleteOriginal: v)),
          ),
          _Check(
            label: 'Abrir a pasta ao terminar',
            value: settings.openFolderWhenDone,
            onChanged: (v) =>
                onChanged((s) => s.copyWith(openFolderWhenDone: v)),
          ),
          _Check(
            key: const Key('option-confirm'),
            label: 'Confirmar antes de converter',
            tooltip: 'Mostra a lista de arquivos e pede confirmação antes de '
                'começar.',
            value: settings.confirmBeforeConvert,
            onChanged: (v) =>
                onChanged((s) => s.copyWith(confirmBeforeConvert: v)),
          ),
        ],
      );

  Widget _saveIn(ColorScheme scheme) => Wrap(
        spacing: 12,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Salvar em:'),
          SegmentedButton<bool>(
            key: const Key('option-save-in'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Mesma pasta do original'),
              ),
              ButtonSegment(value: true, label: Text('Outra pasta')),
            ],
            selected: {settings.useOtherFolder},
            onSelectionChanged: (v) =>
                onChanged((s) => s.copyWith(useOtherFolder: v.first)),
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
      );
}

class _Preset extends StatelessWidget {
  const _Preset({
    required this.label,
    required this.tooltip,
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String tooltip;
  final List<String> options;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            // Mesmo tamanho e peso dos textos ao lado (o padrão é maior).
            style: theme.textTheme.bodyMedium!
                .copyWith(color: theme.colorScheme.onSurface),
            underline: const SizedBox.shrink(),
            borderRadius: AppTheme.borderRadius,
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
      borderRadius: AppTheme.borderRadius,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sem a margem padrão, para alinhar com os rótulos acima e abaixo.
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            ),
            const SizedBox(width: 6),
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
