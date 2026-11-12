import 'package:conversor_arquivos/features/integration/domain/ensure_system_integration.dart';
import 'package:conversor_arquivos/features/integration/domain/system_integration.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSystem implements SystemIntegration {
  bool shortcut = false;
  int installs = 0;
  bool failInstall = false;

  @override
  bool sendToShortcutExists() => shortcut;

  @override
  Future<void> installSendToShortcut(String executable) async {
    if (failInstall) throw Exception('sem permissão');
    installs++;
    shortcut = true;
  }
}

void main() {
  const exe = r'C:\Apps\Conversor\conversor_arquivos.exe';
  late _FakeSystem system;
  late EnsureSystemIntegration ensure;

  setUp(() {
    system = _FakeSystem();
    ensure = EnsureSystemIntegration(system, executable: exe);
  });

  group('Enviar para (obrigatório)', () {
    test('installs when the shortcut is missing', () async {
      final result = await ensure.ensureSendTo('');
      expect(system.installs, 1);
      expect(result.newTarget, exe);
      expect(result.message, contains('instalado'));
    });

    test('does nothing when it already points to this executable', () async {
      system.shortcut = true;
      final result = await ensure.ensureSendTo(exe.toUpperCase());
      expect(system.installs, 0);
      expect(result.newTarget, isNull);
      expect(result.message, isNull);
    });

    test('reinstalls when the app moved to another folder', () async {
      system.shortcut = true;
      final result = await ensure.ensureSendTo(r'D:\antigo\conversor.exe');
      expect(system.installs, 1);
      expect(result.newTarget, exe);
    });

    test('reports a failure without throwing', () async {
      system.failInstall = true;
      final result = await ensure.ensureSendTo('');
      expect(result.newTarget, isNull);
      expect(result.message, contains('Não foi possível'));
    });
  });
}
