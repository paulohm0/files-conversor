import 'dart:io';
import 'dart:typed_data';

import 'package:conversor_arquivos/features/conversion/data/codecs/image_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../../helpers/fakes.dart';

img.Image _transparentRedSquare() {
  final image = img.Image(width: 40, height: 20, numChannels: 4);
  img.fillRect(
    image,
    x1: 10,
    y1: 0,
    x2: 29,
    y2: 19,
    color: img.ColorRgba8(255, 0, 0, 255),
  );
  return image;
}

void main() {
  test('JPG gets a white background where the image was transparent', () {
    final jpg = encodeRaster(_transparentRedSquare(), 'jpg', 95);
    final decoded = img.decodeJpg(jpg)!;
    final corner = decoded.getPixel(0, 0);
    expect(corner.r, greaterThan(240));
    expect(corner.g, greaterThan(240));
    expect(corner.b, greaterThan(240));
  });

  test('BMP is opaque with white background', () {
    final bmp = encodeRaster(_transparentRedSquare(), 'bmp', 85);
    final decoded = img.decodeBmp(bmp)!;
    expect(decoded.getPixel(0, 0).r, 255);
    expect(decoded.getPixel(20, 10).g, 0);
  });

  test('PNG keeps transparency', () {
    final png = encodeRaster(_transparentRedSquare(), 'png', 85);
    final decoded = img.decodePng(png)!;
    expect(decoded.getPixel(0, 0).a, 0);
  });

  test('ICO has the 7 sizes as embedded PNGs', () {
    final ico = encodeIco(_transparentRedSquare());
    final data = ByteData.sublistView(ico);
    expect(data.getUint16(2, Endian.little), 1);
    expect(data.getUint16(4, Endian.little), icoSizes.length);
    final sizes = [
      for (var i = 0; i < icoSizes.length; i++)
        data.getUint8(6 + 16 * i) == 0 ? 256 : data.getUint8(6 + 16 * i),
    ];
    expect(sizes, icoSizes);
    final firstOffset = data.getUint32(6 + 12, Endian.little);
    expect(ico.sublist(firstOffset, firstOffset + 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  test('EXIF orientation 6 rotates the image upright', () {
    final wide = img.Image(width: 40, height: 20)
      ..exif.imageIfd['Orientation'] = 6;
    final jpg = img.encodeJpg(wide);
    final frames = decodeFrames(jpg, 'jpg');
    expect(frames.single.width, 20);
    expect(frames.single.height, 40);
  });

  test('invalid bytes raise a readable error', () {
    expect(
      () => decodeFrames(Uint8List.fromList([1, 2, 3]), 'png'),
      throwsA(isA<ImageDecodeException>()),
    );
  });

  group('PdfPagePlacement', () {
    test('portrait image on portrait A4 with 1 cm margin', () {
      final place = PdfPagePlacement(2000, 3000);
      expect(place.isLandscape, isFalse);
      expect(place.drawWidth, lessThanOrEqualTo(595.28 - 2 * 28.35 + 0.01));
      expect(place.drawHeight, lessThanOrEqualTo(841.89 - 2 * 28.35 + 0.01));
    });

    test('landscape image on landscape A4', () {
      expect(PdfPagePlacement(3000, 2000).isLandscape, isTrue);
    });

    test('small image is not enlarged', () {
      final place = PdfPagePlacement(96, 96);
      expect(place.drawWidth, closeTo(72, 0.001));
    });
  });

  test('writeImagesPdf creates one page per image', () async {
    final dir = createTempDir();
    addTearDown(() => dir.deleteSync(recursive: true));
    final a = File(p.join(dir.path, 'a.png'))
      ..writeAsBytesSync(img.encodePng(_transparentRedSquare()));
    final b = File(p.join(dir.path, 'b.png'))
      ..writeAsBytesSync(img.encodePng(img.Image(width: 10, height: 30)));
    final out = p.join(dir.path, 'saida.pdf');

    final pages = await writeImagesPdf([a.path, b.path], out, 85);

    expect(pages, 2);
    final bytes = File(out).readAsBytesSync();
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(
      RegExp('/Type\\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)),
      hasLength(2),
    );
  });

  test('encodeBgraPage writes an opaque PNG', () {
    final bgra = Uint8List.fromList([
      for (var i = 0; i < 4; i++) ...[255, 0, 0, 255], // azul em BGRA
    ]);
    final png = encodeBgraPage(bgra, 2, 2, 'png', 85);
    final decoded = img.decodePng(png)!;
    expect(decoded.getPixel(0, 0).b, 255);
    expect(decoded.getPixel(0, 0).r, 0);
  });
}
