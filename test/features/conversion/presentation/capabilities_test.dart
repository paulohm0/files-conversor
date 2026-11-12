import 'package:conversor_arquivos/features/conversion/domain/entities/engine_availability.dart';
import 'package:conversor_arquivos/features/conversion/presentation/widgets/capabilities_footer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('full Office lists everything and needs no hint', () {
    const c = Capabilities(
      EngineAvailability(
        acrobat: true,
        word: true,
        excel: true,
        powerPoint: true,
      ),
    );
    expect(c.available, [
      'imagens',
      'PDF',
      'documentos',
      'planilhas',
      'apresentações',
    ]);
    expect(c.missingHint, isNull);
    expect(c.technicalDetail, 'Programas encontrados: Acrobat, Word, Excel, '
        'PowerPoint');
  });

  test('LibreOffice alone covers documents, sheets and slides', () {
    const c = Capabilities(EngineAvailability(libreOfficePath: 'soffice.exe'));
    expect(c.available, hasLength(5));
    expect(c.missingHint, isNull);
  });

  test('without Office tells what to install', () {
    const c = Capabilities(EngineAvailability.none);
    expect(c.available, ['imagens', 'PDF']);
    expect(
      c.missingHint,
      'Para converter documentos, planilhas e apresentações, instale o '
      'Microsoft Office ou o LibreOffice (gratuito).',
    );
    expect(c.technicalDetail, 'Programas encontrados: nenhum');
  });

  test('only Word missing sheets and slides', () {
    const c = Capabilities(EngineAvailability(word: true));
    expect(c.missingHint, startsWith('Para converter planilhas e apresentações'));
  });
}
