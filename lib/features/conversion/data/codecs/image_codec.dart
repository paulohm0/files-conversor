import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/errors.dart';

/// Funções puras de imagem. São síncronas e pesadas: quem chama deve rodá-las
/// em um isolate (`Isolate.run`).

/// A imagem não pôde ser lida pelo decodificador em Dart.
class ImageDecodeException extends ConversionException {
  const ImageDecodeException()
      : super(
          'Não foi possível ler a imagem '
          '(arquivo corrompido ou formato não suportado).',
        );
}

const icoSizes = [256, 128, 64, 48, 32, 24, 16];

/// Lê os quadros de uma imagem já com a rotação EXIF aplicada, em 8 bits
/// RGB ou RGBA. Com [allFrames] falso devolve só o primeiro quadro; de um
/// ICO devolve sempre o maior tamanho.
List<img.Image> decodeFrames(
  Uint8List bytes,
  String extension, {
  bool allFrames = false,
}) {
  img.Image? decoded;
  try {
    if (extension == 'ico') {
      decoded = img.IcoDecoder().decodeImageLargest(bytes);
    } else {
      decoded = img.decodeImage(bytes) ??
          img.decodeNamedImage('arquivo.$extension', bytes);
    }
  } on Object {
    decoded = null;
  }
  if (decoded == null) throw const ImageDecodeException();

  final frames = decoded.numFrames > 1 && allFrames
      ? decoded.frames
      : [decoded.numFrames > 1 ? decoded.frames.first : decoded];
  return [
    for (final frame in frames)
      _normalize(img.bakeOrientation(img.Image.from(frame, noAnimation: true))),
  ];
}

/// Converte para 8 bits por canal, RGB ou RGBA, sem paleta.
img.Image _normalize(img.Image source) {
  final paletteHasAlpha =
      source.hasPalette && source.palette!.numChannels == 4;
  final hasAlpha = source.hasAlpha || paletteHasAlpha;
  final isGray = !source.hasPalette && source.numChannels < 3;
  final result = source.convert(
    format: img.Format.uint8,
    numChannels: hasAlpha ? 4 : 3,
    noAnimation: true,
  );
  if (isGray) {
    // Tons de cinza: replica a luminância nos três canais.
    for (final pixel in result) {
      final l = source.getPixel(pixel.x, pixel.y);
      pixel
        ..r = l.r
        ..g = l.r
        ..b = l.r;
      if (hasAlpha) pixel.a = source.numChannels == 2 ? l.g : 255;
    }
  }
  return result;
}

/// Formatos sem transparência (JPG, BMP, PDF): fundo branco no lugar do preto.
img.Image toOpaque(img.Image source) {
  if (source.numChannels != 4) return source;
  final background = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 3,
  );
  img.fill(background, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(background, source);
  return background;
}

/// Codifica um quadro em PNG, JPG, BMP, GIF ou TIFF.
Uint8List encodeRaster(img.Image image, String format, int jpgQuality) {
  switch (format) {
    case 'png':
      return img.encodePng(image, singleFrame: true);
    case 'jpg':
      return img.encodeJpg(toOpaque(image), quality: jpgQuality);
    case 'bmp':
      return img.encodeBmp(toOpaque(image));
    case 'gif':
      return img.encodeGif(image, singleFrame: true);
    case 'tiff':
      return img.encodeTiff(image, singleFrame: true);
    case 'ico':
      return encodeIco(image);
    default:
      throw ConversionException('Formato de imagem não suportado: $format');
  }
}

/// ICO com vários tamanhos, cada um como PNG embutido.
Uint8List encodeIco(img.Image source) {
  final rgba = source.numChannels == 4
      ? source
      : source.convert(numChannels: 4, alpha: 255);
  final images = <Uint8List>[];
  for (final size in icoSizes) {
    final scale = math.min(size / rgba.width, size / rgba.height);
    final w = math.max(1, (rgba.width * scale).round());
    final h = math.max(1, (rgba.height * scale).round());
    final resized = img.copyResize(
      rgba,
      width: w,
      height: h,
      interpolation: scale < 1
          ? img.Interpolation.average
          : img.Interpolation.cubic,
    );
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    img.compositeImage(
      canvas,
      resized,
      dstX: (size - w) ~/ 2,
      dstY: (size - h) ~/ 2,
      blend: img.BlendMode.direct,
    );
    images.add(img.encodePng(canvas));
  }

  final header = ByteData(6 + 16 * icoSizes.length);
  header
    ..setUint16(0, 0, Endian.little)
    ..setUint16(2, 1, Endian.little)
    ..setUint16(4, icoSizes.length, Endian.little);
  var offset = header.lengthInBytes;
  for (var i = 0; i < icoSizes.length; i++) {
    final entry = 6 + 16 * i;
    final dim = icoSizes[i] >= 256 ? 0 : icoSizes[i];
    header
      ..setUint8(entry, dim)
      ..setUint8(entry + 1, dim)
      ..setUint8(entry + 2, 0)
      ..setUint8(entry + 3, 0)
      ..setUint16(entry + 4, 1, Endian.little)
      ..setUint16(entry + 6, 32, Endian.little)
      ..setUint32(entry + 8, images[i].length, Endian.little)
      ..setUint32(entry + 12, offset, Endian.little);
    offset += images[i].length;
  }
  final builder = BytesBuilder(copy: false)..add(header.buffer.asUint8List());
  images.forEach(builder.add);
  return builder.toBytes();
}

/// Converte um arquivo de imagem e grava em [outputPath].
void convertImageFile(
  String inputPath,
  String outputPath,
  String format,
  int jpgQuality,
) {
  final frames = decodeFrames(
    File(inputPath).readAsBytesSync(),
    p.extension(inputPath).replaceFirst('.', '').toLowerCase(),
  );
  File(outputPath).writeAsBytesSync(
    encodeRaster(frames.first, format, jpgQuality),
    flush: true,
  );
}

/// Codifica pixels BGRA (página de PDF renderizada) em PNG ou JPG.
Uint8List encodeBgraPage(
  Uint8List bgra,
  int width,
  int height,
  String format,
  int jpgQuality,
) {
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: bgra.buffer,
    bytesOffset: bgra.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.bgra,
  );
  // A página já vem com fundo branco: grava sem canal alfa.
  return encodeRaster(toOpaque(image), format, jpgQuality);
}

const double _a4Short = 595.28;
const double _a4Long = 841.89;
const double _marginOneCm = 28.35;

/// Geometria de uma imagem em página A4: orientação conforme a imagem,
/// margem de 1 cm, sem ampliar além do tamanho natural (96 DPI) e centralizada.
class PdfPagePlacement {
  PdfPagePlacement(int pixelWidth, int pixelHeight)
      : pageWidth = pixelWidth > pixelHeight ? _a4Long : _a4Short,
        pageHeight = pixelWidth > pixelHeight ? _a4Short : _a4Long {
    final naturalW = pixelWidth * 72 / 96;
    final naturalH = pixelHeight * 72 / 96;
    final scale = math.min(
      1.0,
      math.min(
        (pageWidth - 2 * _marginOneCm) / naturalW,
        (pageHeight - 2 * _marginOneCm) / naturalH,
      ),
    );
    drawWidth = naturalW * scale;
    drawHeight = naturalH * scale;
  }

  final double pageWidth;
  final double pageHeight;
  late final double drawWidth;
  late final double drawHeight;

  bool get isLandscape => pageWidth > pageHeight;
}

/// Monta um PDF com uma página por quadro de cada imagem. Devolve o número
/// de páginas.
Future<int> writeImagesPdf(
  List<String> imagePaths,
  String outputPath,
  int jpgQuality,
) async {
  final document = pw.Document(compress: false);
  var pages = 0;
  for (final path in imagePaths) {
    final frames = decodeFrames(
      File(path).readAsBytesSync(),
      p.extension(path).replaceFirst('.', '').toLowerCase(),
      allFrames: true,
    );
    for (final frame in frames) {
      final jpeg = img.encodeJpg(toOpaque(frame), quality: jpgQuality);
      final place = PdfPagePlacement(frame.width, frame.height);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(place.pageWidth, place.pageHeight),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Center(
            child: pw.Image(
              pw.MemoryImage(jpeg),
              width: place.drawWidth,
              height: place.drawHeight,
              fit: pw.BoxFit.fill,
            ),
          ),
        ),
      );
      pages++;
    }
  }
  File(outputPath).writeAsBytesSync(await document.save(), flush: true);
  return pages;
}
