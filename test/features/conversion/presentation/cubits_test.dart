import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/conversion_job.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/conversion_options.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/engine_availability.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/target_format.dart';
import 'package:conversor_arquivos/features/conversion/domain/services/engine_chain.dart';
import 'package:conversor_arquivos/features/conversion/domain/usecases/convert_files.dart';
import 'package:conversor_arquivos/features/conversion/domain/usecases/detect_engines.dart';
import 'package:conversor_arquivos/features/conversion/domain/usecases/merge_images_to_pdf.dart';
import 'package:conversor_arquivos/features/conversion/presentation/cubit/conversion_cubit.dart';
import 'package:conversor_arquivos/features/conversion/presentation/cubit/conversion_state.dart';
import 'package:conversor_arquivos/features/conversion/presentation/cubit/engines_cubit.dart';
import 'package:conversor_arquivos/features/settings/domain/app_settings.dart';
import 'package:conversor_arquivos/features/settings/presentation/settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fakes.dart';

void main() {
  late Directory dir;
  late MockClipboardFiles clipboard;
  setUp(() {
    dir = createTempDir();
    clipboard = MockClipboardFiles();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  ConversionCubit buildCubit({FakeEngine? engine}) => ConversionCubit(
        convertFiles: ConvertFiles(
          chain: EngineChain([engine ?? FakeEngine('Word')]),
          mergeImages: MergeImagesToPdf(FakeImagePdfWriter()),
          recycleBin: FakeRecycleBin(),
          session: FakeSession(),
        ),
        clipboard: clipboard,
        clock: () => DateTime(2026, 1, 2, 10, 30),
      );

  group('ConversionCubit list', () {
    test('adds supported files and logs the unsupported ones', () {
      final cubit = buildCubit();
      cubit.addPaths([
        touch(dir, 'a.docx').path,
        touch(dir, 'b.exe').path,
      ]);
      expect(cubit.state.jobs.map((j) => j.fileName), ['a.docx']);
      expect(cubit.state.log.last.text, contains('b.exe'));
    });

    test('re-adding a converted file makes it pending again', () async {
      final cubit = buildCubit();
      final file = touch(dir, 'a.docx').path;
      cubit.addPaths([file]);
      await cubit.start(
        const ConversionOptions(target: TargetFormat.pdf),
        EngineAvailability.none,
      );
      expect(cubit.state.jobs.single.state, JobState.done);

      cubit.addPaths([file]);

      expect(cubit.state.jobs, hasLength(1));
      expect(cubit.state.jobs.single.state, JobState.pending);
    });

    test('selection drives what gets converted', () {
      final cubit = buildCubit()
        ..addPaths([touch(dir, 'a.docx').path, touch(dir, 'b.docx').path]);
      final second = cubit.state.jobs[1].id;

      expect(cubit.state.jobsToConvert, hasLength(2));
      cubit.select(second);
      expect(cubit.state.jobsToConvert.single.id, second);
      cubit.selectAll();
      expect(cubit.state.selectedIds, hasLength(2));
      cubit.removeSelected();
      expect(cubit.state.jobs, isEmpty);
    });

    test('shift selects a range and ctrl toggles', () {
      final cubit = buildCubit()
        ..addPaths([
          for (final n in ['a', 'b', 'c', 'd']) touch(dir, '$n.docx').path,
        ]);
      final ids = cubit.state.jobs.map((j) => j.id).toList();

      cubit
        ..select(ids[0])
        ..select(ids[2], range: true);
      expect(cubit.state.selectedIds, ids.sublist(0, 3).toSet());

      cubit.select(ids[1], toggle: true);
      expect(cubit.state.selectedIds, {ids[0], ids[2]});
    });

    test('paste with empty clipboard logs a hint', () async {
      when(() => clipboard.readFilePaths()).thenAnswer((_) async => []);
      final cubit = buildCubit();
      await cubit.addFromClipboard();
      expect(cubit.state.log.last.text, contains('Ctrl+C'));
    });
  });

  group('ConversionCubit conversion', () {
    blocTest<ConversionCubit, ConversionState>(
      'marks the job as done and reports the run summary',
      build: buildCubit,
      act: (cubit) async {
        cubit.addPaths([touch(dir, 'a.docx').path]);
        await cubit.start(
          const ConversionOptions(target: TargetFormat.pdf),
          EngineAvailability.none,
        );
      },
      verify: (cubit) {
        final job = cubit.state.jobs.single;
        expect(job.state, JobState.done);
        expect(job.statusText, 'Concluído');
        expect(job.finishedAt, DateTime(2026, 1, 2, 10, 30));
        expect(cubit.state.running, isFalse);
        expect(cubit.state.lastRun!.ok, 1);
        expect(cubit.state.statusLabel, 'Concluído: 1 ok, 0 com erro');
      },
    );

    blocTest<ConversionCubit, ConversionState>(
      'failed conversion keeps the error in the log',
      build: () => buildCubit(engine: FakeEngine('Word', error: 'quebrou')),
      act: (cubit) async {
        cubit.addPaths([touch(dir, 'a.docx').path]);
        await cubit.start(
          const ConversionOptions(target: TargetFormat.pdf),
          EngineAvailability.none,
        );
      },
      verify: (cubit) {
        expect(cubit.state.jobs.single.state, JobState.error);
        expect(cubit.state.lastRun!.failed, 1);
        expect(
          cubit.state.log.where((l) => l.isError).map((l) => l.text),
          contains(contains('quebrou')),
        );
      },
    );

    test('missing originals are skipped with a log message', () async {
      final cubit = buildCubit();
      final file = touch(dir, 'a.docx');
      cubit.addPaths([file.path]);
      file.deleteSync();

      await cubit.start(
        const ConversionOptions(target: TargetFormat.pdf),
        EngineAvailability.none,
      );

      expect(cubit.state.lastRun, isNull);
      expect(cubit.state.log.last.text, contains('Original não encontrado'));
    });
  });

  group('EnginesCubit', () {
    late MockEngineDetector detector;
    setUp(() => detector = MockEngineDetector());

    blocTest<EnginesCubit, EnginesState>(
      'detects and disables an engine for the session',
      setUp: () => when(() => detector.detect()).thenAnswer(
        (_) async => const EngineAvailability(acrobat: true, word: true),
      ),
      build: () => EnginesCubit(DetectEngines(detector)),
      act: (cubit) async {
        await cubit.detect();
        cubit.disable('Acrobat');
      },
      expect: () => const [
        EnginesState(
          availability: EngineAvailability(acrobat: true, word: true),
          detected: true,
        ),
        EnginesState(
          availability: EngineAvailability(word: true),
          detected: true,
        ),
      ],
    );
  });

  group('SettingsCubit', () {
    late InMemorySettingsRepository repository;
    setUp(() => repository = InMemorySettingsRepository());

    blocTest<SettingsCubit, AppSettings>(
      'loads and persists every change',
      setUp: () => repository.stored = const AppSettings(jpgPreset: 2),
      build: () => SettingsCubit(repository),
      act: (cubit) async {
        await cubit.load();
        await cubit.update((s) => s.copyWith(deleteOriginal: true));
        await cubit.update((s) => s.copyWith(deleteOriginal: true));
      },
      expect: () => const [
        AppSettings(jpgPreset: 2),
        AppSettings(jpgPreset: 2, deleteOriginal: true),
      ],
      verify: (_) {
        expect(repository.saves, 1);
        expect(repository.stored.deleteOriginal, isTrue);
      },
    );

    test('options use the other folder only when chosen and filled', () {
      const s = AppSettings(useOtherFolder: true, outputDir: '  ');
      expect(s.toOptions(TargetFormat.pdf).outputDir, isNull);
      expect(
        s.copyWith(outputDir: r'C:\saida').toOptions(TargetFormat.jpg),
        const ConversionOptions(
          target: TargetFormat.jpg,
          outputDir: r'C:\saida',
        ),
      );
    });
  });
}
