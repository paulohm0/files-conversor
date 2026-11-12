import 'package:equatable/equatable.dart';

/// O que um motor produziu para um arquivo.
class ConversionResult extends Equatable {
  const ConversionResult({
    required this.outputs,
    this.engineName,
    this.detail,
  });

  /// Arquivos gerados (PDF para imagem gera um por página).
  final List<String> outputs;

  /// Motor externo que fez a conversão; `null` quando foi nativa.
  final String? engineName;

  /// Texto extra para o log, como "3 página(s)".
  final String? detail;

  ConversionResult withEngine(String name) =>
      ConversionResult(outputs: outputs, engineName: name, detail: detail);

  @override
  List<Object?> get props => [outputs, engineName, detail];
}
