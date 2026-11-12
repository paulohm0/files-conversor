/// Falha esperada de uma conversão, com mensagem pronta para o usuário.
class ConversionException implements Exception {
  const ConversionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// O usuário cancelou a operação.
class CancelledException extends ConversionException {
  const CancelledException() : super('Cancelado pelo usuário.');
}

/// O motor não pode ser usado nesta sessão (por exemplo, Acrobat sem licença
/// de automação). A cadeia desativa o motor e segue para o próximo.
class EngineUnavailableException extends ConversionException {
  const EngineUnavailableException(this.engineName, super.message);

  final String engineName;
}

/// Extrai uma mensagem legível de qualquer erro.
String describeError(Object error) {
  if (error is ConversionException) return error.message;
  return error.toString().replaceFirst(RegExp(r'^(Exception|Error): '), '');
}
