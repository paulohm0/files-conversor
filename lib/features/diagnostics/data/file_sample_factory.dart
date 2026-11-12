import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../../core/errors.dart';
import '../../conversion/data/bridge/office_bridge.dart';
import '../../conversion/data/codecs/image_codec.dart';
import '../../conversion/domain/entities/engine_availability.dart';
import '../domain/diagnostic_models.dart';

/// Gera as amostras do autoteste em disco.
class FileSampleFactory implements SampleFactory {
  const FileSampleFactory(this._bridge);

  final OfficeBridge _bridge;

  static const _html = '''
<html><head><meta charset="utf-8"><title>Amostra</title></head><body>
<h1>Relatório de Teste</h1>
<p>Parágrafo com <b>negrito</b>, <i>itálico</i> e acentuação: ação, coração, você.</p>
<ul><li>Item um</li><li>Item dois</li></ul>
<table border="1"><tr><th>Produto</th><th>Qtd</th><th>Preço</th></tr>
<tr><td>Caneta</td><td>10</td><td>2,50</td></tr><tr><td>Caderno</td><td>3</td><td>15,90</td></tr></table>
</body></html>
''';

  @override
  Future<void> createBasicSamples(String directory) async {
    await Isolate.run(() => writeImageSamples(directory));

    void text(String name, String content) {
      // UTF-8 com BOM, para Word e Excel reconhecerem a acentuação.
      File(p.join(directory, name))
          .writeAsBytesSync([0xEF, 0xBB, 0xBF, ...utf8.encode(content)]);
    }

    text('amostra_html.html', _html);
    text(
      'amostra_txt.txt',
      'Relatório de teste\r\nSegunda linha com acentuação: ação, você.\r\n',
    );
    text('amostra_md.md', '# Título\r\n\r\nTexto com **negrito** e acentuação.\r\n');
    text(
      'amostra_csv.csv',
      'Produto,Quantidade,Preco\r\nCaneta,10,2.5\r\nCaderno,3,15.9\r\n',
    );
  }

  @override
  Future<List<String>> createOfficeSamples(
    String directory,
    EngineAvailability engines,
  ) async {
    final warnings = <String>[];
    try {
      if (engines.excel) {
        try {
          await _bridge.send('excel', {
            'in': p.join(directory, 'amostra_csv.csv'),
            'out': p.join(directory, 'amostra_xls.xls'),
            'fmt': 'xls',
          });
        } on Object catch (e) {
          warnings.add(
            'Não foi possível criar amostra .xls: ${describeError(e)}',
          );
        }
      }
      if (engines.powerPoint) {
        try {
          await _bridge.send('sample-slides', {
            'pptx': p.join(directory, 'amostra_pptx.pptx'),
            'ppt': p.join(directory, 'amostra_ppt.ppt'),
          });
        } on Object catch (e) {
          warnings.add(
            'Não foi possível criar amostras de apresentação: '
            '${describeError(e)}',
          );
        }
      }
    } finally {
      await _bridge.close();
    }
    return warnings;
  }
}

/// Imagem com transparência, degradê e texto, em PNG, JPG, BMP, GIF e TIFF.
void writeImageSamples(String directory) {
  const width = 480;
  const height = 320;
  const inset = 20;
  const radius = 30;
  final image = img.Image(width: width, height: height, numChannels: 4);

  bool inside(int x, int y) {
    if (x < inset || y < inset || x >= width - inset || y >= height - inset) {
      return false;
    }
    final cx = x < inset + radius
        ? inset + radius
        : (x >= width - inset - radius ? width - inset - radius - 1 : x);
    final cy = y < inset + radius
        ? inset + radius
        : (y >= height - inset - radius ? height - inset - radius - 1 : y);
    final dx = x - cx;
    final dy = y - cy;
    return dx * dx + dy * dy <= radius * radius;
  }

  for (final pixel in image) {
    if (!inside(pixel.x, pixel.y)) continue;
    final t = pixel.x / (width - 1);
    // De azul-aço a laranja.
    pixel
      ..r = (70 + (255 - 70) * t).round()
      ..g = (130 + (165 - 130) * t).round()
      ..b = (180 + (0 - 180) * t).round()
      ..a = 255;
  }
  img.drawString(
    image,
    'Teste 123',
    font: img.arial48,
    x: 120,
    y: 130,
    color: img.ColorRgba8(255, 255, 255, 255),
  );

  for (final format in const ['png', 'jpg', 'bmp', 'gif', 'tiff']) {
    File(p.join(directory, 'amostra_$format.$format'))
        .writeAsBytesSync(encodeRaster(image, format, 85));
  }
}
