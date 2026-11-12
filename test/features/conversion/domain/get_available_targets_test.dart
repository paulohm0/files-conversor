import 'package:conversor_arquivos/features/conversion/domain/entities/engine_availability.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/file_category.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/target_format.dart';
import 'package:conversor_arquivos/features/conversion/domain/usecases/get_available_targets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const targets = GetAvailableTargets();
  const T = TargetFormat.values;

  test('images always offer the native formats', () {
    expect(
      targets([FileCategory.image], EngineAvailability.none),
      [
        TargetFormat.pdf,
        TargetFormat.png,
        TargetFormat.jpg,
        TargetFormat.bmp,
        TargetFormat.gif,
        TargetFormat.tiff,
        TargetFormat.ico,
      ],
    );
  });

  test('PDF without engines only goes to images', () {
    expect(
      targets([FileCategory.pdf], EngineAvailability.none),
      [TargetFormat.png, TargetFormat.jpg],
    );
  });

  test('PDF to XLSX and PPTX only with Acrobat', () {
    final withWord = targets(
      [FileCategory.pdf],
      const EngineAvailability(word: true),
    );
    expect(withWord, contains(TargetFormat.docx));
    expect(withWord, isNot(contains(TargetFormat.xlsx)));

    final withAcrobat = targets(
      [FileCategory.pdf],
      const EngineAvailability(acrobat: true),
    );
    expect(withAcrobat, containsAll([TargetFormat.xlsx, TargetFormat.pptx]));
  });

  test('documents need Word or LibreOffice', () {
    expect(targets([FileCategory.document], EngineAvailability.none), isEmpty);
    expect(
      targets(
        [FileCategory.document],
        const EngineAvailability(libreOfficePath: 'soffice.exe'),
      ),
      [T[0], T[1], T[2], T[3], T[4], T[5]],
    );
  });

  test('mixed list only shows common formats', () {
    final common = targets(
      [FileCategory.image, FileCategory.document],
      const EngineAvailability(word: true),
    );
    expect(common, [TargetFormat.pdf]);
  });

  test('empty list has no formats', () {
    expect(targets(const [], const EngineAvailability(word: true)), isEmpty);
  });
}
