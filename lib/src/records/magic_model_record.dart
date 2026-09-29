import 'package:flutter/foundation.dart' show FlutterTimeline;

/// An immutable Magic model lifecycle event captured by MagicModelWatcher
/// (shipped in `magic` package via TelescopePlugin.registerWatcher).
class MagicModelRecord {
  MagicModelRecord({
    required this.modelClass,
    required this.event,
    required this.modelKey,
    required this.time,
    this.attributes,
    int? atUs,
    this.interactionId,
    this.linkedBy,
  }) : atUs = atUs ?? FlutterTimeline.now;

  final String modelClass;

  /// 'created' | 'saved' | 'deleted'
  final String event;
  final String modelKey;
  final DateTime time;
  final Map<String, dynamic>? attributes;

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
        'modelClass': modelClass,
        'event': event,
        'modelKey': modelKey,
        'time': time.toIso8601String(),
        if (attributes != null) 'attributes': attributes,
        'atUs': atUs,
        if (interactionId != null) 'interactionId': interactionId,
        if (linkedBy != null) 'linkedBy': linkedBy,
      };
}
