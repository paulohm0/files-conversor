import 'package:equatable/equatable.dart';

import '../../conversion/domain/entities/conversion_options.dart';
import '../../conversion/domain/entities/target_format.dart';

/// Opções lembradas entre usos do aplicativo.
class AppSettings extends Equatable {
  const AppSettings({
    this.jpgPreset = 1,
    this.dpiPreset = 1,
    this.mergeImages = false,
    this.useOtherFolder = false,
    this.outputDir = '',
    this.openFolderWhenDone = false,
    this.deleteOriginal = false,
    this.lastTarget = TargetFormat.pdf,
    this.confirmBeforeConvert = true,
    this.showLog = false,
    this.showOptions = true,
  });

  static const jpgPresetLabels = [
    'Baixa (arquivo menor)',
    'Média (recomendado)',
    'Alta (melhor qualidade)',
  ];
  static const dpiPresetLabels = [
    'Baixa - 100 DPI',
    'Média - 150 DPI',
    'Alta - 300 DPI',
  ];

  /// Índice em [ConversionOptions.jpgQualities].
  final int jpgPreset;

  /// Índice em [ConversionOptions.dpiValues].
  final int dpiPreset;
  final bool mergeImages;
  final bool useOtherFolder;
  final String outputDir;
  final bool openFolderWhenDone;
  final bool deleteOriginal;
  final TargetFormat lastTarget;
  final bool confirmBeforeConvert;
  final bool showLog;
  final bool showOptions;

  int get jpgQuality => ConversionOptions.jpgQualities[jpgPreset.clamp(0, 2)];
  int get dpi => ConversionOptions.dpiValues[dpiPreset.clamp(0, 2)];

  /// Opções de um lote para o formato escolhido.
  ConversionOptions toOptions(TargetFormat target) => ConversionOptions(
        target: target,
        jpgQuality: jpgQuality,
        dpi: dpi,
        outputDir: useOtherFolder && outputDir.trim().isNotEmpty
            ? outputDir.trim()
            : null,
        mergeImages: mergeImages,
        deleteOriginal: deleteOriginal,
      );

  AppSettings copyWith({
    int? jpgPreset,
    int? dpiPreset,
    bool? mergeImages,
    bool? useOtherFolder,
    String? outputDir,
    bool? openFolderWhenDone,
    bool? deleteOriginal,
    TargetFormat? lastTarget,
    bool? confirmBeforeConvert,
    bool? showLog,
    bool? showOptions,
  }) =>
      AppSettings(
        jpgPreset: jpgPreset ?? this.jpgPreset,
        dpiPreset: dpiPreset ?? this.dpiPreset,
        mergeImages: mergeImages ?? this.mergeImages,
        useOtherFolder: useOtherFolder ?? this.useOtherFolder,
        outputDir: outputDir ?? this.outputDir,
        openFolderWhenDone: openFolderWhenDone ?? this.openFolderWhenDone,
        deleteOriginal: deleteOriginal ?? this.deleteOriginal,
        lastTarget: lastTarget ?? this.lastTarget,
        confirmBeforeConvert: confirmBeforeConvert ?? this.confirmBeforeConvert,
        showLog: showLog ?? this.showLog,
        showOptions: showOptions ?? this.showOptions,
      );

  @override
  List<Object?> get props => [
        jpgPreset,
        dpiPreset,
        mergeImages,
        useOtherFolder,
        outputDir,
        openFolderWhenDone,
        deleteOriginal,
        lastTarget,
        confirmBeforeConvert,
        showLog,
        showOptions,
      ];
}
