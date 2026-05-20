import 'dart:convert';
import 'dart:developer' as developer;

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:meta/meta.dart';

import '../telescope_store.dart';

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
  registerExtensionIdempotent('ext.telescope.clear', clearHandler);
  registerExtensionIdempotent('ext.telescope.pause', pauseHandler);
  registerExtensionIdempotent('ext.telescope.resume', resumeHandler);
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
/// Returns recent [LogRecordEntry] entries from [TelescopeStore]. Accepts an
/// optional `limit` param (stringified integer) and an optional `level` param
/// (minimum log level name) to filter the result set.
@visibleForTesting
Future<developer.ServiceExtensionResponse> consoleHandler(
  String method,
  Map<String, String> params,
) async {
  final limit = int.tryParse(params['limit'] ?? '');
  final level = params['level'];
  final records = TelescopeStore.recentLogs(limit: limit, minLevel: level);
  return developer.ServiceExtensionResponse.result(
    jsonEncode({'messages': records.map((r) => r.toJson()).toList()}),
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
/// Returns recent [EventRecord] entries from [TelescopeStore]. Accepts an
/// optional `limit` param (stringified integer) to cap the result set.
@visibleForTesting
Future<developer.ServiceExtensionResponse> eventsHandler(
  String method,
  Map<String, String> params,
) async {
  final limit = int.tryParse(params['limit'] ?? '');
  final records = TelescopeStore.recentEvents(limit: limit);
  return developer.ServiceExtensionResponse.result(
    jsonEncode({'events': records.map((r) => r.toJson()).toList()}),
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
