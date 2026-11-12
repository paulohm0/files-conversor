import 'package:conversor_arquivos/features/diagnostics/domain/diagnostic_models.dart';
import 'package:conversor_arquivos/features/diagnostics/presentation/diagnostics_summary.dart';
import 'package:flutter_test/flutter_test.dart';

DiagnosticRow _row(
  String test,
  String input,
  DiagnosticOutcome outcome, [
  String detail = '',
]) =>
    DiagnosticRow(
      test: test,
      input: input,
      output: 'pdf',
      outcome: outcome,
      detail: detail,
    );

void main() {
  const ok = DiagnosticOutcome.ok;
  const error = DiagnosticOutcome.error;
  const skipped = DiagnosticOutcome.skipped;

  test('everything working gives a short positive headline', () {
    final summary = DiagnosticsSummary([
      _row('Nativo', 'png', ok),
      _row('Nativo', 'pdf', ok),
      _row('Word', 'docx', ok),
      _row('Word', 'pdf', skipped),
    ]);

    expect(summary.headline, 'Tudo funcionando!');
    expect(summary.subtitle, '3 conversões testadas neste computador.');
    expect(summary.groups.map((g) => g.title), [
      'Imagens (PNG, JPG, ícone e outros)',
      'PDF para imagem',
      'Documentos com o Microsoft Word',
    ]);
    expect(
      summary.groups.every((g) => g.status == GroupStatus.working),
      isTrue,
    );
  });

  test('Acrobat without license is explained in plain language', () {
    final summary = DiagnosticsSummary([
      _row('Nativo', 'png', ok),
      for (var i = 0; i < 3; i++)
        _row(
          'Acrobat',
          'pdf',
          error,
          'Acrobat: O Acrobat instalado não permite automação (...)',
        ),
    ]);

    expect(summary.headline, 'Quase tudo funcionando');
    expect(summary.subtitle, startsWith('1 de 4 conversões funcionaram.'));
    final acrobat = summary.groups.last;
    expect(acrobat.statusText, 'Não funciona neste computador');
    expect(acrobat.explanation, contains('Acrobat Pro ou Standard'));
    expect(acrobat.explanation, isNot(contains('automação')));
  });

  test('partial groups show how many worked', () {
    final summary = DiagnosticsSummary([
      _row('Excel', 'csv', ok),
      _row('Excel', 'xls', error, 'Excel: Tempo esgotado (600 s).'),
    ]);
    final excel = summary.groups.single;
    expect(excel.statusText, 'Funciona em parte (1 de 2)');
    expect(excel.explanation, contains('demorou demais'));
  });

  test('current step is described without technical names', () {
    expect(
      DiagnosticsSummary.currentStep(['Pasta do teste: C:\\x']),
      'Começando...',
    );
    expect(
      DiagnosticsSummary.currentStep([
        'Criando arquivos de exemplo...',
        'Testando: Nativo',
      ]),
      'Testando imagens e PDF...',
    );
    expect(
      DiagnosticsSummary.currentStep(['Testando: Excel']),
      'Testando o Microsoft Excel...',
    );
  });
}
