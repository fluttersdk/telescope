import 'dart:convert';

import 'package:meta/meta.dart';

import 'internal/redaction_lists.dart' as lists;
import 'records/event_record.dart';
import 'records/exception_record.dart';
import 'records/http_request_record.dart';
import 'records/log_record_entry.dart';

/// Masks credentials in HTTP records before [TelescopeStore.recordHttp]
/// buffers them.
///
/// The HTTP ring buffer is served verbatim to AI agents over
/// `ext.telescope.requests` and MCP, so a bearer header or a login body
/// stored as captured leaks the credential into an agent transcript. The
/// model mirrors Laravel Telescope: three name lists (request headers,
/// request parameters, response parameters), matched case-insensitively,
/// extended through the `hide*` methods (additions merge with the defaults,
/// they never replace them), and every matching value replaced with [mask].
///
/// The store only understands JSON and form-encoded bodies. An adapter that holds a body as
/// structured data (a Dart `Map` whose `toString()` is not JSON) must run it
/// through [redactParameters] before stringifying it.
final class TelescopeRedaction {
  TelescopeRedaction._();

  /// The value a hidden entry is replaced with; Laravel Telescope's mask.
  static const String mask = '********';

  /// The host's text redactor, or null while none is registered.
  ///
  /// When set, the store runs it over every text the log, event, exception
  /// and HTTP records carry (message, error, stack, URL, header values,
  /// bodies and every String inside an event payload's nested Maps and
  /// Lists) before the record enters its queue or its stream, and marks the
  /// record `redacted`. It receives one String and returns the masked one;
  /// it must be pure and total, since a throw drops the record rather than
  /// let it through unmasked. A record buffered while this is null stays
  /// unredacted, and a consumer that persists records writes only the
  /// redacted ones.
  static String Function(String)? redactor;

  /// Lowercased request header names whose values are masked.
  static Set<String> get hiddenRequestHeaders =>
      Set<String>.unmodifiable(lists.hiddenRequestHeaders);

  /// Lowercased request body keys whose values are masked.
  static Set<String> get hiddenRequestParameters =>
      Set<String>.unmodifiable(lists.hiddenRequestParameters);

  /// Lowercased response body keys whose values are masked.
  static Set<String> get hiddenResponseParameters =>
      Set<String>.unmodifiable(lists.hiddenResponseParameters);

  /// Hide the given request headers in addition to the defaults.
  static void hideRequestHeaders(Iterable<String> names) =>
      lists.hiddenRequestHeaders.addAll(names.map(_normalize));

  /// Hide the given request body keys in addition to the defaults.
  static void hideRequestParameters(Iterable<String> names) =>
      lists.hiddenRequestParameters.addAll(names.map(_normalize));

  /// Hide the given response body keys in addition to the defaults.
  static void hideResponseParameters(Iterable<String> names) =>
      lists.hiddenResponseParameters.addAll(names.map(_normalize));

  /// Return a copy of [data] with the value under every key in [keys]
  /// replaced by [mask], at any depth of nested Maps and Lists.
  ///
  /// Keys match case-insensitively. A matching key masks its whole value,
  /// structured or not. An empty value (null, false, an empty string or
  /// collection) stays visible: it is not a secret, and seeing it explains a
  /// validation failure. A subtree nested past 64 levels is masked whole.
  /// [data] is never mutated; a scalar comes back as is.
  static Object? redactParameters(Object? data, Set<String> keys) =>
      _redact(data, keys.map(_normalize).toSet());

  /// Return [record] with its hidden request headers masked and the hidden
  /// keys of a JSON or form-encoded request or response body masked, then,
  /// when a [redactor] is registered, every text field run through it.
  ///
  /// Any other body is kept as is, and so is a body with nothing to hide
  /// (byte for byte, so its formatting survives). Returns [record] itself
  /// when nothing was masked and no [redactor] is registered. Never throws on
  /// a malformed body.
  static HttpRequestRecord redactHttpRecord(HttpRequestRecord record) {
    final HttpRequestRecord keyed = _redactHttpKeys(record);
    final String Function(String)? redact = redactor;
    if (redact == null) return keyed;

    return HttpRequestRecord(
      url: redact(keyed.url),
      method: redact(keyed.method),
      statusCode: keyed.statusCode,
      durationMs: keyed.durationMs,
      isError: keyed.isError,
      timestamp: keyed.timestamp,
      requestHeaders: keyed.requestHeaders?.map(
        (String name, String value) =>
            MapEntry<String, String>(name, redact(value)),
      ),
      requestBody: _text(keyed.requestBody, redact),
      responseBody: _text(keyed.responseBody, redact),
      attributedHeuristically: keyed.attributedHeuristically,
      requestId: _text(keyed.requestId, redact),
      startUs: keyed.startUs,
      endUs: keyed.endUs,
      atUs: keyed.atUs,
      interactionId: _text(keyed.interactionId, redact),
      linkedBy: _text(keyed.linkedBy, redact),
      redacted: true,
    );
  }

  /// Return [record] with every text field run through the [redactor] and
  /// `redacted` set, or [record] itself when none is registered.
  static LogRecordEntry redactLogRecord(LogRecordEntry record) {
    final String Function(String)? redact = redactor;
    if (redact == null) return record;

    return LogRecordEntry(
      level: redact(record.level),
      levelValue: record.levelValue,
      message: redact(record.message),
      loggerName: redact(record.loggerName),
      time: record.time,
      error: _text(record.error, redact),
      stackTrace: _text(record.stackTrace, redact),
      atUs: record.atUs,
      redacted: true,
    );
  }

  /// Return [record] with every text field run through the [redactor] and
  /// `redacted` set, or [record] itself when none is registered.
  static ExceptionRecord redactExceptionRecord(ExceptionRecord record) {
    final String Function(String)? redact = redactor;
    if (redact == null) return record;

    return ExceptionRecord(
      exceptionType: redact(record.exceptionType),
      message: redact(record.message),
      time: record.time,
      stackTrace: _text(record.stackTrace, redact),
      isolate: _text(record.isolate, redact),
      redacted: true,
    );
  }

  /// Return [record] with a JSON-safe payload, and with every text field run
  /// through the [redactor] and `redacted` set when one is registered.
  ///
  /// The payload is walked at any depth of Maps and Lists. A value `jsonEncode`
  /// cannot write (a `DateTime`, a `Duration`, any object) is stored as its
  /// `toString()` and a non-String map key as its `toString()`, so one bad
  /// payload cannot fail a whole events response. A subtree nested past 64
  /// levels is masked whole. Returns [record] itself when there is nothing to
  /// change.
  static EventRecord redactEventRecord(EventRecord record) {
    final String Function(String)? redact = redactor;
    final Map<String, dynamic> payload =
        _scrub(record.payload, redact) as Map<String, dynamic>;
    if (redact == null && identical(payload, record.payload)) return record;

    return EventRecord(
      eventType: _text(record.eventType, redact)!,
      payload: payload,
      time: record.time,
      listenerCount: record.listenerCount,
      atUs: record.atUs,
      interactionId: _text(record.interactionId, redact),
      linkedBy: _text(record.linkedBy, redact),
      redacted: redact != null || record.redacted,
    );
  }

  static String? _text(String? text, String Function(String)? redact) =>
      text == null || redact == null ? text : redact(text);

  /// A String is run through [redactor] when one is given; a scalar stays;
  /// a Map or List is rebuilt only when something inside it changed, so an
  /// already-safe payload keeps its identity; anything else becomes its
  /// `toString()`.
  static Object? _scrub(
    Object? value,
    String Function(String)? redact, [
    int depth = 0,
  ]) {
    if (value == null || value is bool || value is num) return value;
    if (depth >= _maxDepth) return mask;
    if (value is String) return _text(value, redact);

    if (value is Map) {
      bool changed = value is! Map<String, dynamic>;
      final Map<String, dynamic> scrubbed = <String, dynamic>{};
      for (final MapEntry<Object?, Object?> entry in value.entries) {
        final Object? item = _scrub(entry.value, redact, depth + 1);
        changed = changed || !identical(item, entry.value);
        scrubbed['${entry.key}'] = item;
      }
      return changed ? scrubbed : value;
    }

    if (value is List) {
      bool changed = false;
      final List<Object?> scrubbed = <Object?>[];
      for (final Object? element in value) {
        final Object? item = _scrub(element, redact, depth + 1);
        changed = changed || !identical(item, element);
        scrubbed.add(item);
      }
      return changed ? scrubbed : value;
    }

    return _text(value.toString(), redact);
  }

  static HttpRequestRecord _redactHttpKeys(HttpRequestRecord record) {
    final Map<String, String>? headers = _redactHeaders(record.requestHeaders);
    final String? requestBody = redactBody(
      record.requestBody,
      lists.hiddenRequestParameters,
    );
    final String? responseBody = redactBody(
      record.responseBody,
      lists.hiddenResponseParameters,
    );

    if (identical(headers, record.requestHeaders) &&
        identical(requestBody, record.requestBody) &&
        identical(responseBody, record.responseBody)) {
      return record;
    }

    return record.copyWith(
      requestHeaders: headers,
      requestBody: requestBody,
      responseBody: responseBody,
    );
  }

  /// Restore the three lists to their defaults and unregister the [redactor].
  @visibleForTesting
  static void resetForTesting() {
    lists.resetRedactionLists();
    redactor = null;
  }

  static String _normalize(String name) => name.toLowerCase();

  // Real API payloads nest a handful of levels. The walk recurses and so
  // does `jsonEncode`, and a pathological body thousands of levels deep
  // would overflow the stack inside `recordHttp`; past this depth a subtree
  // is masked whole instead, which is also what keeps a credential down
  // there out of the buffer.
  static const int _maxDepth = 64;

  /// [keys] must already be normalized. An empty value (null, false, an
  /// empty string or collection) is not a secret and stays visible, the
  /// truthiness rule Laravel's `hideParameters` applies.
  static bool _hides(Object? key, Object? value, Set<String> keys) =>
      key is String && keys.contains(_normalize(key)) && !_isEmpty(value);

  static bool _isEmpty(Object? value) =>
      value == null ||
      value == false ||
      value == '' ||
      (value is Map && value.isEmpty) ||
      (value is List && value.isEmpty);

  static Object? _redact(Object? data, Set<String> keys, [int depth = 0]) {
    if (data is! Map && data is! List) return data;
    if (depth >= _maxDepth) return mask;

    if (data is Map) {
      return data.map(
        (Object? key, Object? value) => MapEntry<Object?, Object?>(
          key,
          _hides(key, value, keys) ? mask : _redact(value, keys, depth + 1),
        ),
      );
    }

    return (data as List)
        .map((Object? item) => _redact(item, keys, depth + 1))
        .toList();
  }

  static bool _mentions(Object? data, Set<String> keys, [int depth = 0]) {
    if (data is! Map && data is! List) return false;
    if (depth >= _maxDepth) return true;

    if (data is Map) {
      return data.entries.any(
        (MapEntry<Object?, Object?> entry) =>
            _hides(entry.key, entry.value, keys) ||
            _mentions(entry.value, keys, depth + 1),
      );
    }

    return (data as List).any(
      (Object? item) => _mentions(item, keys, depth + 1),
    );
  }

  /// A whole `application/x-www-form-urlencoded` body: pairs joined by `&`,
  /// no whitespace, and every percent escape well formed, so decoding a key
  /// cannot throw.
  static final RegExp _formBody = RegExp(
    r'^(?:[^\s=&%]|%[0-9A-Fa-f]{2})+=(?:[^\s&%]|%[0-9A-Fa-f]{2})*'
    r'(?:&(?:[^\s=&%]|%[0-9A-Fa-f]{2})+=(?:[^\s&%]|%[0-9A-Fa-f]{2})*)*$',
  );

  static String _redactForm(String body, Set<String> hidden) {
    if (!_formBody.hasMatch(body)) return body;

    bool masked = false;
    final String redacted = body.split('&').map((String pair) {
      final int equals = pair.indexOf('=');
      // Latin-1 maps every byte, so a key that is not UTF-8 still decodes;
      // the default names are ASCII either way.
      final String key = _formLeaf(
        Uri.decodeQueryComponent(pair.substring(0, equals), encoding: latin1),
      );
      if (!_hides(key, pair.substring(equals + 1), hidden)) return pair;
      masked = true;
      return '${pair.substring(0, equals + 1)}$mask';
    }).join('&');

    return masked ? redacted : body;
  }

  /// The name a form key addresses, the leaf a nested JSON key would be:
  /// `user[password]` is `password`, and a list key `codes[]` is `codes`.
  static String _formLeaf(String key) {
    String name = key;
    while (name.endsWith('[]')) {
      name = name.substring(0, name.length - 2);
    }
    final int open = name.lastIndexOf('[');
    if (!name.endsWith(']') || open < 0) return name;
    return name.substring(open + 1, name.length - 1);
  }

  static Map<String, String>? _redactHeaders(Map<String, String>? headers) {
    if (headers == null ||
        !headers.entries.any(
          (MapEntry<String, String> header) =>
              _hides(header.key, header.value, lists.hiddenRequestHeaders),
        )) {
      return headers;
    }

    return headers.map(
      (String name, String value) => MapEntry<String, String>(
        name,
        _hides(name, value, lists.hiddenRequestHeaders) ? mask : value,
      ),
    );
  }

  /// Return [body] with the value under every key in [keys] masked, when
  /// it parses as a JSON object or array, or reads as a form-encoded body
  /// (`key=value&key=value`, an OAuth token call or a form login).
  ///
  /// Anything else (plain text, a truncated JSON snippet) and a body with
  /// nothing to hide come back as given, byte for byte, so the formatting
  /// survives; in a form body only the value of a matching pair changes.
  /// Never throws on a malformed body. Use it for a body an adapter holds as
  /// a string, before truncating it: a cut JSON body no longer parses, so
  /// the store could not mask it afterwards.
  static String? redactBody(String? body, Set<String> keys) {
    if (body == null || body.isEmpty) return body;
    final Set<String> hidden = keys.map(_normalize).toSet();

    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      // Not JSON: a form body is masked pair by pair, and anything else
      // (plain text, a truncated payload) has no keys to find.
      return _redactForm(body, hidden);
    }

    if (!_mentions(decoded, hidden)) return body;

    return jsonEncode(_redact(decoded, hidden));
  }
}
