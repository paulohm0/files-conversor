import 'dart:io';

import 'package:path/path.dart' as p;

/// Extensão em minúsculas, sem ponto.
String extensionOf(String path) =>
    p.extension(path).replaceFirst('.', '').toLowerCase();

/// Extensão normalizada para comparar com o formato de destino
/// (`jpeg`/`jfif` viram `jpg`, `tif` vira `tiff`).
String normalizedExtension(String path) {
  final ext = extensionOf(path);
  return switch (ext) {
    'jpeg' || 'jfif' => 'jpg',
    'tif' => 'tiff',
    _ => ext,
  };
}

/// Nunca sobrescreve: se `nome.ext` existe, devolve `nome (1).ext`,
/// `nome (2).ext` e assim por diante.
String uniquePath(
  String directory,
  String baseName,
  String extension, {
  bool Function(String path)? exists,
}) {
  final check = exists ?? (String path) => File(path).existsSync();
  var candidate = p.join(directory, '$baseName.$extension');
  var n = 1;
  while (check(candidate)) {
    candidate = p.join(directory, '$baseName ($n).$extension');
    n++;
  }
  return candidate;
}

/// Expande pastas apenas no primeiro nível; arquivos passam direto.
List<String> expandFirstLevel(Iterable<String> paths) {
  final result = <String>[];
  for (final path in paths) {
    if (path.isEmpty) continue;
    if (Directory(path).existsSync()) {
      try {
        final files = Directory(path)
            .listSync(followLinks: false)
            .whereType<File>()
            .map((f) => f.path)
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        result.addAll(files);
      } on FileSystemException {
        // Pasta sem permissão de leitura: ignora.
      }
    } else if (File(path).existsSync()) {
      result.add(path);
    }
  }
  return result;
}

/// Apaga um arquivo parcial sem propagar erro.
void deleteQuietly(String? path) {
  if (path == null) return;
  try {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  } on FileSystemException {
    // Sem permissão ou arquivo em uso: nada a fazer.
  }
}

bool isExistingFile(String path) => File(path).existsSync();

/// Verdadeiro se o arquivo existe e não está vazio.
bool isNonEmptyFile(String path) {
  final file = File(path);
  return file.existsSync() && file.lengthSync() > 0;
}
