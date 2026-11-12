import 'dart:io';

import 'package:conversor_arquivos/core/cancellation.dart';
import 'package:conversor_arquivos/core/errors.dart';
import 'package:conversor_arquivos/features/conversion/domain/contracts/conversion_engine.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/conversion_options.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/engine_availability.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/file_category.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/target_format.dart';
import 'package:conversor_arquivos/features/conversion/domain/services/engine_chain.dart';
import 'package:conversor_arquivos/features/conversion/domain/services/output_allocator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fakes.dart';

void main() {
  late Directory dir;
  late File input;

  setUp(() {
    dir = createTempDir();
    input = touch(dir, 'relatorio.docx');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  ConversionRequest request({CancellationToken? cancel}) => ConversionRequest(
        inputPath: input.path,
        category: FileCategory.document,
        options: const ConversionOptions(target: TargetFormat.pdf),
        output: OutputAllocator(sourcePath: input.path),
        cancel: cancel,
      );

  test('uses the first engine that succeeds', () async {
    final word = FakeEngine('Word');
    final libre = FakeEngine('LibreOffice');

    final result = await EngineChain([word, libre])
        .convert(request(), EngineAvailability.none);

    expect(result.engineName, 'Word');
    expect(libre.calls, 0);
  });

  test('falls back and deletes the partial file of the failed engine',
      () async {
    final word = FakeEngine(
      'Word',
      error: Exception('Word travou'),
      writeBeforeFailing: true,
    );
    final libre = FakeEngine('LibreOffice');

    final result = await EngineChain([word, libre])
        .convert(request(), EngineAvailability.none);

    expect(result.engineName, 'LibreOffice');
    // O parcial do Word foi apagado, então o LibreOffice grava no mesmo nome
    // (sem virar "relatorio (1).pdf") e o conteúdo é o dele.
    expect(libre.lastOutput, word.lastOutput);
    expect(File(libre.lastOutput!).readAsStringSync(), 'ok');
    expect(dir.listSync().whereType<File>(), hasLength(2));
  });

  test('joins all errors when every engine fails', () async {
    final chain = EngineChain([
      FakeEngine('Word', error: const ConversionException('erro A')),
      FakeEngine('LibreOffice', error: const ConversionException('erro B')),
    ]);

    expect(
      () => chain.convert(request(), EngineAvailability.none),
      throwsA(
        isA<ConversionException>().having(
          (e) => e.message,
          'message',
          'Word: erro A | LibreOffice: erro B',
        ),
      ),
    );
  });

  test('skips engines that cannot convert', () async {
    final chain = EngineChain([FakeEngine('Word', accepts: false)]);
    expect(
      () => chain.convert(request(), EngineAvailability.none),
      throwsA(
        isA<ConversionException>().having(
          (e) => e.message,
          'message',
          contains('Nenhum motor'),
        ),
      ),
    );
  });

  test('empty output counts as failure', () async {
    final empty = FakeEngine('Word', content: '');
    final libre = FakeEngine('LibreOffice');

    final result = await EngineChain([empty, libre])
        .convert(request(), EngineAvailability.none);

    expect(result.engineName, 'LibreOffice');
  });

  test('reports an engine disabled for the session', () async {
    final disabled = <String>[];
    final chain = EngineChain([
      FakeEngine(
        'Acrobat',
        error: const EngineUnavailableException('Acrobat', 'sem licença'),
      ),
      FakeEngine('Word'),
    ]);

    final result = await chain.convert(
      request(),
      const EngineAvailability(acrobat: true, word: true),
      onEngineDisabled: (engine, _) => disabled.add(engine),
    );

    expect(result.engineName, 'Word');
    expect(disabled, ['Acrobat']);
  });

  test('cancellation stops the chain and cleans up', () async {
    final cancelling = FakeEngine(
      'Word',
      error: const CancelledException(),
      writeBeforeFailing: true,
    );
    final libre = FakeEngine('LibreOffice');

    await expectLater(
      EngineChain([cancelling, libre])
          .convert(request(), EngineAvailability.none),
      throwsA(isA<CancelledException>()),
    );
    expect(libre.calls, 0);
    expect(File(cancelling.lastOutput!).existsSync(), isFalse);
  });
}
