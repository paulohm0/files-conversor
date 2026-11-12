@Tags(['office'])
library;

import 'dart:io';

import 'package:conversor_arquivos/features/conversion/data/bridge/office_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../helpers/fakes.dart';

/// Usa o script do repositório, sem passar pelo rootBundle.
class _RepoScript implements BridgeScriptLocator {
  @override
  Future<String> locate() async =>
      p.join(Directory.current.path, 'assets', 'office_bridge.ps1');
}

bool _hasCom(String progId) => Process.runSync('reg', [
      'query',
      'HKCR\\$progId\\CLSID',
    ]).exitCode ==
    0;

/// Testa a ponte com o Office instalado. Pulado se o programa não existir.
/// Rodar só estes: `flutter test --tags office`.
void main() {
  late Directory dir;
  late PowerShellOfficeBridge bridge;

  setUp(() {
    dir = createTempDir();
    bridge = PowerShellOfficeBridge(
      _RepoScript(),
      callTimeout: const Duration(minutes: 2),
    );
  });
  tearDown(() async {
    await bridge.close();
    dir.deleteSync(recursive: true);
  });

  test('ping answers with the PowerShell version', () async {
    final data = await bridge.send('ping');
    expect(data['version'], startsWith('5.'));
  });

  test(
    'Excel: CSV to XLS and XLSX in the same session',
    () async {
      final csv = touch(dir, 'c.csv', 'Produto,Qtd\r\nCaneta,10\r\n');
      for (final fmt in ['xls', 'xlsx']) {
        final out = p.join(dir.path, 'c.$fmt');
        await bridge.send('excel', {'in': csv.path, 'out': out, 'fmt': fmt});
        expect(File(out).lengthSync(), greaterThan(0));
      }
    },
    skip: _hasCom('Excel.Application') ? false : 'Excel não instalado',
  );

  test(
    'PowerPoint: sample slides after an Excel call',
    () async {
      final csv = touch(dir, 'c.csv', 'a,b\r\n1,2\r\n');
      await bridge.send('excel', {
        'in': csv.path,
        'out': p.join(dir.path, 'c.xls'),
        'fmt': 'xls',
      });
      final pptx = p.join(dir.path, 's.pptx');
      await bridge.send('sample-slides', {'pptx': pptx, 'ppt': ''});
      expect(File(pptx).lengthSync(), greaterThan(0));
    },
    skip: _hasCom('PowerPoint.Application') ? false : 'PowerPoint ausente',
  );

  test('bridge errors become exceptions with the message', () async {
    await expectLater(
      bridge.send('nao-existe'),
      throwsA(predicate((e) => e.toString().contains('Ação desconhecida'))),
    );
  });
}
