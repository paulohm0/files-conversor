import 'package:flutter/material.dart';

import '../../domain/entities/engine_availability.dart';

/// O que este computador consegue converter, em palavras comuns.
class Capabilities {
  const Capabilities(this.engines);

  final EngineAvailability engines;

  bool get documents => engines.word || engines.libreOffice;
  bool get sheets => engines.excel || engines.libreOffice;
  bool get slides => engines.powerPoint || engines.libreOffice;

  /// Itens que funcionam, na ordem em que aparecem.
  List<String> get available => [
        'imagens',
        'PDF',
        if (documents) 'documentos',
        if (sheets) 'planilhas',
        if (slides) 'apresentações',
      ];

  /// Dica para o que falta, ou `null` se está tudo disponível.
  String? get missingHint {
    final missing = [
      if (!documents) 'documentos',
      if (!sheets) 'planilhas',
      if (!slides) 'apresentações',
    ];
    if (missing.isEmpty) return null;
    final what = missing.length == 1
        ? missing.first
        : '${missing.sublist(0, missing.length - 1).join(', ')} e '
            '${missing.last}';
    return 'Para converter $what, instale o Microsoft Office ou o '
        'LibreOffice (gratuito).';
  }

  /// Programas encontrados, para suporte (aparece só como dica do mouse).
  String get technicalDetail {
    final found = EngineNames.all.where(engines.has).toList();
    return 'Programas encontrados: '
        '${found.isEmpty ? 'nenhum' : found.join(', ')}';
  }
}

/// Rodapé: "Este computador converte: imagens · PDF · documentos...".
class CapabilitiesFooter extends StatelessWidget {
  const CapabilitiesFooter({
    required this.engines,
    required this.detected,
    super.key,
  });

  final EngineAvailability engines;
  final bool detected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context)
        .textTheme
        .labelMedium!
        .copyWith(color: scheme.onSurfaceVariant);
    final capabilities = Capabilities(engines);
    final hint = capabilities.missingHint;
    return Tooltip(
      message: detected ? capabilities.technicalDetail : '',
      waitDuration: const Duration(seconds: 1),
      child: Container(
        key: const Key('capabilities-footer'),
        width: double.infinity,
        color: scheme.surfaceContainerHigh,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: !detected
            ? Text('Verificando o que este computador converte...', style: style)
            : Wrap(
                spacing: 16,
                runSpacing: 2,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Este computador converte: '
                        '${capabilities.available.join(' · ')}',
                        style: style,
                      ),
                    ],
                  ),
                  if (hint != null) Text(hint, style: style),
                ],
              ),
      ),
    );
  }
}
