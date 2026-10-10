import 'package:flutter/foundation.dart' show FlutterTimeline;

import '../telescope_redaction.dart';

/// An immutable HTTP request/response record captured by a [TelescopeHttpAdapter].
class HttpRequestRecord {
  HttpRequestRecord({
    required this.url,
    required this.method,
    required this.statusCode,
    required this.durationMs,
    required this.isError,
    required this.timestamp,
    this.requestHeaders,
    this.requestBody,
    this.responseBody,
    this.attributedHeuristically = false,
    this.requestId,
    this.startUs,
    this.endUs,
    int? atUs,
    this.interactionId,
    this.linkedBy,
  }) : atUs = atUs ?? FlutterTimeline.now;

  final String url;
  final String method;
  final int statusCode;
  final int durationMs;
  final bool isError;
  final DateTime timestamp;
  final Map<String, String>? requestHeaders;
  final String? requestBody;
  final String? responseBody;

  /// True when the adapter could not exactly match this response to its request
  /// (concurrent requests in flight). The attribution is best-effort FIFO.
  final bool attributedHeuristically;

  /// The adapter-assigned identifier that pairs this response with the
  /// request that produced it, when the capturing adapter tracks one
  /// (replacing best-effort FIFO attribution with an exact match).
  final String? requestId;

  /// Monotonic microsecond timestamp (from [FlutterTimeline.now]'s clock)
  /// when the request was sent, when the capturing adapter tracks one.
  final int? startUs;

  /// Monotonic microsecond timestamp (from [FlutterTimeline.now]'s clock)
  /// when the response arrived, when the capturing adapter tracks one.
  final int? endUs;

  /// Monotonic microsecond timestamp from `FlutterTimeline.now`, captured at
  /// construction unless the caller supplies one explicitly. Comparable
  /// across every telescope record type regardless of wall-clock skew;
  /// [timestamp] stays the wall-clock field for display.
  final int atUs;

  /// Correlates this record to others captured during the same logical
  /// interaction (a tap, a navigation), when the capturing site knows one.
  final String? interactionId;

  /// How [interactionId] was derived: `zone` | `frame` | `window`.
  /// `window` means no interaction was open at capture: [interactionId] is
  /// null and analysis joins the record by [atUs]. Null when the capturing
  /// site does not link at all.
  final String? linkedBy;

  /// True when [TelescopeRedaction.redactor] ran over this record before it
  /// was buffered: only the store's redaction pass sets it, so a record a
  /// caller constructs is always false. A record made while no redactor was
  /// registered is false too, and a consumer that persists records (a file
  /// sink) writes only the true ones.
  bool get redacted => TelescopeRedaction.isRedacted(this);

  /// Copy with the capture payload replaced; every other field, [atUs]
  /// included, carries over so the copy keeps its place on the trace. The
  /// copy is not [redacted]: the replaced payload is caller input no
  /// redactor has seen.
  HttpRequestRecord copyWith({
    Map<String, String>? requestHeaders,
    String? requestBody,
    String? responseBody,
  }) =>
      HttpRequestRecord(
        url: url,
        method: method,
        statusCode: statusCode,
        durationMs: durationMs,
        isError: isError,
        timestamp: timestamp,
        requestHeaders: requestHeaders ?? this.requestHeaders,
        requestBody: requestBody ?? this.requestBody,
        responseBody: responseBody ?? this.responseBody,
        attributedHeuristically: attributedHeuristically,
        requestId: requestId,
        startUs: startUs,
        endUs: endUs,
        atUs: atUs,
        interactionId: interactionId,
        linkedBy: linkedBy,
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'method': method,
        'statusCode': statusCode,
        'durationMs': durationMs,
        'isError': isError,
        'timestamp': timestamp.toIso8601String(),
        if (requestHeaders != null) 'requestHeaders': requestHeaders,
        if (requestBody != null) 'requestBody': requestBody,
        if (responseBody != null) 'responseBody': responseBody,
        if (attributedHeuristically) 'attributedHeuristically': true,
        if (requestId != null) 'requestId': requestId,
        if (startUs != null) 'startUs': startUs,
        if (endUs != null) 'endUs': endUs,
        'atUs': atUs,
        if (interactionId != null) 'interactionId': interactionId,
        if (linkedBy != null) 'linkedBy': linkedBy,
        'redacted': redacted,
      };
}
