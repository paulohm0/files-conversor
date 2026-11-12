import 'dart:io';

import 'package:equatable/equatable.dart';

import '../../conversion/domain/entities/engine_availability.dart';

enum DiagnosticOutcome {
  ok('OK'),
  error('ERRO'),
  skipped('IGNORADO');

  const DiagnosticOutcome(this.label);

  final String label;
}

/// Uma linha do relatório do autoteste.
class DiagnosticRow extends Equatable {
  const DiagnosticRow({
    required this.test,
    required this.input,
    required this.output,
    required this.outcome,
    this.detail = '',
    this.file,
  });

  final String test;
  final String input;
  final String output;
  final DiagnosticOutcome outcome;
  final String detail;
  final String? file;

  DiagnosticRow failed(String reason) => DiagnosticRow(
        test: test,
        input: input,
        output: output,
        outcome: DiagnosticOutcome.error,
        detail: reason,
        file: file,
      );

  @override
  List<Object?> get props => [test, input, output, outcome, detail, file];
}

/// Cria os arquivos de exemplo do autoteste.
abstract interface class SampleFactory {
  /// Imagens e textos, sem depender de nenhum motor externo.
  Future<void> createBasicSamples(String directory);

  /// Amostras que só o Office gera (XLS, PPTX, PPT). Devolve avisos.
  Future<List<String>> createOfficeSamples(
    String directory,
    EngineAvailability engines,
  );
}

/// Confere se o arquivo existe, não está vazio e começa com a assinatura do
/// formato. Devolve o problema encontrado ou `null`.
String? validateOutputFile(String? path, String format) {
  if (path == null || !File(path).existsSync()) {
    return 'arquivo de saída não encontrado';
  }
  final file = File(path);
  if (file.lengthSync() == 0) return 'arquivo de saída vazio';
  final handle = file.openSync();
  final List<int> head;
  try {
    head = handle.readSync(8);
  } finally {
    handle.closeSync();
  }
  bool starts(List<int> signature) =>
      head.length >= signature.length &&
      List.generate(signature.length, (i) => head[i] == signature[i])
          .every((match) => match);

  final valid = switch (format) {
    'pdf' => starts('%PDF'.codeUnits),
    'docx' || 'xlsx' || 'pptx' || 'odt' || 'ods' || 'odp' =>
      starts('PK'.codeUnits),
    'doc' || 'xls' || 'ppt' => starts(const [0xD0, 0xCF, 0x11, 0xE0]),
    'rtf' => starts(r'{\rtf'.codeUnits),
    'png' => starts(const [0x89, 0x50, 0x4E, 0x47]),
    'jpg' => starts(const [0xFF, 0xD8]),
    'bmp' => starts('BM'.codeUnits),
    'gif' => starts('GIF8'.codeUnits),
    'tiff' => starts(const [0x49, 0x49, 0x2A, 0x00]) ||
        starts(const [0x4D, 0x4D, 0x00, 0x2A]),
    'ico' => starts(const [0x00, 0x00, 0x01, 0x00]),
    _ => true,
  };
  if (valid) return null;
  final hex = head
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();
  return 'o arquivo gerado não parece um .$format válido (início: $hex)';
}
