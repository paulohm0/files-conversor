import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/conversion/data/bridge/office_bridge.dart';
import '../features/conversion/data/engines/external_engines.dart';
import '../features/conversion/data/engines/image_engines.dart';
import '../features/conversion/data/engines/office_engines.dart';
import '../features/conversion/data/engines/pdf_raster_engine.dart';
import '../features/conversion/data/platform/windows_engine_detector.dart';
import '../features/conversion/data/platform/windows_registry.dart';
import '../features/conversion/data/platform/windows_shell.dart';
import '../features/conversion/domain/contracts/repositories.dart';
import '../features/conversion/domain/services/engine_chain.dart';
import '../features/conversion/domain/usecases/convert_files.dart';
import '../features/conversion/domain/usecases/detect_engines.dart';
import '../features/conversion/domain/usecases/get_available_targets.dart';
import '../features/conversion/domain/usecases/merge_images_to_pdf.dart';
import '../features/conversion/presentation/cubit/conversion_cubit.dart';
import '../features/conversion/presentation/cubit/engines_cubit.dart';
import '../features/diagnostics/data/file_sample_factory.dart';
import '../features/diagnostics/domain/diagnostic_models.dart';
import '../features/diagnostics/domain/run_diagnostics.dart';
import '../features/diagnostics/presentation/diagnostics_cubit.dart';
import '../features/integration/data/windows_system_integration.dart';
import '../features/integration/domain/ensure_system_integration.dart';
import '../features/integration/domain/system_integration.dart';
import '../features/settings/data/shared_prefs_settings_repository.dart';
import '../features/settings/domain/settings_repository.dart';
import '../features/settings/presentation/settings_cubit.dart';
import 'process_runner.dart';

final sl = GetIt.instance;

/// Registra as dependências: infraestrutura e casos de uso como singletons,
/// Cubits como factories.
Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();

  sl
    // Infraestrutura
    ..registerLazySingleton<ProcessRunner>(() => const SystemProcessRunner())
    ..registerLazySingleton<RegistryReader>(() => const Win32RegistryReader())
    ..registerLazySingleton<BridgeScriptLocator>(AssetBridgeScriptLocator.new)
    ..registerLazySingleton<OfficeBridge>(() => PowerShellOfficeBridge(sl()))
    ..registerLazySingleton<EngineSession>(sl.call<OfficeBridge>)
    ..registerLazySingleton<WicImageReader>(() => BridgeWicImageReader(sl()))
    ..registerLazySingleton(() => ImageSourceResolver(sl()))
    ..registerLazySingleton<ImagePdfWriter>(() => IsolateImagePdfWriter(sl()))
    ..registerLazySingleton<PdfRenderer>(() => const PdfrxRenderer())
    ..registerLazySingleton<EngineDetector>(() => WindowsEngineDetector(sl()))
    ..registerLazySingleton<RecycleBin>(() => const WindowsRecycleBin())
    ..registerLazySingleton<ShellIntegration>(
      () => const WindowsShellIntegration(),
    )
    ..registerLazySingleton<SystemIntegration>(
      () => WindowsSystemIntegration(sl()),
    )
    ..registerLazySingleton(
      () => EnsureSystemIntegration(
        sl(),
        executable: Platform.resolvedExecutable,
      ),
    )
    ..registerLazySingleton<ClipboardFiles>(() => const SuperClipboardFiles())
    ..registerLazySingleton<SettingsRepository>(
      () => SharedPrefsSettingsRepository(prefs),
    )
    ..registerLazySingleton<SampleFactory>(() => FileSampleFactory(sl()))
    // Motores, em ordem de prioridade
    ..registerLazySingleton(
      () => EngineChain([
        ImageEngine(sl()),
        ImagePdfEngine(sl()),
        PdfRasterEngine(sl()),
        AcrobatEngine(sl()),
        WordEngine(sl()),
        ExcelEngine(sl()),
        PowerPointEngine(sl()),
        Pdf2DocxEngine(sl()),
        LibreOfficeEngine(sl()),
      ]),
    )
    // Casos de uso
    ..registerLazySingleton(() => const GetAvailableTargets())
    ..registerLazySingleton(() => DetectEngines(sl()))
    ..registerLazySingleton(() => MergeImagesToPdf(sl()))
    ..registerLazySingleton(
      () => ConvertFiles(
        chain: sl(),
        mergeImages: sl(),
        recycleBin: sl(),
        session: sl(),
      ),
    )
    ..registerLazySingleton(
      () => RunDiagnostics(convertFiles: sl(), getTargets: sl(), samples: sl()),
    )
    // Cubits
    ..registerFactory(() => ConversionCubit(convertFiles: sl(), clipboard: sl()))
    ..registerFactory(() => EnginesCubit(sl()))
    ..registerFactory(() => SettingsCubit(sl()))
    ..registerFactory(() => DiagnosticsCubit(sl()));
}
