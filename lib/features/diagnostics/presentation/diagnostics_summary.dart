import 'package:equatable/equatable.dart';

import '../domain/diagnostic_models.dart';

enum GroupStatus { working, partial, notWorking }

/// Um grupo de conversões do teste, descrito para quem não é técnico.
class SummaryGroup extends Equatable {
  const SummaryGroup({
    required this.title,
    required this.ok,
    required this.failed,
    this.explanation,
  });

  final String title;
  final int ok;
  final int failed;

  /// Por que falhou, em linguagem simples (só quando há falha).
  final String? explanation;

  int get total => ok + failed;

  GroupStatus get status => failed == 0
      ? GroupStatus.working
      : (ok == 0 ? GroupStatus.notWorking : GroupStatus.partial);

  String get statusText => switch (status) {
        GroupStatus.working => 'Funcionando',
        GroupStatus.partial => 'Funciona em parte ($ok de $total)',
        GroupStatus.notWorking => 'Não funciona neste computador',
      };

  @override
  List<Object?> get props => [title, ok, failed, explanation];
}

/// Traduz o resultado técnico do autoteste em um resumo para usuários.
class DiagnosticsSummary {
  DiagnosticsSummary(List<DiagnosticRow> rows) : groups = _group(rows);

  final List<SummaryGroup> groups;

  int get ok => groups.fold(0, (sum, g) => sum + g.ok);
  int get failed => groups.fold(0, (sum, g) => sum + g.failed);

  String get headline {
    if (groups.isEmpty) return 'Nenhuma conversão foi testada.';
    if (failed == 0) return 'Tudo funcionando!';
    if (ok == 0) return 'As conversões não funcionaram neste computador.';
    return 'Quase tudo funcionando';
  }

  String get subtitle {
    if (groups.isEmpty) return '';
    if (failed == 0) return '$ok conversões testadas neste computador.';
    final working = groups.where((g) => g.status == GroupStatus.working);
    return '$ok de ${ok + failed} conversões funcionaram.'
        '${working.isEmpty ? '' : ' Os itens marcados como funcionando '
            'podem ser usados normalmente.'}';
  }

  /// Etapa atual, para mostrar enquanto o teste roda.
  static String currentStep(List<String> messages) {
    for (final message in messages.reversed) {
      if (message.startsWith('Criando arquivos')) {
        return 'Preparando arquivos de exemplo...';
      }
      if (message.startsWith('Testando: ')) {
        final label = message.substring('Testando: '.length);
        return 'Testando ${_stepNames[label] ?? label}...';
      }
      if (message.startsWith('Testes extras')) {
        return 'Testando as opções extras...';
      }
    }
    return 'Começando...';
  }

  static const _stepNames = {
    'Nativo': 'imagens e PDF',
    'Word': 'o Microsoft Word',
    'Excel': 'o Microsoft Excel',
    'PowerPoint': 'o Microsoft PowerPoint',
    'Acrobat': 'o Adobe Acrobat',
    'LibreOffice': 'o LibreOffice',
    'pdf2docx': 'o pdf2docx',
  };

  /// Ordem e nomes dos grupos.
  static const _titles = {
    'images': 'Imagens (PNG, JPG, ícone e outros)',
    'pdfImages': 'PDF para imagem',
    'Word': 'Documentos com o Microsoft Word',
    'Excel': 'Planilhas com o Microsoft Excel',
    'PowerPoint': 'Apresentações com o Microsoft PowerPoint',
    'LibreOffice': 'Documentos, planilhas e apresentações com o LibreOffice',
    'pdf2docx': 'PDF para Word com o pdf2docx',
    'Acrobat': 'PDF para Word, Excel e PowerPoint com o Adobe Acrobat',
    'Juntar PDF': 'Juntar várias imagens em um PDF',
    'Lixeira': 'Mover o arquivo original para a Lixeira',
  };

  static String _keyFor(DiagnosticRow row) {
    if (row.test == 'Nativo') return row.input == 'pdf' ? 'pdfImages' : 'images';
    return row.test;
  }

  static List<SummaryGroup> _group(List<DiagnosticRow> rows) {
    final byKey = <String, List<DiagnosticRow>>{};
    for (final row in rows) {
      // "Já está no formato" não é teste de conversão.
      if (row.outcome == DiagnosticOutcome.skipped) continue;
      byKey.putIfAbsent(_keyFor(row), () => []).add(row);
    }
    final keys = [
      ..._titles.keys.where(byKey.containsKey),
      ...byKey.keys.where((k) => !_titles.containsKey(k)),
    ];
    return [
      for (final key in keys) _summarize(key, byKey[key]!),
    ];
  }

  static SummaryGroup _summarize(String key, List<DiagnosticRow> rows) {
    final failures =
        rows.where((r) => r.outcome == DiagnosticOutcome.error).toList();
    return SummaryGroup(
      title: _titles[key] ?? key,
      ok: rows.length - failures.length,
      failed: failures.length,
      explanation: failures.isEmpty ? null : _explain(key, failures),
    );
  }

  static String _explain(String key, List<DiagnosticRow> failures) {
    final details = failures.map((r) => r.detail.toLowerCase()).join(' ');
    if (details.contains('não permite automação')) {
      return 'O Adobe Acrobat deste computador não permite conversões '
          'automáticas. Para usar esta opção é preciso o Acrobat Pro ou '
          'Standard. As outras conversões de PDF continuam funcionando.';
    }
    if (key == 'Lixeira') {
      return 'Não foi possível mover o arquivo de exemplo para a Lixeira. '
          'Deixe essa opção desmarcada até resolver.';
    }
    if (details.contains('extensões de imagem')) {
      return 'O Windows precisa das "Extensões de Imagem HEIF" da Microsoft '
          'Store para abrir esse tipo de foto.';
    }
    if (details.contains('tempo esgotado')) {
      return 'O programa demorou demais para responder. Feche o Word, o '
          'Excel e o PowerPoint e tente o teste de novo.';
    }
    return 'Algumas conversões não deram certo. Os detalhes estão no '
        'relatório completo.';
  }
}
