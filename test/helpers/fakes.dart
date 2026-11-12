import 'dart:io';

import 'package:conversor_arquivos/features/conversion/domain/contracts/conversion_engine.dart';
import 'package:conversor_arquivos/features/conversion/domain/contracts/repositories.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/conversion_result.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/engine_availability.dart';
import 'package:conversor_arquivos/features/settings/domain/app_settings.dart';
import 'package:conversor_arquivos/features/settings/domain/settings_repository.dart';
import 'package:mocktail/mocktail.dart';

/// Motor de teste: grava [content] (ou lança [error]) e registra as chamadas.
class FakeEngine implements ConversionEngine {
  FakeEngine(
    this.name, {
    this.accepts = true,
    this.error,
    this.content = 'ok',
    this.writeBeforeFailing = false,
  });

  @override
  final String name;
  final bool accepts;
  final Object? error;
  final String content;

  /// Grava um parcial antes de falhar, para testar a limpeza.
  final bool writeBeforeFailing;
  int calls = 0;
  String? lastOutput;

  @override
  bool canConvert(ConversionRequest request, EngineAvailability engines) =>
      accepts;

  @override
  Future<ConversionResult> convert(
    ConversionRequest request,
    EngineAvailability engines,
  ) async {
    calls++;
    final output = request.output.allocate(request.target.extension);
    lastOutput = output;
    final failure = error;
    if (failure != null) {
      if (writeBeforeFailing) File(output).writeAsStringSync('parcial');
      throw failure;
    }
    File(output).writeAsStringSync(content);
    return ConversionResult(outputs: [output], engineName: name);
  }
}

class FakeRecycleBin implements RecycleBin {
  FakeRecycleBin({this.succeed = true});

  final bool succeed;
  final List<String> recycled = [];

  @override
  Future<bool> moveToRecycleBin(String path) async {
    if (!succeed) return false;
    File(path).deleteSync();
    recycled.add(path);
    return true;
  }
}

class FakeSession implements EngineSession {
  int closed = 0;

  @override
  Future<void> close() async => closed++;
}

class FakeImagePdfWriter implements ImagePdfWriter {
  List<String>? lastPaths;

  @override
  Future<int> write(
    List<String> imagePaths,
    String outputPath, {
    required int jpgQuality,
  }) async {
    lastPaths = imagePaths;
    File(outputPath).writeAsStringSync('%PDF-fake');
    return imagePaths.length;
  }
}

class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository([this.stored = const AppSettings()]);

  AppSettings stored;
  int saves = 0;

  @override
  Future<AppSettings> load() async => stored;

  @override
  Future<void> save(AppSettings settings) async {
    stored = settings;
    saves++;
  }
}

class MockEngineDetector extends Mock implements EngineDetector {}

class MockClipboardFiles extends Mock implements ClipboardFiles {}

/// Pasta temporária apagada no fim do teste.
Directory createTempDir() =>
    Directory.systemTemp.createTempSync('conversor_teste_');

File touch(Directory dir, String name, [String content = 'x']) =>
    File('${dir.path}${Platform.pathSeparator}$name')
      ..writeAsStringSync(content);
