import 'dart:convert';
import 'dart:developer' as developer;

import 'package:fluttersdk_artisan/artisan.dart';

import '../telescope_store.dart';

/// Aggregator for ext.telescope.* VM Service extensions.
void registerAllTelescopeExtensions() {
  registerExtensionIdempotent('ext.telescope.requests', _requestsHandler);
  registerExtensionIdempotent('ext.telescope.console', _consoleHandler);
  registerExtensionIdempotent('ext.telescope.exceptions', _exceptionsHandler);
  registerExtensionIdempotent('ext.telescope.clear', _clearHandler);
  registerExtensionIdempotent('ext.telescope.pause', _pauseHandler);
  registerExtensionIdempotent('ext.telescope.resume', _resumeHandler);
}

Future<developer.ServiceExtensionResponse> _requestsHandler(
  String method,
  Map<String, String> params,
) async {
  final limit = int.tryParse(params['limit'] ?? '');
  final records = TelescopeStore.recentHttp(limit: limit);
  return developer.ServiceExtensionResponse.result(
    jsonEncode({'records': records.map((r) => r.toJson()).toList()}),
  );
}

Future<developer.ServiceExtensionResponse> _consoleHandler(
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

Future<developer.ServiceExtensionResponse> _exceptionsHandler(
  String method,
  Map<String, String> params,
) async {
  final limit = int.tryParse(params['limit'] ?? '');
  final records = TelescopeStore.recentExceptions(limit: limit);
  return developer.ServiceExtensionResponse.result(
    jsonEncode({'exceptions': records.map((r) => r.toJson()).toList()}),
  );
}

Future<developer.ServiceExtensionResponse> _clearHandler(
  String method,
  Map<String, String> params,
) async {
  TelescopeStore.clear();
  return developer.ServiceExtensionResponse.result(
    jsonEncode({'cleared': true}),
  );
}

Future<developer.ServiceExtensionResponse> _pauseHandler(
  String method,
  Map<String, String> params,
) async {
  TelescopeStore.pause();
  return developer.ServiceExtensionResponse.result(
    jsonEncode({'paused': true}),
  );
}

Future<developer.ServiceExtensionResponse> _resumeHandler(
  String method,
  Map<String, String> params,
) async {
  TelescopeStore.resume();
  return developer.ServiceExtensionResponse.result(
    jsonEncode({'resumed': true}),
  );
}
