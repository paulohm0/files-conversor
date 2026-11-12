/// Integração do app com o Explorer do Windows.
abstract interface class SystemIntegration {
  /// O atalho "Enviar para" existe?
  bool sendToShortcutExists();

  /// Cria (ou recria) o atalho "Enviar para" apontando para [executable].
  Future<void> installSendToShortcut(String executable);
}
