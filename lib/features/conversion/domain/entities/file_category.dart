import '../../../../core/path_utils.dart';

/// Tipo de arquivo de entrada, definido pela extensão.
enum FileCategory {
  image('Imagem', [
    'png', 'jpg', 'jpeg', 'jfif', 'bmp', 'gif', 'tif', 'tiff', 'webp', //
    'heic', 'heif', 'ico',
  ]),
  pdf('PDF', ['pdf']),
  document('Documento', [
    'doc', 'docx', 'docm', 'dotx', 'odt', 'rtf', 'txt', 'md', 'htm', 'html', //
  ]),
  sheet('Planilha', ['xlsx', 'xls', 'xlsm', 'ods', 'csv']),
  slides('Apresentação', ['pptx', 'ppt', 'pptm', 'ppsx', 'pps', 'odp']);

  const FileCategory(this.label, this.extensions);

  final String label;
  final List<String> extensions;

  /// Categoria do arquivo, ou `null` se a extensão não é suportada.
  static FileCategory? fromPath(String path) {
    final ext = extensionOf(path);
    for (final category in values) {
      if (category.extensions.contains(ext)) return category;
    }
    return null;
  }

  static List<String> get allExtensions =>
      [for (final c in values) ...c.extensions];
}
