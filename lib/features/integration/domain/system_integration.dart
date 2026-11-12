/// Integrações do app com o Windows que ficam gravadas no sistema.
abstract interface class SystemIntegration {
  /// O atalho "Enviar para" existe?
  bool sendToShortcutExists();

  /// Cria (ou recria) o atalho "Enviar para" apontando para [executable].
  Future<void> installSendToShortcut(String executable);

  /// Comando registrado para iniciar com o Windows, ou `null` se não há.
  String? startupCommand();

  /// Registra [command] para rodar no logon do usuário.
  void registerStartup(String command);

  /// Remove o registro de inicialização.
  void unregisterStartup();
}
