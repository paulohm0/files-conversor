import '../entities/engine_availability.dart';

/// Descobre quais motores externos existem na máquina.
abstract interface class EngineDetector {
  Future<EngineAvailability> detect();
}

/// Lixeira do Windows: sempre recuperável, nunca exclusão permanente.
abstract interface class RecycleBin {
  /// Devolve `false` se não foi possível mover.
  Future<bool> moveToRecycleBin(String path);
}

/// Monta um PDF A4 com uma imagem por página.
abstract interface class ImagePdfWriter {
  /// Devolve o número de páginas gravadas em [outputPath].
  Future<int> write(
    List<String> imagePaths,
    String outputPath, {
    required int jpgQuality,
  });
}

/// Encerra recursos de motores mantidos abertos durante um lote
/// (Word, Excel, PowerPoint, Acrobat).
abstract interface class EngineSession {
  Future<void> close();
}

/// Integrações com o Explorer do Windows.
abstract interface class ShellIntegration {
  /// Mostra o arquivo selecionado na pasta.
  Future<void> revealInExplorer(String path);

  /// Abre a pasta.
  Future<void> openFolder(String path);
}

/// Diálogos de escolha de arquivos e pastas.
abstract interface class FileDialogs {
  /// Caminhos escolhidos; vazio se o usuário cancelou.
  Future<List<String>> pickFiles();

  /// Pasta escolhida ou `null` se o usuário cancelou.
  Future<String?> pickFolder({String? initialDirectory});
}

/// Arquivos copiados no Explorer (Ctrl+C).
abstract interface class ClipboardFiles {
  Future<List<String>> readFilePaths();
}
