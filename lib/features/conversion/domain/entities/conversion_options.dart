import 'package:equatable/equatable.dart';

import 'target_format.dart';

/// Opções de um lote de conversão.
class ConversionOptions extends Equatable {
  const ConversionOptions({
    required this.target,
    this.jpgQuality = 85,
    this.dpi = 150,
    this.outputDir,
    this.mergeImages = false,
    this.deleteOriginal = false,
  });

  static const jpgQualities = [70, 85, 95];
  static const dpiValues = [100, 150, 300];

  final TargetFormat target;

  /// Qualidade JPG (70, 85 ou 95). Também vale para imagens dentro de PDF.
  final int jpgQuality;

  /// Resolução de PDF para imagem (100, 150 ou 300).
  final int dpi;

  /// Pasta de saída; `null` grava ao lado do original.
  final String? outputDir;

  /// Junta todas as imagens do lote em um único PDF.
  final bool mergeImages;

  /// Move o original para a Lixeira depois de confirmar a saída.
  final bool deleteOriginal;

  @override
  List<Object?> get props =>
      [target, jpgQuality, dpi, outputDir, mergeImages, deleteOriginal];
}
