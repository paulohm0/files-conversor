/// Formato de saída. A ordem do enum é a ordem dos botões na tela.
enum TargetFormat {
  pdf('PDF', 'PDF'),
  docx('DOCX (Word)', 'Word (DOCX)'),
  doc('DOC (Word 97-2003)', 'Word 97 (DOC)'),
  odt('ODT (OpenDocument)', 'ODT'),
  rtf('RTF', 'RTF'),
  txt('TXT (texto puro)', 'Texto (TXT)'),
  xlsx('XLSX (Excel)', 'Excel (XLSX)'),
  ods('ODS (OpenDocument)', 'ODS'),
  csv('CSV', 'CSV'),
  pptx('PPTX (PowerPoint)', 'PowerPoint'),
  odp('ODP (OpenDocument)', 'ODP'),
  png('PNG', 'PNG'),
  jpg('JPG', 'JPG'),
  bmp('BMP', 'BMP'),
  gif('GIF', 'GIF'),
  tiff('TIFF', 'TIFF'),
  ico('ICO (ícone)', 'Ícone (ICO)');

  const TargetFormat(this.label, this.buttonLabel);

  /// Nome completo, usado em mensagens e dicas.
  final String label;

  /// Texto curto do botão.
  final String buttonLabel;

  /// Extensão do arquivo gerado (igual ao nome do enum).
  String get extension => name;

  bool get isRasterImage =>
      const {png, jpg, bmp, gif, tiff, ico}.contains(this);

  static TargetFormat? fromName(String? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}
