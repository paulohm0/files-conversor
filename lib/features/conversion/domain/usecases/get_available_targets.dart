import '../entities/engine_availability.dart';
import '../entities/file_category.dart';
import '../entities/target_format.dart';

/// Formatos de saída oferecidos, conforme os motores instalados.
class GetAvailableTargets {
  const GetAvailableTargets();

  /// Formatos para uma categoria.
  List<TargetFormat> forCategory(
    FileCategory category,
    EngineAvailability engines,
  ) {
    switch (category) {
      case FileCategory.image:
        return const [
          TargetFormat.png,
          TargetFormat.jpg,
          TargetFormat.bmp,
          TargetFormat.gif,
          TargetFormat.tiff,
          TargetFormat.ico,
          TargetFormat.pdf,
        ];
      case FileCategory.pdf:
        return [
          if (engines.acrobat ||
              engines.word ||
              engines.pdf2Docx ||
              engines.libreOffice)
            TargetFormat.docx,
          if (engines.acrobat) ...[TargetFormat.xlsx, TargetFormat.pptx],
          if (engines.nativePdf) ...[TargetFormat.png, TargetFormat.jpg],
        ];
      case FileCategory.document:
        if (!engines.word && !engines.libreOffice) return const [];
        return const [
          TargetFormat.pdf,
          TargetFormat.docx,
          TargetFormat.doc,
          TargetFormat.odt,
          TargetFormat.rtf,
          TargetFormat.txt,
        ];
      case FileCategory.sheet:
        if (!engines.excel && !engines.libreOffice) return const [];
        return const [
          TargetFormat.pdf,
          TargetFormat.xlsx,
          TargetFormat.ods,
          TargetFormat.csv,
        ];
      case FileCategory.slides:
        if (!engines.powerPoint && !engines.libreOffice) return const [];
        return const [TargetFormat.pdf, TargetFormat.pptx, TargetFormat.odp];
    }
  }

  /// Só os formatos comuns a todas as categorias, na ordem dos botões.
  List<TargetFormat> call(
    Iterable<FileCategory> categories,
    EngineAvailability engines,
  ) {
    final unique = categories.toSet();
    if (unique.isEmpty) return const [];
    var common = TargetFormat.values.toSet();
    for (final category in unique) {
      common = common.intersection(forCategory(category, engines).toSet());
    }
    return [
      for (final target in TargetFormat.values)
        if (common.contains(target)) target,
    ];
  }
}
