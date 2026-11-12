import 'dart:io';

import 'package:conversor_arquivos/core/process_runner.dart';
import 'package:conversor_arquivos/features/conversion/data/engines/external_engines.dart';
import 'package:conversor_arquivos/features/conversion/data/platform/windows_engine_detector.dart';
import 'package:conversor_arquivos/features/conversion/data/platform/windows_registry.dart';
import 'package:conversor_arquivos/features/conversion/domain/contracts/conversion_engine.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/conversion_options.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/engine_availability.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/file_category.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/target_format.dart';
import 'package:conversor_arquivos/features/conversion/domain/services/output_allocator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/fakes.dart';

class _MockRunner extends Mock implements ProcessRunner {}

class _FakeRegistry implements RegistryReader {
  _FakeRegistry(this.keys, {this.libreOfficeDir});

  final Set<String> keys;
  final String? libreOfficeDir;

  @override
  bool classesRootKeyExists(String subKey) => keys.contains(subKey);

  @override
  String? localMachineDefaultValue(String subKey) => libreOfficeDir;
}

void main() {
  setUpAll(() => registerFallbackValue(Duration.zero));

  late Directory dir;
  setUp(() => dir = createTempDir());
  tearDown(() => dir.deleteSync(recursive: true));

  ConversionRequest request(String name, FileCategory c, TargetFormat t) {
    final input = touch(dir, name);
    return ConversionRequest(
      inputPath: input.path,
      category: c,
      options: ConversionOptions(target: t),
      output: OutputAllocator(sourcePath: input.path),
    );
  }

  group('LibreOfficeEngine', () {
    late _MockRunner runner;
    late Directory temp;
    setUp(() {
      runner = _MockRunner();
      temp = Directory(p.join(dir.path, 'tmp'))..createSync();
    });

    const engines = EngineAvailability(libreOfficePath: r'C:\LO\soffice.exe');

    test('uses its own profile, headless, and moves the output', () async {
      final engine = LibreOfficeEngine(runner, tempDir: temp.path);
      final req = request('a.docx', FileCategory.document, TargetFormat.pdf);
      late List<String> args;
      when(() => runner.run(any(), any(), timeout: any(named: 'timeout')))
          .thenAnswer((call) async {
        args = call.positionalArguments[1] as List<String>;
        final outDir = args[args.indexOf('--outdir') + 1];
        File(p.join(outDir, 'a.pdf')).writeAsStringSync('%PDF');
        return const ProcessOutput(0, '', '');
      });

      final result = await engine.convert(req, engines);

      expect(args, contains('--headless'));
      expect(args.first, startsWith('-env:UserInstallation=file:///'));
      expect(args, isNot(contains('--infilter=writer_pdf_import')));
      expect(File(result.outputs.single).readAsStringSync(), '%PDF');
      expect(result.engineName, 'LibreOffice');
    });

    test('PDF to DOCX uses the Writer PDF import filter', () async {
      final engine = LibreOfficeEngine(runner, tempDir: temp.path);
      final req = request('a.pdf', FileCategory.pdf, TargetFormat.docx);
      late List<String> args;
      when(() => runner.run(any(), any(), timeout: any(named: 'timeout')))
          .thenAnswer((call) async {
        args = call.positionalArguments[1] as List<String>;
        final outDir = args[args.indexOf('--outdir') + 1];
        File(p.join(outDir, 'a.docx')).writeAsStringSync('PK');
        return const ProcessOutput(0, '', '');
      });

      await engine.convert(req, engines);
      expect(args, contains('--infilter=writer_pdf_import'));
    });

    test('fails with the tool output when nothing is produced', () async {
      final engine = LibreOfficeEngine(runner, tempDir: temp.path);
      when(() => runner.run(any(), any(), timeout: any(named: 'timeout')))
          .thenAnswer((_) async => const ProcessOutput(1, '', 'erro X'));

      await expectLater(
        engine.convert(
          request('a.docx', FileCategory.document, TargetFormat.pdf),
          engines,
        ),
        throwsA(predicate((e) => e.toString().contains('erro X'))),
      );
    });

    test('only handles office conversions when installed', () {
      final engine = LibreOfficeEngine(runner);
      final img = request('a.png', FileCategory.image, TargetFormat.pdf);
      final doc = request('b.docx', FileCategory.document, TargetFormat.odt);
      expect(engine.canConvert(img, engines), isFalse);
      expect(engine.canConvert(doc, engines), isTrue);
      expect(engine.canConvert(doc, EngineAvailability.none), isFalse);
    });
  });

  group('WindowsEngineDetector', () {
    test('finds COM engines and LibreOffice next to the app', () async {
      final appDir = dir.path;
      final soffice =
          p.join(appDir, 'engines', 'LibreOffice', 'program', 'soffice.exe');
      final detector = WindowsEngineDetector(
        _FakeRegistry({
          r'Word.Application\CLSID',
          r'AcroExch.App\CLSID',
        }),
        appDir: appDir,
        environment: const {'PATH': ''},
        fileExists: (path) => path == soffice,
      );

      final found = await detector.detect();

      expect(found.word, isTrue);
      expect(found.excel, isFalse);
      expect(found.acrobat, isFalse, reason: 'precisa de App e PDDoc');
      expect(found.libreOfficePath, soffice);
      expect(found.pdf2Docx, isFalse);
    });

    test('finds LibreOffice by the registry and pdf2docx in PATH', () async {
      final detector = WindowsEngineDetector(
        _FakeRegistry({}, libreOfficeDir: r'D:\LO\program'),
        appDir: r'C:\app',
        environment: const {'Path': r'C:\py\Scripts;C:\outro'},
        fileExists: (path) =>
            path == r'D:\LO\program\soffice.exe' ||
            path == r'C:\py\Scripts\pdf2docx.exe',
      );

      final found = await detector.detect();

      expect(found.libreOfficePath, r'D:\LO\program\soffice.exe');
      expect(found.pdf2DocxPath, r'C:\py\Scripts\pdf2docx.exe');
    });
  });
}
