import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/records/event_record.dart';
import 'package:fluttersdk_telescope/src/records/exception_record.dart';
import 'package:fluttersdk_telescope/src/records/log_record_entry.dart';
import 'package:fluttersdk_telescope/src/telescope_file_sink.dart';
import 'package:fluttersdk_telescope/src/telescope_redaction.dart';
import 'package:fluttersdk_telescope/src/telescope_store.dart';

final RegExp _timelineName = RegExp(r'^timeline-\d{8}T\d{6}Z-\d+\.jsonl$');

/// Lets the store's broadcast streams deliver to the sink's listeners.
Future<void> _delivered() => Future<void>.delayed(Duration.zero);

void _event(int i) => TelescopeStore.recordEvent(
      EventRecord(
        eventType: 'player.tick',
        payload: <String, dynamic>{
          'i': i,
        },
        time: DateTime.utc(2026),
      ),
    );

void _log(String message) => TelescopeStore.recordLog(
      LogRecordEntry(
        level: 'INFO',
        levelValue: 800,
        message: message,
        loggerName: 'mpv',
        time: DateTime.utc(2026),
      ),
    );

void _exception(String message) => TelescopeStore.recordException(
      ExceptionRecord(
        exceptionType: 'StateError',
        message: message,
        time: DateTime.utc(2026),
      ),
    );

String _identity(String text) => text;

void main() {
  late Directory root;
  late String directory;

  setUp(() {
    TelescopeStore.resetForTesting();
    root = Directory.systemTemp.createTempSync('telescope_file_sink_');
    directory = '${root.path}${Platform.pathSeparator}timeline';
  });

  tearDown(() async {
    await TelescopeFileSink.current?.stop();
    TelescopeStore.resetForTesting();
    root.deleteSync(recursive: true);
  });

  List<File> timelineFiles() => Directory(directory)
      .listSync()
      .whereType<File>()
      .where(
        (File file) => _timelineName.hasMatch(file.uri.pathSegments.last),
      )
      .toList();

  Future<List<String>> allLines(TelescopeFileSink sink) async {
    final List<String> lines = <String>[];
    for (final Map<String, Object> file in (await sink.files()).reversed) {
      final Map<String, Object>? page = await sink.read(
        file['name']! as String,
        maxBytes: 1 << 20,
      );
      lines.addAll(page!['lines']! as List<String>);
    }
    return lines;
  }

  group('TelescopeFileSink', () {
    group('start()', () {
      test('creates the directory and becomes current until stopped', () async {
        final TelescopeFileSink sink = await TelescopeFileSink.start(
          directory: directory,
        );

        expect(Directory(directory).existsSync(), isTrue);
        expect(TelescopeFileSink.current, same(sink));

        final List<Map<String, Object>> files = await sink.files();
        expect(files, hasLength(1));
        expect(_timelineName.hasMatch(files.single['name']! as String), isTrue);

        await sink.stop();
        expect(TelescopeFileSink.current, isNull);
      });

      test('stops the previous sink when started again', () async {
        TelescopeRedaction.redactor = _identity;
        final TelescopeFileSink first = await TelescopeFileSink.start(
          directory: directory,
        );
        final TelescopeFileSink second = await TelescopeFileSink.start(
          directory: '${root.path}${Platform.pathSeparator}second',
        );

        _event(1);
        await _delivered();

        expect(TelescopeFileSink.current, same(second));
        expect(first.pendingLines, 0);
        expect(second.pendingLines, 1);
      });
    });

    group('fail closed', () {
      test('writes no unredacted event and counts it', () async {
        final TelescopeFileSink sink = await TelescopeFileSink.start(
          directory: directory,
        );

        _event(1);
        await _delivered();
        await sink.flush();

        expect(sink.droppedUnredacted, 1);
        expect(await allLines(sink), isEmpty);
        expect(timelineFiles().single.lengthSync(), 0);
      });

      test('drops unredacted log and exception records too', () async {
        final TelescopeFileSink sink = await TelescopeFileSink.start(
          directory: directory,
        );

        _log('u:p@ss:w');
        _exception('u:p@ss:w');
        await _delivered();
        await sink.stop();

        expect(sink.droppedUnredacted, 2);
        expect(timelineFiles().single.readAsStringSync(), isEmpty);
      });
    });

    group('writing', () {
      test('writes one JSON line per redacted event', () async {
        TelescopeRedaction.redactor = _identity;
        final TelescopeFileSink sink = await TelescopeFileSink.start(
          directory: directory,
        );

        _event(1);
        _event(2);
        _event(3);
        await _delivered();

        final List<String> lines = await allLines(sink);
        expect(lines, hasLength(3));
        for (final String line in lines) {
          final Map<String, dynamic> decoded =
              jsonDecode(line) as Map<String, dynamic>;
          expect(decoded['kind'], 'event');
          expect(decoded['eventType'], 'player.tick');
          expect(decoded['redacted'], isTrue);
          expect(decoded['atUs'], isA<int>());
        }
        expect(sink.droppedUnredacted, 0);
      });

      test('tags log and exception lines with their kind', () async {
        TelescopeRedaction.redactor = _identity;
        final TelescopeFileSink sink = await TelescopeFileSink.start(
          directory: directory,
        );

        _log('opened');
        _exception('boom');
        await _delivered();

        final List<String> kinds = (await allLines(sink))
            .map(
              (String line) =>
                  (jsonDecode(line) as Map<String, dynamic>)['kind'] as String,
            )
            .toList();
        expect(
          kinds,
          unorderedEquals(<String>[
            'log',
            'exception',
          ]),
        );
      });

      test('hands the batch to disk at 64 lines without a flush', () async {
        TelescopeRedaction.redactor = _identity;
        final TelescopeFileSink sink = await TelescopeFileSink.start(
          directory: directory,
        );

        for (int i = 0; i < 63; i++) {
          _event(i);
        }
        await _delivered();
        expect(sink.pendingLines, 63);

        _event(63);
        await _delivered();
        expect(sink.pendingLines, 0);
      });

      test('flushes a partial batch after 500 ms', () async {
        TelescopeRedaction.redactor = _identity;
        await TelescopeFileSink.start(directory: directory);

        _event(1);
        await _delivered();
        expect(timelineFiles().single.lengthSync(), 0);

        await Future<void>.delayed(const Duration(milliseconds: 800));
        expect(timelineFiles().single.readAsLinesSync(), hasLength(1));
      });

      test('stop flushes buffered lines and ends the subscription', () async {
        TelescopeRedaction.redactor = _identity;
        final TelescopeFileSink sink = await TelescopeFileSink.start(
          directory: directory,
        );

        _event(1);
        await _delivered();
        await sink.stop();
        _event(2);
        await _delivered();

        expect(timelineFiles().single.readAsLinesSync(), hasLength(1));
        expect(sink.pendingLines, 0);
      });
    });

    group('rotation', () {
      test('rotates at maxFileBytes and keeps at most maxFiles', () async {
        TelescopeRedaction.redactor = _identity;
        final TelescopeFileSink sink = await TelescopeFileSink.start(
          directory: directory,
          maxFileBytes: 200,
          maxFiles: 3,
        );

        for (int i = 0; i < 20; i++) {
          _event(i);
        }
        await _delivered();

        final List<Map<String, Object>> files = await sink.files();
        expect(files.length, inInclusiveRange(2, 3));
        expect(timelineFiles().length, lessThanOrEqualTo(3));
        for (final Map<String, Object> file in files) {
          expect(file['bytes']! as int, lessThanOrEqualTo(200));
        }

        // Newest first: the rotation counter falls down the list.
        final List<int> counters = files
            .map(
              (Map<String, Object> file) => int.parse(
                RegExp(r'-(\d+)\.jsonl$')
                    .firstMatch(file['name']! as String)!
                    .group(1)!,
              ),
            )
            .toList();
        final List<int> descending = counters.toList()
          ..sort((int a, int b) => b.compareTo(a));
        expect(counters, orderedEquals(descending));

        // The newest file holds the newest record.
        final List<String> lines = await allLines(sink);
        final Map<String, dynamic> last =
            jsonDecode(lines.last) as Map<String, dynamic>;
        expect(last['payload'], <String, dynamic>{'i': 19});
      });

      test('prunes an older launch beyond maxFiles', () async {
        TelescopeRedaction.redactor = _identity;
        Directory(directory).createSync(recursive: true);
        final File older = File(
          '$directory${Platform.pathSeparator}'
          'timeline-20200101T000000Z-1.jsonl',
        )..writeAsStringSync('{"kind":"event"}\n');

        final TelescopeFileSink sink = await TelescopeFileSink.start(
          directory: directory,
          maxFileBytes: 200,
          maxFiles: 2,
        );
        _event(1);
        _event(2);
        await _delivered();
        await sink.flush();

        expect(older.existsSync(), isFalse);
        expect(timelineFiles(), hasLength(2));
      });
    });

    group('.files()', () {
      test('reports the bytes written to each file', () async {
        TelescopeRedaction.redactor = _identity;
        final TelescopeFileSink sink = await TelescopeFileSink.start(
          directory: directory,
        );

        _event(1);
        await _delivered();

        final List<Map<String, Object>> files = await sink.files();
        expect(files.single['bytes'], timelineFiles().single.lengthSync());
        expect(files.single['bytes']! as int, greaterThan(0));
      });
    });

    group('.read()', () {
      late TelescopeFileSink sink;
      late String name;

      setUp(() async {
        TelescopeRedaction.redactor = _identity;
        sink = await TelescopeFileSink.start(directory: directory);
        _event(1);
        _event(2);
        _event(3);
        await _delivered();
        name = (await sink.files()).single['name']! as String;
      });

      test('refuses a traversal or absolute name', () async {
        File('${root.path}${Platform.pathSeparator}secret')
            .writeAsStringSync('u:p@ss:w\n');

        expect(await sink.read('../secret'), isNull);
        expect(await sink.read('/etc/hosts'), isNull);
        expect(await sink.read('../timeline/$name'), isNull);
        expect(await sink.read('./$name'), isNull);
        expect(
          await sink.read('$directory${Platform.pathSeparator}$name'),
          isNull,
        );
      });

      test('refuses a file in the directory the sink did not write', () async {
        File('$directory${Platform.pathSeparator}notes.txt')
            .writeAsStringSync('u:p@ss:w\n');
        File(
          '$directory${Platform.pathSeparator}'
          'timeline-20200101T000000Z-1.jsonl',
        ).writeAsStringSync('{"kind":"event"}\n');

        expect(await sink.read('notes.txt'), isNull);
        expect(await sink.read('timeline-20200101T000000Z-1.jsonl'), isNull);
      });

      test('refuses a negative offset or a non-positive maxBytes', () async {
        expect(await sink.read(name, offset: -1), isNull);
        expect(await sink.read(name, maxBytes: 0), isNull);
      });

      test('continues from next where the previous read stopped', () async {
        final List<String> all = timelineFiles().single.readAsLinesSync();
        final int firstBytes = utf8.encode('${all.first}\n').length;

        final Map<String, Object> first =
            (await sink.read(name, maxBytes: firstBytes + 5))!;
        expect(first['lines'], <String>[all.first]);
        expect(first['next'], firstBytes);

        final Map<String, Object> rest =
            (await sink.read(name, offset: first['next']! as int))!;
        expect(rest['lines'], all.sublist(1));

        final int end = rest['next']! as int;
        expect(end, timelineFiles().single.lengthSync());

        final Map<String, Object> tail = (await sink.read(name, offset: end))!;
        expect(tail['lines'], isEmpty);
        expect(tail['next'], end);
      });

      test('returns a line longer than maxBytes whole', () async {
        final List<String> all = timelineFiles().single.readAsLinesSync();

        final Map<String, Object> page = (await sink.read(name, maxBytes: 4))!;

        expect(page['lines'], <String>[all.first]);
        expect(page['next'], utf8.encode('${all.first}\n').length);
      });

      test('sees lines still waiting in the batch', () async {
        _event(4);
        await _delivered();

        final Map<String, Object> page = (await sink.read(name))!;

        expect(page['lines'], hasLength(4));
      });
    });
  });
}
