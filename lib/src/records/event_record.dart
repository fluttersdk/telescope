import 'package:flutter/foundation.dart' show FlutterTimeline;

/// An immutable app event record captured by an event watcher
/// (e.g. MagicEventWatcher shipped in the `magic` package).
class EventRecord {
  EventRecord({
    required this.eventType,
    required this.payload,
    required this.time,
    this.listenerCount,
    int? atUs,
    this.interactionId,
    this.linkedBy,
  }) : atUs = atUs ?? FlutterTimeline.now;

  final String eventType;
  final Map<String, dynamic> payload;
  final DateTime time;

  /// Number of listeners notified at dispatch time, when available.
  final int? listenerCount;

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
        'eventType': eventType,
        'payload': payload,
        'time': time.toIso8601String(),
        if (listenerCount != null) 'listenerCount': listenerCount,
        'atUs': atUs,
        if (interactionId != null) 'interactionId': interactionId,
        if (linkedBy != null) 'linkedBy': linkedBy,
      };
}
