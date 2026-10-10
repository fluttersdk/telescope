import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'records/event_record.dart';
import 'records/exception_record.dart';
import 'records/log_record_entry.dart';
import 'telescope_store.dart';

/// Persists the redacted log, event and exception records to rotating JSONL
/// files, so a timeline survives the in-memory ring buffers.
///
/// Each record becomes one line, `{"kind": "log"|"event"|"exception", ...}`
/// followed by the record's `toJson()`, in `timeline-<launch stamp>-<n>.jsonl`
/// inside the directory the host passes to [start]; the package looks no
/// directory up. Lines are batched and written at 64 lines or 500 ms,
/// whichever comes first, and a new file starts before a line would push the
/// current one past `maxFileBytes`. Once more than `maxFiles` timeline files
/// sit in the directory (earlier launches included), the oldest are deleted.
///
/// Fail closed: a record whose `redacted` flag is false (it was buffered
/// while no `TelescopeRedaction.redactor` was registered) is never written,
/// only counted in [droppedUnredacted].
///
/// A batch write no caller awaits (the 64 line or 500 ms flush) that fails
/// stops the sink rather than raise: the failure is counted in
/// [writeFailures] and the sink is no longer [current].
///
/// [files] and [read] expose the timeline files in the directory, earlier
/// launches included, and nothing else: a name is matched against that
/// listing before it is ever turned into a path, so a caller-supplied name
/// cannot reach any other file.
final class TelescopeFileSink {
  TelescopeFileSink._({
    required Directory directory,
    required int maxFileBytes,
    required int maxFiles,
    required String launchStamp,
  })  : _directory = directory,
        _maxFileBytes = maxFileBytes,
        _maxFiles = maxFiles,
        _launchStamp = launchStamp;

  static const int _batchLines = 64;
  static const Duration _flushInterval = Duration(milliseconds: 500);
  static final RegExp _timelineName = RegExp(
    r'^timeline-(\d{8}T\d{6}Z)-(\d+)\.jsonl$',
  );

  static TelescopeFileSink? _current;

  /// The running sink, set by [start] and cleared by [stop]; null when none
  /// runs.
  static TelescopeFileSink? get current => _current;

  final Directory _directory;
  final int _maxFileBytes;
  final int _maxFiles;
  final String _launchStamp;

  final List<StreamSubscription<Object>> _subscriptions =
      <StreamSubscription<Object>>[];
  final List<String> _pending = <String>[];

  /// The files this launch created and has not pruned, oldest first. The
  /// last one is open for writing.
  final List<_TimelineFile> _files = <_TimelineFile>[];

  RandomAccessFile? _open;
  Timer? _timer;
  bool _opened = false;
  bool _stopped = false;
  int _dropped = 0;
  int _writeFailures = 0;

  /// Every disk operation runs on this chain, one after the other, so a
  /// write, a rotation and a read never interleave.
  Future<void> _queue = Future<void>.value();

  /// Start writing the store's redacted log, event and exception records to
  /// [directory], creating it when absent, and make the sink [current].
  ///
  /// A sink already running is stopped first. [maxFileBytes] (bytes, at least
  /// 1) caps one file; a single line larger than that still gets a file of
  /// its own. [maxFiles] (at least 1) caps the timeline files kept in
  /// [directory]. Throws a [FileSystemException] when [directory] cannot be
  /// created or written; the sink then neither listens nor becomes
  /// [current].
  static Future<TelescopeFileSink> start({
    required String directory,
    int maxFileBytes = 1048576,
    int maxFiles = 8,
  }) async {
    assert(maxFileBytes > 0, 'maxFileBytes must be positive.');
    assert(maxFiles > 0, 'maxFiles must be positive.');

    // 1. One sink at a time: two would split the timeline across files.
    await _current?.stop();

    // 2. Subscribe before the first await on disk, so no record recorded
    // while the directory is being created is missed; those lines wait in
    // the batch until the first file is open.
    final TelescopeFileSink sink = TelescopeFileSink._(
      directory: Directory(directory),
      maxFileBytes: maxFileBytes,
      maxFiles: maxFiles,
      launchStamp: _stamp(DateTime.now().toUtc()),
    );
    sink._subscriptions.addAll(<StreamSubscription<Object>>[
      TelescopeStore.onLogRecord.listen(
        (LogRecordEntry r) => sink._accept('log', r.redacted, r.toJson),
      ),
      TelescopeStore.onEventRecord.listen(
        (EventRecord r) => sink._accept('event', r.redacted, r.toJson),
      ),
      TelescopeStore.onExceptionRecord.listen(
        (ExceptionRecord r) => sink._accept('exception', r.redacted, r.toJson),
      ),
    ]);

    // 3. The first file exists before the sink becomes current, so nothing
    // writes without one; a sink that cannot open it stops listening.
    try {
      await sink._serial(() async {
        await sink._directory.create(recursive: true);
        await sink._rotate();
      });
    } on Object {
      await sink._halt();
      rethrow;
    }

    // 4. Hand the lines batched during startup to the usual schedule.
    sink._opened = true;
    _current = sink;
    if (sink._pending.isNotEmpty) sink._scheduleFlush();

    return sink;
  }

  /// Records refused because their `redacted` flag was false.
  int get droppedUnredacted => _dropped;

  /// Batch writes no caller awaited that failed; the first one stops the
  /// sink.
  int get writeFailures => _writeFailures;

  /// Lines accepted and not yet handed to the disk queue.
  @visibleForTesting
  int get pendingLines => _pending.length;

  /// Hand every batched line to disk; completes once they are written.
  ///
  /// Throws a [FileSystemException] when the write fails.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty) return _serial(() async {});

    final List<String> batch = List<String>.of(_pending);
    _pending.clear();
    return _serial(() => _write(batch));
  }

  /// The timeline files in the directory, earlier launches included, newest
  /// first, each as `{name, bytes}` with `bytes` the file's length after a
  /// [flush].
  Future<List<Map<String, Object>>> files() async {
    await flush();

    return _serial(() async {
      final List<Map<String, Object>> listing = <Map<String, Object>>[];
      for (final _TimelineEntry entry in await _timeline()) {
        listing.add(<String, Object>{
          'name': entry.name,
          'bytes': await entry.file.length(),
        });
      }
      return listing;
    });
  }

  /// Read whole lines of the file called [name], from byte [offset], after a
  /// [flush].
  ///
  /// Returns `{lines, next}`: `lines` the complete lines found within
  /// [maxBytes] bytes of [offset] (without their newline), `next` the offset
  /// to pass to continue. A line longer than [maxBytes] is returned whole
  /// rather than cut. At the end of the file `lines` is empty and `next`
  /// equals [offset]. An [offset] that is not 0 or a previous `next` may
  /// start mid-line.
  ///
  /// An [offset] inside a multi-byte character decodes the cut bytes as
  /// U+FFFD rather than fail.
  ///
  /// Returns null, a refusal, when [name] is not exactly the name of a
  /// timeline file [files] lists (a path, a `..` segment, a link, or another
  /// file in the directory are all refused), when [offset] is negative, or
  /// when [maxBytes] is not positive.
  Future<Map<String, Object>?> read(
    String name, {
    int offset = 0,
    int maxBytes = 65536,
  }) async {
    if (offset < 0 || maxBytes < 1) return null;
    await flush();

    return _serial(() async {
      // The listing is the traversal guard: [name] is only compared, never
      // joined into a path, and the file read is the entry the directory
      // listing returned.
      final File? file = await _find(name);
      if (file == null) return null;

      final Uint8List bytes = await _readLines(file, offset, maxBytes);
      final List<String> lines = bytes.isEmpty
          ? <String>[]
          : (utf8.decode(bytes, allowMalformed: true).split('\n')
            ..removeLast());

      return <String, Object>{
        'lines': lines,
        'next': offset + bytes.length,
      };
    });
  }

  /// Stop listening, write what is batched and close the file; the sink is no
  /// longer [current]. Safe to call twice.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    if (identical(_current, this)) _current = null;

    for (final StreamSubscription<Object> subscription in _subscriptions) {
      await subscription.cancel();
    }
    await flush();
    await _serial(() async {
      await _open?.close();
      _open = null;
    });
  }

  void _accept(
    String kind,
    bool redacted,
    Map<String, dynamic> Function() toJson,
  ) {
    if (!redacted) {
      _dropped++;
      return;
    }

    _pending.add(
      jsonEncode(<String, dynamic>{
        'kind': kind,
        ...toJson(),
      }),
    );
    if (_opened) _scheduleFlush();
  }

  void _scheduleFlush() {
    if (_pending.length >= _batchLines) {
      unawaited(_flushInBackground());
      return;
    }
    _timer ??= Timer(_flushInterval, () => unawaited(_flushInBackground()));
  }

  /// A flush no caller awaits. Its failure must not escape into the zone:
  /// an exception watcher would record it, this sink would accept that
  /// record, and the next flush would fail the same way. It is counted and
  /// the sink stops instead.
  Future<void> _flushInBackground() async {
    try {
      await flush();
    } on Object {
      _writeFailures++;
      await _halt();
    }
  }

  /// Stop without writing: stop listening, drop the batch and close the
  /// file; the sink is no longer [current]. A no-op once stopped.
  Future<void> _halt() async {
    if (_stopped) return;
    _stopped = true;
    if (identical(_current, this)) _current = null;
    _timer?.cancel();
    _timer = null;
    _pending.clear();

    for (final StreamSubscription<Object> subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _serial(() async {
      final RandomAccessFile? open = _open;
      _open = null;
      try {
        await open?.close();
      } on FileSystemException {
        _writeFailures++;
      }
    });
  }

  /// Run [operation] after every operation queued before it. Its error goes
  /// to the returned future only, so one failed write does not block the
  /// ones after it.
  Future<T> _serial<T>(Future<T> Function() operation) {
    final Future<T> result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _write(List<String> batch) async {
    final BytesBuilder chunk = BytesBuilder(copy: false);

    for (final String line in batch) {
      final Uint8List encoded = utf8.encode('$line\n');
      final int written = _files.last.bytes + chunk.length;
      // A line goes to a fresh file when it would overflow a non-empty one;
      // an oversized line alone in a file is still written.
      if (written > 0 && written + encoded.length > _maxFileBytes) {
        await _append(chunk.takeBytes());
        await _rotate();
      }
      chunk.add(encoded);
    }

    await _append(chunk.takeBytes());
  }

  Future<void> _append(Uint8List bytes) async {
    if (bytes.isEmpty) return;
    final RandomAccessFile? open = _open;
    if (open == null) {
      // A rotation failed after closing the previous file.
      throw FileSystemException(
        'No timeline file is open.',
        _files.last.file.path,
      );
    }
    await open.writeFrom(bytes);
    _files.last.bytes += bytes.length;
  }

  /// Close the current file, open the next one and prune the oldest.
  Future<void> _rotate() async {
    final RandomAccessFile? previous = _open;
    _open = null;
    await previous?.close();

    // Counting on from the last file rather than from the list length keeps
    // the counter rising after a prune removed earlier files of this launch.
    final int counter = _files.isEmpty ? 1 : _files.last.counter + 1;
    final File file = File(
      '${_directory.path}${Platform.pathSeparator}'
      'timeline-$_launchStamp-$counter.jsonl',
    );
    _open = await file.open(mode: FileMode.write);
    _files.add(_TimelineFile(file: file, counter: counter));

    await _prune();
  }

  /// Delete the oldest timeline files in the directory beyond [_maxFiles].
  /// Only names the sink's own pattern produces are considered, and the file
  /// being written is never deleted.
  Future<void> _prune() async {
    final List<_TimelineEntry> timeline = await _timeline();
    if (timeline.length <= _maxFiles) return;

    final String writing = _files.last.name;
    for (final _TimelineEntry entry in timeline.skip(_maxFiles)) {
      if (entry.name == writing) continue;
      await entry.file.delete();
      _files.removeWhere((_TimelineFile file) => file.name == entry.name);
    }
  }

  /// The regular files in the directory whose names the sink's own pattern
  /// produces, newest first. Links are not followed, so a link named like a
  /// timeline file is not one.
  Future<List<_TimelineEntry>> _timeline() async {
    final List<_TimelineEntry> timeline = <_TimelineEntry>[];
    await for (final FileSystemEntity entity in _directory.list(
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final String name = entity.uri.pathSegments.last;
      final RegExpMatch? match = _timelineName.firstMatch(name);
      if (match == null) continue;
      timeline.add(
        _TimelineEntry(
          name: name,
          stamp: match.group(1)!,
          counter: int.parse(match.group(2)!),
          file: entity,
        ),
      );
    }

    return timeline
      ..sort((_TimelineEntry a, _TimelineEntry b) {
        final int byStamp = b.stamp.compareTo(a.stamp);
        return byStamp != 0 ? byStamp : b.counter.compareTo(a.counter);
      });
  }

  Future<File?> _find(String name) async {
    for (final _TimelineEntry entry in await _timeline()) {
      if (entry.name == name) return entry.file;
    }
    return null;
  }

  /// The bytes from [offset] through the last newline within [maxBytes], or
  /// through the first newline when the line at [offset] is longer.
  Future<Uint8List> _readLines(File file, int offset, int maxBytes) async {
    final RandomAccessFile reader = await file.open();
    try {
      final int available = await reader.length() - offset;
      if (available <= 0) return Uint8List(0);

      await reader.setPosition(offset);
      final Uint8List window = await reader.read(
        maxBytes < available ? maxBytes : available,
      );
      final int lastNewline = window.lastIndexOf(_newline);
      if (lastNewline >= 0) {
        return Uint8List.sublistView(window, 0, lastNewline + 1);
      }

      // Every written line ends in a newline, so the rest of this one is
      // within [available]; a file of an earlier launch cut off mid-line
      // ends the loop at its length.
      final BytesBuilder line = BytesBuilder(copy: false)..add(window);
      while (line.length < available) {
        final Uint8List more = await reader.read(maxBytes);
        final int newline = more.indexOf(_newline);
        if (newline >= 0) {
          line.add(Uint8List.sublistView(more, 0, newline + 1));
          break;
        }
        line.add(more);
      }
      return line.takeBytes();
    } finally {
      await reader.close();
    }
  }

  static const int _newline = 0x0A;

  /// `yyyyMMddTHHmmssZ`: sorts by time as text and holds no `:`, which some
  /// file systems refuse in a name.
  static String _stamp(DateTime utc) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
        '${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }
}

/// A file the sink created: its handle, rotation counter and the bytes
/// written to it so far.
final class _TimelineFile {
  _TimelineFile({
    required this.file,
    required this.counter,
  });

  final File file;
  final int counter;
  int bytes = 0;

  String get name => file.uri.pathSegments.last;
}

/// A timeline file found in the directory: its name, the launch stamp and
/// rotation counter parsed from it, and the entry the listing returned.
final class _TimelineEntry {
  const _TimelineEntry({
    required this.name,
    required this.stamp,
    required this.counter,
    required this.file,
  });

  final String name;
  final String stamp;
  final int counter;
  final File file;
}
