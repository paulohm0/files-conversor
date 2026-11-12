import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:window_manager/window_manager.dart';

import 'core/di.dart';
import 'core/theme.dart';
import 'features/conversion/data/platform/file_selector_dialogs.dart';
import 'features/conversion/presentation/cubit/conversion_cubit.dart';
import 'features/conversion/presentation/cubit/engines_cubit.dart';
import 'features/conversion/presentation/pages/home_page.dart';
import 'features/diagnostics/presentation/diagnostics_cubit.dart';
import 'features/diagnostics/presentation/headless_self_test.dart';
import 'features/settings/presentation/settings_cubit.dart';

/// [args]: arquivos recebidos pelo "Enviar para" do Explorer, ou
/// `--autoteste [pasta]` para rodar o diagnóstico sem abrir a janela.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (args.isNotEmpty && args.first == '--autoteste') {
    await pdfrxFlutterInitialize();
    await configureDependencies();
    exit(await runHeadlessSelfTest(args.length > 1 ? args[1] : null));
  }
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'Conversor de Arquivos',
      size: Size(1000, 760),
      minimumSize: Size(860, 640),
      center: true,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  await pdfrxFlutterInitialize();
  await configureDependencies();

  final settings = sl<SettingsCubit>();
  await settings.load();
  final engines = sl<EnginesCubit>();
  final conversion = sl<ConversionCubit>()
    ..addLog(
      'Pronto. Arraste arquivos, cole com Ctrl+V ou use o botão direito do '
      'Explorer (Enviar para).',
    );

  // A detecção lê o registro e o disco: não segura a abertura da janela.
  unawaited(
    engines.detect().then((_) {
      final found = engines.state.availability;
      if (!found.word && !found.libreOffice) {
        conversion
          ..addLog(
            'AVISO: nem Word nem LibreOffice foram encontrados. Só imagens e '
            'PDF->imagem estarão disponíveis.',
            isError: true,
          )
          ..addLog(
            '       Instale o LibreOffice (gratuito) ou coloque-o em '
            r'engines\LibreOffice para converter documentos.',
          );
        unawaited(settings.update((s) => s.copyWith(showLog: true)));
      }
    }),
  );
  if (args.isNotEmpty) conversion.addPaths(args);

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: settings),
        BlocProvider.value(value: engines),
        BlocProvider.value(value: conversion),
      ],
      child: const ConverterApp(),
    ),
  );
}

class ConverterApp extends StatelessWidget {
  const ConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conversor de Arquivos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('pt', 'BR'),
      home: HomePage(
        getTargets: sl(),
        dialogs: const FileSelectorDialogs(),
        shell: sl(),
        createDiagnosticsCubit: sl.call<DiagnosticsCubit>,
      ),
    );
  }
}
