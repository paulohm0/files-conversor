import 'package:equatable/equatable.dart';

/// Nomes dos motores externos, como aparecem no log e no rodapé.
abstract final class EngineNames {
  static const acrobat = 'Acrobat';
  static const word = 'Word';
  static const excel = 'Excel';
  static const powerPoint = 'PowerPoint';
  static const libreOffice = 'LibreOffice';
  static const pdf2Docx = 'pdf2docx';

  static const all = [acrobat, word, excel, powerPoint, libreOffice, pdf2Docx];
}

/// Motores de conversão encontrados na máquina.
class EngineAvailability extends Equatable {
  const EngineAvailability({
    this.acrobat = false,
    this.word = false,
    this.excel = false,
    this.powerPoint = false,
    this.libreOfficePath,
    this.pdf2DocxPath,
    this.nativePdf = true,
  });

  /// Nenhum motor externo: só as conversões nativas.
  static const none = EngineAvailability();

  final bool acrobat;
  final bool word;
  final bool excel;
  final bool powerPoint;
  final String? libreOfficePath;
  final String? pdf2DocxPath;

  /// Renderização nativa de PDF (PDFium). Desligada só no autoteste, para
  /// isolar cada motor externo.
  final bool nativePdf;

  bool get libreOffice => libreOfficePath != null;
  bool get pdf2Docx => pdf2DocxPath != null;

  bool has(String engineName) => switch (engineName) {
        EngineNames.acrobat => acrobat,
        EngineNames.word => word,
        EngineNames.excel => excel,
        EngineNames.powerPoint => powerPoint,
        EngineNames.libreOffice => libreOffice,
        EngineNames.pdf2Docx => pdf2Docx,
        _ => false,
      };

  /// Cópia sem o motor indicado.
  EngineAvailability without(String engineName) => EngineAvailability(
        acrobat: acrobat && engineName != EngineNames.acrobat,
        word: word && engineName != EngineNames.word,
        excel: excel && engineName != EngineNames.excel,
        powerPoint: powerPoint && engineName != EngineNames.powerPoint,
        libreOfficePath:
            engineName == EngineNames.libreOffice ? null : libreOfficePath,
        pdf2DocxPath: engineName == EngineNames.pdf2Docx ? null : pdf2DocxPath,
        nativePdf: nativePdf,
      );

  /// Cópia somente com o motor indicado (usada pelo autoteste).
  EngineAvailability only(String engineName) => EngineAvailability(
        acrobat: acrobat && engineName == EngineNames.acrobat,
        word: word && engineName == EngineNames.word,
        excel: excel && engineName == EngineNames.excel,
        powerPoint: powerPoint && engineName == EngineNames.powerPoint,
        libreOfficePath:
            engineName == EngineNames.libreOffice ? libreOfficePath : null,
        pdf2DocxPath: engineName == EngineNames.pdf2Docx ? pdf2DocxPath : null,
        nativePdf: false,
      );

  /// Cópia sem nenhum motor externo.
  EngineAvailability get nativeOnly => const EngineAvailability();

  @override
  List<Object?> get props => [
        acrobat,
        word,
        excel,
        powerPoint,
        libreOfficePath,
        pdf2DocxPath,
        nativePdf,
      ];
}
