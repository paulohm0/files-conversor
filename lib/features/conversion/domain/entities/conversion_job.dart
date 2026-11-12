import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as p;

import 'file_category.dart';

enum JobState { pending, queued, running, done, error, skipped }

/// Um arquivo na lista: pendente, em conversão ou já no histórico.
class ConversionJob extends Equatable {
  const ConversionJob({
    required this.id,
    required this.path,
    required this.category,
    this.state = JobState.pending,
    this.statusText = 'Pendente',
    this.outputPath,
    this.finishedAt,
  });

  final int id;
  final String path;
  final FileCategory category;
  final JobState state;
  final String statusText;

  /// Primeiro arquivo gerado na última conversão.
  final String? outputPath;
  final DateTime? finishedAt;

  String get fileName => p.basename(path);
  String get folder => p.dirname(path);

  /// Entra na conversão quando nada está selecionado.
  bool get needsConversion =>
      state == JobState.pending || state == JobState.error;

  ConversionJob copyWith({
    JobState? state,
    String? statusText,
    String? Function()? outputPath,
    DateTime? Function()? finishedAt,
  }) =>
      ConversionJob(
        id: id,
        path: path,
        category: category,
        state: state ?? this.state,
        statusText: statusText ?? this.statusText,
        outputPath: outputPath != null ? outputPath() : this.outputPath,
        finishedAt: finishedAt != null ? finishedAt() : this.finishedAt,
      );

  ConversionJob asPending() => copyWith(
        state: JobState.pending,
        statusText: 'Pendente',
        outputPath: () => null,
        finishedAt: () => null,
      );

  @override
  List<Object?> get props =>
      [id, path, category, state, statusText, outputPath, finishedAt];
}
