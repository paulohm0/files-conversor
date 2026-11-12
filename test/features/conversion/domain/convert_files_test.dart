import 'dart:io';

import 'package:conversor_arquivos/core/cancellation.dart';
import 'package:conversor_arquivos/features/conversion/domain/contracts/conversion_engine.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/conversion_job.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/conversion_options.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/conversion_result.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/engine_availability.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/file_category.dart';
import 'package:conversor_arquivos/features/conversion/domain/entities/target_format.dart';
import 'package:conversor_arquivos/features/conversion/domain/services/engine_chain.dart';
import 'package:conversor_arquivos/features/conversion/domain/usecases/convert_files.dart';
import 'package:conversor_arquivos/features/conversion/domain/usecases/merge_images_to_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../../helpers/fakes.dart';

/// Motor de "páginas": grava várias saídas e cancela no meio.
class _PagedEngine implements ConversionEngine {
  _PagedEngine(this.cancel);

  final CancellationToken cancel;
  final written = <String>[];

  @override
  String get name => nativeName;

  @override
  bool canConvert(ConversionRequest request, EngineAvailability engines) =>
      true;

  @override
  Future<ConversionResult> convert(
    ConversionRequest request,
    EngineAvailability engines,
  ) async {
    for (var i = 1; i <= 3; i++) {
      request.cancel.throwIfCancelled();
      final out = request.output.allocate('png', suffix: '_pagina0$i');
      File(out).writeAsStringSync('page');
      written.add(out);
      if (i == 2) cancel.cancel();
    }
    return ConversionResult(outputs: written);
  }
}

void main() {
  late Directory dir;
  late FakeRecycleBin recycle;
  late FakeSession session;
  late FakeImagePdfWriter pdfWriter;

  setUp(() {
    dir = createTempDir();
    recycle = FakeRecycleBin();
    session = FakeSession();
    pdfWriter = FakeImagePdfWriter();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  ConvertFiles build(List<ConversionEngine> engines) => ConvertFiles(
        chain: EngineChain(engines),
        mergeImages: MergeImagesToPdf(pdfWriter),
        recycleBin: recycle,
        session: session,
      );

  ConversionJob job(int id, String name, FileCategory category) =>
      ConversionJob(id: id, path: touch(dir, name).path, category: category);

  Future<List<ConversionEvent>> run(
    ConvertFiles convert,
    List<ConversionJob> jobs,
    ConversionOptions options, {
    CancellationToken? cancel,
  }) =>
      convert(jobs, options, EngineAvailability.none, cancel: cancel).toList();

  test('converts, reports progress and closes the engine session', () async {
    final events = await run(
      build([FakeEngine('Word')]),
      [job(1, 'a.docx', FileCategory.document)],
      const ConversionOptions(target: TargetFormat.pdf),
    );

    final finished = events.whereType<BatchFinished>().single;
    expect(finished.ok, 1);
    expect(finished.failed, 0);
    expect(finished.folders, [dir.path]);
    expect(events.whereType<ProgressChanged>().last.done, 1);
    expect(
      events.whereType<JobStatusChanged>().last.state,
      JobState.done,
    );
    expect(session.closed, 1);
    expect(File(p.join(dir.path, 'a.pdf')).existsSync(), isTrue);
  });

  test('never overwrites an existing output', () async {
    touch(dir, 'a.pdf', 'antigo');
    await run(
      build([FakeEngine('Word')]),
      [job(1, 'a.docx', FileCategory.document)],
      const ConversionOptions(target: TargetFormat.pdf),
    );
    expect(File(p.join(dir.path, 'a.pdf')).readAsStringSync(), 'antigo');
    expect(File(p.join(dir.path, 'a (1).pdf')).existsSync(), isTrue);
  });

  test('skips files already in the target format (except images)', () async {
    final engine = FakeEngine('Word');
    final events = await run(
      build([engine]),
      [job(1, 'a.pdf', FileCategory.pdf)],
      const ConversionOptions(target: TargetFormat.pdf),
    );
    expect(engine.calls, 0);
    expect(
      events.whereType<JobStatusChanged>().single.state,
      JobState.skipped,
    );
  });

  test('images in the same format are converted again', () async {
    final engine = FakeEngine(nativeName);
    await run(
      build([engine]),
      [job(1, 'foto.jpeg', FileCategory.image)],
      const ConversionOptions(target: TargetFormat.jpg),
    );
    expect(engine.calls, 1);
  });

  test('moves the original to the recycle bin only after success', () async {
    final good = job(1, 'a.docx', FileCategory.document);
    final events = await run(
      build([FakeEngine('Word')]),
      [good],
      const ConversionOptions(target: TargetFormat.pdf, deleteOriginal: true),
    );
    expect(recycle.recycled, [good.path]);
    expect(
      events.whereType<JobStatusChanged>().last.text,
      'Concluído - original na Lixeira',
    );
  });

  test('keeps the original when the conversion fails', () async {
    final bad = job(1, 'a.docx', FileCategory.document);
    final events = await run(
      build([FakeEngine('Word', error: Exception('falhou'))]),
      [bad],
      const ConversionOptions(target: TargetFormat.pdf, deleteOriginal: true),
    );
    expect(recycle.recycled, isEmpty);
    expect(File(bad.path).existsSync(), isTrue);
    expect(events.whereType<BatchFinished>().single.failed, 1);
    expect(
      events.whereType<LogEmitted>().any((l) => l.isError),
      isTrue,
    );
  });

  test('merges images into a single PDF', () async {
    final events = await run(
      build([FakeEngine('Word')]),
      [
        job(1, 'a.png', FileCategory.image),
        job(2, 'b.jpg', FileCategory.image),
      ],
      const ConversionOptions(target: TargetFormat.pdf, mergeImages: true),
    );
    expect(pdfWriter.lastPaths, hasLength(2));
    final done = events
        .whereType<JobStatusChanged>()
        .where((e) => e.state == JobState.done);
    expect(done.map((e) => e.text).toSet(), {'Concluído (PDF único)'});
    expect(events.whereType<BatchFinished>().single.ok, 2);
  });

  test('cancel finishes the current file, deletes its pages and stops',
      () async {
    final token = CancellationToken();
    final paged = _PagedEngine(token);
    final second = FakeEngine('Word');
    final events = await run(
      build([paged, second]),
      [
        job(1, 'a.pdf', FileCategory.pdf),
        job(2, 'b.docx', FileCategory.document),
      ],
      const ConversionOptions(target: TargetFormat.png),
      cancel: token,
    );

    expect(paged.written, hasLength(2));
    for (final page in paged.written) {
      expect(File(page).existsSync(), isFalse, reason: 'página parcial');
    }
    expect(second.calls, 0);
    final finished = events.whereType<BatchFinished>().single;
    expect(finished.cancelled, isTrue);
    expect(finished.ok, 0);
    final statuses = events.whereType<JobStatusChanged>().toList();
    expect(statuses.last.jobId, 2);
    expect(statuses.last.text, 'Cancelado');
  });
}
