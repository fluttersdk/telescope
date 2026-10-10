import 'dart:convert';
import 'dart:developer' as developer;

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:meta/meta.dart';

import '../telescope_file_sink.dart';
import '../telescope_store.dart';
import '../watchers/frame_perf_watcher.dart';

/// Aggregator for ext.telescope.* VM Service extensions.
void registerAllTelescopeExtensions() {
  registerExtensionIdempotent('ext.telescope.requests', requestsHandler);
  registerExtensionIdempotent('ext.telescope.console', consoleHandler);
  registerExtensionIdempotent('ext.telescope.exceptions', exceptionsHandler);
  registerExtensionIdempotent('ext.telescope.events', eventsHandler);
  registerExtensionIdempotent('ext.telescope.gates', gatesHandler);
  registerExtensionIdempotent('ext.telescope.dumps', dumpsHandler);
  registerExtensionIdempotent('ext.telescope.queries', queriesHandler);
  registerExtensionIdempotent('ext.telescope.caches', cachesHandler);
  registerExtensionIdempotent('ext.telescope.frames', framesHandler);
  registerExtensionIdempotent('ext.telescope.clear', clearHandler);
  registerExtensionIdempotent('ext.telescope.pause', pauseHandler);
  registerExtensionIdempotent('ext.telescope.resume', resumeHandler);
  registerExtensionIdempotent('ext.telescope.files', filesHandler);
  registerExtensionIdempotent('ext.telescope.file', fileHandler);
}

/// Handler for ext.telescope.requests.
///
/// Returns recent [HttpRequestRecord] entries from [TelescopeStore]. Accepts an
/// optional `limit` param (stringified integer) to cap the result set.
@visibleForTesting
Future<developer.ServiceExtensionResponse> requestsHandler(
  String method,
  Map<String, String> params,
) async {
  final limit = int.tryParse(params['limit'] ?? '');
  final records = TelescopeStore.recentHttp(limit: limit);
  return developer.ServiceExtensionResponse.result(
    jsonEncode({'records': records.map((r) => r.toJson()).toList()}),
  );
}

/// Handler for ext.telescope.console.
///
/// Returns recent [LogRecordEntry] entries from [TelescopeStore], oldest
/// first, with a `cursor` for the next read. Accepts these optional params:
/// `limit` (stringified integer, applied after the filters), `level`
/// (minimum log level name), `logger` (exact logger name) and `since`
/// (stringified microseconds, exclusive, compared with `atUs`). A `since`
/// that is not an integer is refused.
///
/// With `since`, `limit` keeps the OLDEST N after it, extended to the end of
/// the run of records sharing the last one's `atUs`, so paging by `cursor`
/// skips nothing; without `since` it keeps the newest N.
///
/// `cursor` is the largest `atUs` returned, else the given `since`, else null:
/// passing it back as `since` yields only newer records.
@visibleForTesting
Future<developer.ServiceExtensionResponse> consoleHandler(
  String method,
  Map<String, String> params,
) async {
  final since = _since(params);
  if (since.refused) return _invalidSince();

  final logger = params['logger'];
  final records = TelescopeStore.recentLogs(minLevel: params['level'])
      .where(
        (r) =>
            (logger == null || r.loggerName == logger) &&
            (since.value == null || r.atUs > since.value!),
      )
      .toList();
  final page = _page(
    records,
    int.tryParse(params['limit'] ?? ''),
    atUs: (r) => r.atUs,
    oldest: since.value != null,
  );
  return developer.ServiceExtensionResponse.result(
    jsonEncode({
      'messages': page.map((r) => r.toJson()).toList(),
      'cursor': _cursor(page.map((r) => r.atUs), since.value),
    }),
  );
}

/// Handler for ext.telescope.exceptions.
///
/// Returns recent [ExceptionRecord] entries from [TelescopeStore]. Accepts an
/// optional `limit` param (stringified integer) to cap the result set.
@visibleForTesting
Future<developer.ServiceExtensionResponse> exceptionsHandler(
  String method,
  Map<String, String> params,
) async {
  final limit = int.tryParse(params['limit'] ?? '');
  final records = TelescopeStore.recentExceptions(limit: limit);
  return developer.ServiceExtensionResponse.result(
    jsonEncode({'exceptions': records.map((r) => r.toJson()).toList()}),
  );
}

/// Handler for ext.telescope.events.
///
/// Returns recent [EventRecord] entries from [TelescopeStore], oldest first,
/// with a `cursor` for the next read. Accepts these optional params: `limit`
/// (stringified integer, applied after the filters), `type` (prefix of
/// `eventType`) and `since` (stringified microseconds, exclusive, compared
/// with `atUs`). A `since` that is not an integer is refused.
///
/// With `since`, `limit` keeps the OLDEST N after it, extended to the end of
/// the run of records sharing the last one's `atUs`, so paging by `cursor`
/// skips nothing; without `since` it keeps the newest N.
///
/// `cursor` is the largest `atUs` returned, else the given `since`, else null:
/// passing it back as `since` yields only newer records.
@visibleForTesting
Future<developer.ServiceExtensionResponse> eventsHandler(
  String method,
  Map<String, String> params,
) async {
  final since = _since(params);
  if (since.refused) return _invalidSince();

  final type = params['type'];
  final records = TelescopeStore.recentEvents()
      .where(
        (r) =>
            (type == null || r.eventType.startsWith(type)) &&
            (since.value == null || r.atUs > since.value!),
      )
      .toList();
  final page = _page(
    records,
    int.tryParse(params['limit'] ?? ''),
    atUs: (r) => r.atUs,
    oldest: since.value != null,
  );
  return developer.ServiceExtensionResponse.result(
    jsonEncode({
      'events': page.map((r) => r.toJson()).toList(),
      'cursor': _cursor(page.map((r) => r.atUs), since.value),
    }),
  );
}

/// Handler for ext.telescope.gates.
///
/// Returns recent [GateRecord] entries from [TelescopeStore]. Accepts an
/// optional `limit` param (stringified integer) to cap the result set.
@visibleForTesting
Future<developer.ServiceExtensionResponse> queriesHandler(
  String method,
  Map<String, String> params,
) async {
  final limit = int.tryParse(params['limit'] ?? '');
  final records = TelescopeStore.recentQueries(limit: limit);
  return developer.ServiceExtensionResponse.result(
    jsonEncode({'queries': records.map((r) => r.toJson()).toList()}),
  );
}

/// Handler for ext.telescope.caches.
///
/// Returns recent [MagicCacheRecord] entries from [TelescopeStore]. Accepts
/// an optional `limit` param (stringified integer) to cap the result set.
@visibleForTesting
Future<developer.ServiceExtensionResponse> cachesHandler(
  String method,
  Map<String, String> params,
) async {
  final limit = int.tryParse(params['limit'] ?? '');
  final records = TelescopeStore.recentCaches(limit: limit);
  return developer.ServiceExtensionResponse.result(
    jsonEncode({'caches': records.map((r) => r.toJson()).toList()}),
  );
}

/// Handler for ext.telescope.gates.
///
/// Returns recent [GateRecord] entries from [TelescopeStore]. Accepts an
/// optional `limit` param (stringified integer) to cap the result set.
@visibleForTesting
Future<developer.ServiceExtensionResponse> gatesHandler(
  String method,
  Map<String, String> params,
) async {
  final limit = int.tryParse(params['limit'] ?? '');
  final records = TelescopeStore.recentGates(limit: limit);
  return developer.ServiceExtensionResponse.result(
    jsonEncode({'gates': records.map((r) => r.toJson()).toList()}),
  );
}

/// Handler for ext.telescope.dumps.
///
/// Returns recent [DumpRecord] entries from [TelescopeStore]. Accepts an
/// optional `limit` param (stringified integer) to cap the result set.
@visibleForTesting
Future<developer.ServiceExtensionResponse> dumpsHandler(
  String method,
  Map<String, String> params,
) async {
  final limit = int.tryParse(params['limit'] ?? '');
  final records = TelescopeStore.recentDumps(limit: limit);
  return developer.ServiceExtensionResponse.result(
    jsonEncode({'dumps': records.map((r) => r.toJson()).toList()}),
  );
}

/// Handler for ext.telescope.frames.
///
/// Returns recent [FramePerfRecord] entries from [TelescopeStore] alongside
/// [FramePerfWatcher.livenessCounter], so a caller can distinguish an empty
/// result caused by a quiet app from one caused by a stalled engine. Accepts
/// an optional `limit` param (stringified integer) to cap the result set.
@visibleForTesting
Future<developer.ServiceExtensionResponse> framesHandler(
  String method,
  Map<String, String> params,
) async {
  final limit = int.tryParse(params['limit'] ?? '');
  final records = TelescopeStore.recentFramePerf(limit: limit);
  return developer.ServiceExtensionResponse.result(
    jsonEncode({
      'frames': records.map((r) => r.toJson()).toList(),
      'livenessCounter': FramePerfWatcher.livenessCounter,
    }),
  );
}

/// Handler for ext.telescope.clear.
///
/// Clears all buffers in [TelescopeStore] and returns `{'cleared': true}`.
@visibleForTesting
Future<developer.ServiceExtensionResponse> clearHandler(
  String method,
  Map<String, String> params,
) async {
  TelescopeStore.clear();
  return developer.ServiceExtensionResponse.result(
    jsonEncode({'cleared': true}),
  );
}

/// Handler for ext.telescope.pause.
///
/// Pauses recording in [TelescopeStore] so subsequent record calls become
/// no-ops until [resumeHandler] is invoked.
@visibleForTesting
Future<developer.ServiceExtensionResponse> pauseHandler(
  String method,
  Map<String, String> params,
) async {
  TelescopeStore.pause();
  return developer.ServiceExtensionResponse.result(
    jsonEncode({'paused': true}),
  );
}

/// Handler for ext.telescope.resume.
///
/// Resumes recording in [TelescopeStore] after a prior [pauseHandler] call.
@visibleForTesting
Future<developer.ServiceExtensionResponse> resumeHandler(
  String method,
  Map<String, String> params,
) async {
  TelescopeStore.resume();
  return developer.ServiceExtensionResponse.result(
    jsonEncode({'resumed': true}),
  );
}

/// Handler for ext.telescope.files.
///
/// Lists the timeline files of the running [TelescopeFileSink] as
/// `{files: [{name, bytes}]}`, newest first. Answers `{error}` when no sink
/// runs.
@visibleForTesting
Future<developer.ServiceExtensionResponse> filesHandler(
  String method,
  Map<String, String> params,
) async {
  final sink = TelescopeFileSink.current;
  if (sink == null) return _fileError(_noSink);

  return developer.ServiceExtensionResponse.result(
    jsonEncode({'files': await sink.files()}),
  );
}

/// Handler for ext.telescope.file.
///
/// Reads whole lines of one timeline file through the running
/// [TelescopeFileSink], answering `{lines, next}`. Params: `name` (a file
/// from ext.telescope.files), `offset` (bytes, default 0) and `maxBytes`
/// (default 65536). Answers `{error}` when no sink runs and, with one fixed
/// message, whenever the sink refuses; `name` only ever reaches
/// [TelescopeFileSink.read], which compares it with the files it wrote.
@visibleForTesting
Future<developer.ServiceExtensionResponse> fileHandler(
  String method,
  Map<String, String> params,
) async {
  final sink = TelescopeFileSink.current;
  if (sink == null) return _fileError(_noSink);

  final offset = int.tryParse(params['offset'] ?? '0');
  final maxBytes = int.tryParse(params['maxBytes'] ?? '$_defaultMaxBytes');
  if (offset == null || maxBytes == null) return _fileError(_fileRefused);

  final page = await sink.read(
    params['name'] ?? '',
    offset: offset,
    maxBytes: maxBytes,
  );
  if (page == null) return _fileError(_fileRefused);

  return developer.ServiceExtensionResponse.result(jsonEncode(page));
}

const String _noSink = 'No timeline file sink is running.';
const String _fileRefused =
    'Unknown timeline file, or offset or maxBytes out of range.';
const int _defaultMaxBytes = 65536;

developer.ServiceExtensionResponse _fileError(String message) =>
    developer.ServiceExtensionResponse.result(jsonEncode({'error': message}));

/// The `since` param: [value] null when absent, [refused] when present but
/// not an integer. A typo must not read as "from the start".
({int? value, bool refused}) _since(Map<String, String> params) {
  final raw = params['since'];
  if (raw == null) return (value: null, refused: false);

  final value = int.tryParse(raw);
  return (value: value, refused: value == null);
}

developer.ServiceExtensionResponse _invalidSince() =>
    developer.ServiceExtensionResponse.error(
      developer.ServiceExtensionResponse.invalidParams,
      'since must be an integer number of microseconds.',
    );

/// [limit] of [records] (oldest first); all of them when [limit] is null.
///
/// Keeps the oldest when [oldest] is true, which is what a cursor read needs:
/// the cursor is the largest `atUs` returned, so a page that dropped its
/// oldest records would skip them for good. Keeps the newest otherwise.
///
/// A cursor read also finishes the run of records sharing the page's last
/// `atUs` ([atUs] reads it), so the page may exceed [limit] by those ties:
/// the next read filters strictly after the cursor and would otherwise never
/// see them.
List<T> _page<T>(
  List<T> records,
  int? limit, {
  required int Function(T record) atUs,
  required bool oldest,
}) {
  if (limit == null || records.length <= limit) return records;
  if (limit <= 0) return <T>[];
  if (!oldest) return records.sublist(records.length - limit);

  var end = limit;
  final last = atUs(records[end - 1]);
  while (end < records.length && atUs(records[end]) == last) {
    end++;
  }
  return records.sublist(0, end);
}

int? _cursor(Iterable<int> atUs, int? since) =>
    atUs.isEmpty ? since : atUs.reduce((a, b) => a > b ? a : b);
