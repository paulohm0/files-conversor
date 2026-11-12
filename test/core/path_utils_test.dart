import 'dart:io';

import 'package:conversor_arquivos/core/path_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

void main() {
  group('normalizedExtension', () {
    test('unifies jpeg, jfif and tif', () {
      expect(normalizedExtension(r'C:\a\foto.JPEG'), 'jpg');
      expect(normalizedExtension(r'C:\a\foto.jfif'), 'jpg');
      expect(normalizedExtension(r'C:\a\scan.TIF'), 'tiff');
      expect(normalizedExtension(r'C:\a\doc.docx'), 'docx');
    });
  });

  group('uniquePath', () {
    test('never overwrites: adds (1), (2)...', () {
      final taken = {
        p.join('dir', 'nome.pdf'),
        p.join('dir', 'nome (1).pdf'),
      };
      final path = uniquePath('dir', 'nome', 'pdf', exists: taken.contains);
      expect(path, p.join('dir', 'nome (2).pdf'));
    });

    test('keeps the plain name when free', () {
      expect(
        uniquePath('dir', 'nome', 'pdf', exists: (_) => false),
        p.join('dir', 'nome.pdf'),
      );
    });
  });

  group('expandFirstLevel', () {
    late Directory dir;
    setUp(() => dir = createTempDir());
    tearDown(() => dir.deleteSync(recursive: true));

    test('expands folders only one level deep', () {
      touch(dir, 'b.png');
      touch(dir, 'a.pdf');
      final sub = Directory(p.join(dir.path, 'sub'))..createSync();
      touch(sub, 'escondido.png');

      final result = expandFirstLevel([dir.path]);

      expect(result.map(p.basename), ['a.pdf', 'b.png']);
    });

    test('keeps files and ignores missing paths', () {
      final file = touch(dir, 'x.txt');
      expect(
        expandFirstLevel([file.path, p.join(dir.path, 'nao-existe.txt'), '']),
        [file.path],
      );
    });
  });
}
