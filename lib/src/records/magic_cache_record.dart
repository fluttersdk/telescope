import 'package:flutter/foundation.dart' show FlutterTimeline;

/// An immutable Magic cache operation record captured by MagicCacheWatcher
/// (shipped in `magic` package).
class MagicCacheRecord {
  MagicCacheRecord({
    required this.operation,
    required this.key,
    required this.time,
    this.ttl,
    int? atUs,
    this.interactionId,
    this.linkedBy,
  }) : atUs = atUs ?? FlutterTimeline.now;

  /// 'put' | 'get' | 'forget' | 'hit' | 'miss'
  final String operation;
  final String key;
  final DateTime time;
  final Duration? ttl;

  /// Monotonic microsecond timestamp from `FlutterTimeline.now`, captured at
  /// construction unless the caller supplies one explicitly. Comparable
  /// across every telescope record type regardless of wall-clock skew;
  /// [time] stays the wall-clock field for display.
  final int atUs;

  /// Correlates this record to others captured during the same logical
  /// interaction (a tap, a navigation), when the capturing site knows one.
  final String? interactionId;

  /// How [interactionId] was derived: `zone` | `frame` | `window`.
  /// `window` means no interaction was open at capture: [interactionId] is
  /// null and analysis joins the record by [atUs]. Null when the capturing
  /// site does not link at all.
  final String? linkedBy;

  Map<String, dynamic> toJson() => {
        'operation': operation,
        'key': key,
        'time': time.toIso8601String(),
        if (ttl != null) 'ttlMs': ttl!.inMilliseconds,
        'atUs': atUs,
        if (interactionId != null) 'interactionId': interactionId,
        if (linkedBy != null) 'linkedBy': linkedBy,
      };
}
