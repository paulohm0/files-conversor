import 'dart:io';

import 'package:conversor_arquivos/core/theme.dart';
import 'package:conversor_arquivos/features/conversion/domain/contracts/repositories.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/engine_availability.dart';
import 'package:conversor_arquivos/features/conversion/domain/services/engine_chain.dart';
import 'package:conversor_arquivos/features/conversion/domain/usecases/convert_files.dart';
import 'package:conversor_arquivos/features/conversion/domain/usecases/detect_engines.dart';
import 'package:conversor_arquivos/features/conversion/domain/usecases/get_available_targets.dart';
import 'package:conversor_arquivos/features/conversion/domain/usecases/merge_images_to_pdf.dart';
import 'package:conversor_arquivos/features/conversion/presentation/cubit/conversion_cubit.dart';
import 'package:conversor_arquivos/features/conversion/presentation/cubit/engines_cubit.dart';
import 'package:conversor_arquivos/features/conversion/presentation/pages/home_page.dart';
import 'package:conversor_arquivos/features/diagnostics/domain/run_diagnostics.dart';
import 'package:conversor_arquivos/features/diagnostics/presentation/diagnostics_cubit.dart';
import 'package:conversor_arquivos/features/settings/domain/app_settings.dart';
import 'package:conversor_arquivos/features/settings/presentation/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fakes.dart';

class _MockDialogs extends Mock implements FileDialogs {}

class _MockShell extends Mock implements ShellIntegration {}

class _MockRunDiagnostics extends Mock implements RunDiagnostics {}

void main() {
  late Directory dir;
  late _MockDialogs dialogs;
  late ConversionCubit conversion;
  late SettingsCubit settings;
  late EnginesCubit engines;

  setUp(() async {
    dir = createTempDir();
    dialogs = _MockDialogs();
    final detector = MockEngineDetector();
    when(detector.detect)
        .thenAnswer((_) async => const EngineAvailability(word: true));
    engines = EnginesCubit(DetectEngines(detector));
    await engines.detect();
    settings = SettingsCubit(InMemorySettingsRepository());
    conversion = ConversionCubit(
      convertFiles: ConvertFiles(
        chain: EngineChain([FakeEngine('Word')]),
        mergeImages: MergeImagesToPdf(FakeImagePdfWriter()),
        recycleBin: FakeRecycleBin(),
        session: FakeSession(),
      ),
      clipboard: MockClipboardFiles(),
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: settings),
          BlocProvider.value(value: engines),
          BlocProvider.value(value: conversion),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: HomePage(
            getTargets: const GetAvailableTargets(),
            dialogs: dialogs,
            shell: _MockShell(),
            createDiagnosticsCubit: () =>
                DiagnosticsCubit(_MockRunDiagnostics()),
          ),
        ),
      ),
    );
  }

  testWidgets('empty list shows the drop area and no formats', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('empty-drop-area')), findsOneWidget);
    expect(
      find.text('Adicione arquivos para ver os formatos disponíveis.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('engines-footer')), findsOneWidget);
  });

  testWidgets('clicking the drop area opens the file dialog', (tester) async {
    final file = touch(dir, 'carta.docx').path;
    when(() => dialogs.pickFiles()).thenAnswer((_) async => [file]);
    await pump(tester);

    await tester.tap(find.byKey(const Key('empty-drop-area')));
    await tester.pumpAndSettle();

    expect(find.text('carta.docx'), findsOneWidget);
    expect(find.byKey(const Key('format-pdf')), findsOneWidget);
    expect(find.byKey(const Key('format-png')), findsNothing);
  });

  testWidgets('format button asks for confirmation and converts',
      (tester) async {
    await settings.update((s) => s.copyWith(deleteOriginal: false));
    conversion.addPaths([touch(dir, 'carta.docx').path]);
    await pump(tester);

    await tester.tap(find.byKey(const Key('format-odt')));
    await tester.pumpAndSettle();
    expect(find.text('Converter 1 arquivo(s) para ODT (OpenDocument)?'),
        findsOneWidget);
    expect(find.byKey(const Key('recycle-warning')), findsNothing);

    await tester.tap(find.byKey(const Key('dont-ask-again')));
    await tester.tap(find.byKey(const Key('confirm-convert')));
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 200),
        ));
    await tester.pumpAndSettle();

    expect(find.text('Concluído'), findsOneWidget);
    expect(settings.state.confirmBeforeConvert, isFalse);
    expect(settings.state.lastTarget.name, 'odt');
  });

  testWidgets('confirmation warns in red when originals go to the bin',
      (tester) async {
    await settings
        .update((s) => s.copyWith(deleteOriginal: true, showOptions: false));
    conversion.addPaths([touch(dir, 'carta.docx').path]);
    await pump(tester);

    await tester.tap(find.byKey(const Key('format-pdf')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recycle-warning')), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Pendente'), findsOneWidget);
  });

  testWidgets('log panel toggles', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('log-panel')), findsNothing);
    await tester.tap(find.byKey(const Key('log-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('log-panel')), findsOneWidget);
    expect(settings.state, const AppSettings(showLog: true));
  });
}
