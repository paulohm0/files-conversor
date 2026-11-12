import 'package:path/path.dart' as p;

import '../../../../core/errors.dart';
import '../../../../core/path_utils.dart';
import '../../../../core/result.dart';
import '../contracts/repositories.dart';

class MergedPdf {
  const MergedPdf(this.path, this.pageCount);

  final String path;
  final int pageCount;
}

/// Junta várias imagens em um único PDF, uma por página.
class MergeImagesToPdf {
  const MergeImagesToPdf(this._writer, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final ImagePdfWriter _writer;
  final DateTime Function() _clock;

  Future<Result<MergedPdf>> call(
    List<String> imagePaths, {
    required int jpgQuality,
    String? outputDir,
  }) async {
    if (imagePaths.isEmpty) {
      return const Failure('Nenhuma imagem para juntar.');
    }
    final directory = outputDir ?? p.dirname(imagePaths.first);
    final output =
        uniquePath(directory, 'Imagens combinadas ${_stamp(_clock())}', 'pdf');
    try {
      final pages =
          await _writer.write(imagePaths, output, jpgQuality: jpgQuality);
      if (!isNonEmptyFile(output)) {
        throw const ConversionException('arquivo de saída não foi criado.');
      }
      return Success(MergedPdf(output, pages));
    } on Object catch (e) {
      deleteQuietly(output);
      return Failure(describeError(e));
    }
  }

  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }
}
