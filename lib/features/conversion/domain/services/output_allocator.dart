import 'package:path/path.dart' as p;

import '../../../../core/path_utils.dart';

/// Reserva os caminhos de saída de um arquivo de entrada, sem sobrescrever
/// nada, e lembra o que foi gerado para poder desfazer em caso de falha.
class OutputAllocator {
  OutputAllocator({required this.sourcePath, this.outputDir});

  final String sourcePath;
  final String? outputDir;
  final List<String> _outputs = [];

  String get directory => outputDir ?? p.dirname(sourcePath);

  /// Arquivos reservados até agora.
  List<String> get outputs => List.unmodifiable(_outputs);

  /// Próximo caminho livre: `nome<sufixo>.ext`, `nome<sufixo> (1).ext`...
  String allocate(String extension, {String suffix = ''}) {
    final base = p.basenameWithoutExtension(sourcePath) + suffix;
    final path = uniquePath(
      directory,
      base,
      extension,
      exists: (candidate) =>
          _outputs.contains(candidate) || isExistingFile(candidate),
    );
    _outputs.add(path);
    return path;
  }

  /// Apaga tudo o que foi gerado (arquivos parciais) e esquece as reservas.
  void discardAll() {
    for (final path in _outputs) {
      deleteQuietly(path);
    }
    _outputs.clear();
  }

  /// A conversão só é confirmada se todos os arquivos existem e têm conteúdo.
  bool get allOutputsValid =>
      _outputs.isNotEmpty && _outputs.every(isNonEmptyFile);
}
