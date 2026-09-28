import 'package:flutter/foundation.dart' show FlutterTimeline;

/// An immutable database query record captured by MagicQueryWatcher
/// (shipped in `magic` package via TelescopePlugin.registerWatcher).
class QueryRecord {
  QueryRecord({
    required this.sql,
    required this.bindings,
    required this.timeMs,
    required this.time,
    this.connectionName = 'default',
    int? atUs,
    this.interactionId,
    this.linkedBy,
  }) : atUs = atUs ?? FlutterTimeline.now;

  /// The SQL string the QueryBuilder dispatched to the underlying driver.
  final String sql;

  /// Positional or named query bindings. Held as `List<Object?>` so the
  /// JSON envelope stays predictable; magic dispatches `List<dynamic>`,
  /// which is structurally identical.
  final List<Object?> bindings;

  /// Execution time in milliseconds reported by magic's QueryBuilder.
  final int timeMs;

  /// Connection name (`default` when the consumer did not name it).
  final String connectionName;
  final DateTime time;

  /// Monotonic microsecond timestamp from `FlutterTimeline.now`, captured at
  /// construction unless the caller supplies one explicitly. Comparable
  /// across every telescope record type regardless of wall-clock skew;
  /// [time] stays the wall-clock field for display.
  final int atUs;

  /// Correlates this record to others captured during the same logical
  /// interaction (a tap, a navigation), when the capturing site knows one.
  final String? interactionId;

  /// How [interactionId] was derived: `zone` | `frame` | `window`. Null when
  /// [interactionId] is null.
  final String? linkedBy;

  Map<String, dynamic> toJson() => {
        'sql': sql,
        'bindings': bindings,
        'timeMs': timeMs,
        'connectionName': connectionName,
        'time': time.toIso8601String(),
        'atUs': atUs,
        if (interactionId != null) 'interactionId': interactionId,
        if (linkedBy != null) 'linkedBy': linkedBy,
      };
}
