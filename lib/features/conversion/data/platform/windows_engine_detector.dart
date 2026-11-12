import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/contracts/repositories.dart';
import '../../domain/entities/engine_availability.dart';
import 'windows_registry.dart';

/// Procura os motores: COM pelo registro; LibreOffice e pdf2docx em
/// `engines\` ao lado do executável, em Arquivos de Programas, no registro e
/// no PATH.
class WindowsEngineDetector implements EngineDetector {
  WindowsEngineDetector(
    this._registry, {
    String? appDir,
    Map<String, String>? environment,
    bool Function(String path)? fileExists,
  })  : _appDir = appDir ?? p.dirname(Platform.resolvedExecutable),
        _env = environment ?? Platform.environment,
        _exists = fileExists ?? ((path) => File(path).existsSync());

  final RegistryReader _registry;
  final String _appDir;
  final Map<String, String> _env;
  final bool Function(String path) _exists;

  @override
  Future<EngineAvailability> detect() async => EngineAvailability(
        acrobat: _hasCom('AcroExch.App') && _hasCom('AcroExch.PDDoc'),
        word: _hasCom('Word.Application'),
        excel: _hasCom('Excel.Application'),
        powerPoint: _hasCom('PowerPoint.Application'),
        libreOfficePath: findLibreOffice(),
        pdf2DocxPath: findPdf2Docx(),
      );

  bool _hasCom(String progId) =>
      _registry.classesRootKeyExists('$progId\\CLSID');

  String? _envValue(String name) {
    for (final entry in _env.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
    }
    return null;
  }

  String? findLibreOffice() {
    final programFiles = _envValue('ProgramFiles');
    final programFilesX86 = _envValue('ProgramFiles(x86)');
    final registryDir =
        _registry.localMachineDefaultValue(r'SOFTWARE\LibreOffice\UNO\InstallPath');
    final candidates = [
      p.join(_appDir, 'engines', 'LibreOffice', 'program', 'soffice.exe'),
      p.join(
        _appDir,
        'engines',
        'LibreOfficePortable',
        'App',
        'libreoffice',
        'program',
        'soffice.exe',
      ),
      if (programFiles != null)
        p.join(programFiles, 'LibreOffice', 'program', 'soffice.exe'),
      if (programFilesX86 != null)
        p.join(programFilesX86, 'LibreOffice', 'program', 'soffice.exe'),
      if (registryDir != null) p.join(registryDir, 'soffice.exe'),
    ];
    return _firstExisting(candidates);
  }

  String? findPdf2Docx() {
    final pathDirs = (_envValue('PATH') ?? '')
        .split(';')
        .map((d) => d.trim().replaceAll('"', ''))
        .where((d) => d.isNotEmpty);
    final candidates = [
      p.join(_appDir, 'engines', 'pdf2docx', 'pdf2docx.exe'),
      p.join(_appDir, 'engines', 'pdf2docx.exe'),
      for (final dir in pathDirs) p.join(dir, 'pdf2docx.exe'),
    ];
    return _firstExisting(candidates);
  }

  String? _firstExisting(List<String> candidates) {
    for (final candidate in candidates) {
      if (_exists(candidate)) return candidate;
    }
    return null;
  }
}
