import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../../domain/contracts/repositories.dart';
import '../../domain/entities/file_category.dart';

/// Diálogos nativos do Windows, pelo pacote file_selector.
class FileSelectorDialogs implements FileDialogs {
  const FileSelectorDialogs();

  @override
  Future<List<String>> pickFiles() async {
    final files = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(
          label: 'Arquivos suportados',
          extensions: FileCategory.allExtensions,
        ),
        XTypeGroup(label: 'Imagens', extensions: FileCategory.image.extensions),
        XTypeGroup(
          label: 'Documentos e PDF',
          extensions: [
            ...FileCategory.document.extensions,
            ...FileCategory.pdf.extensions,
          ],
        ),
        XTypeGroup(
          label: 'Planilhas e apresentações',
          extensions: [
            ...FileCategory.sheet.extensions,
            ...FileCategory.slides.extensions,
          ],
        ),
        const XTypeGroup(label: 'Todos'),
      ],
    );
    return [for (final file in files) file.path];
  }

  @override
  Future<String?> pickFolder({String? initialDirectory}) => getDirectoryPath(
        initialDirectory:
            initialDirectory != null && Directory(initialDirectory).existsSync()
                ? initialDirectory
                : null,
        confirmButtonText: 'Selecionar pasta',
      );
}
