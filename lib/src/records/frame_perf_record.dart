import 'package:flutter/foundation.dart' show FlutterTimeline;

/// An immutable per-frame performance record captured by `FramePerfWatcher`.
///
/// Carries the fields `FrameTiming` actually exposes (`buildMicros`,
/// `rasterMicros`, `vsyncOverheadMicros`, `totalSpanMicros`, `vsyncStartUs`)
/// plus the per-frame attribution join, `blocks`: a map from block name (a
/// widget build span, a layout span, ...) to how much time it consumed
/// inclusive of its nested children (`micros`), exclusive of them
/// (`selfMicros`), and how many times it ran during that frame (`count`).
///
/// `blocks` serializes to a plain JSON object of nested objects:
/// ```json
/// {"Widget.build": {"micros": 600, "selfMicros": 400, "count": 5}}
/// ```
class FramePerfRecord {
  FramePerfRecord({
    required this.frameNumber,
    required this.buildMicros,
    required this.rasterMicros,
    required this.vsyncOverheadMicros,
    required this.totalSpanMicros,
    required this.time,
    required this.blocks,
    this.vsyncStartUs,
    int? atUs,
    this.interactionId,
    this.linkedBy,
  }) : atUs = atUs ?? FlutterTimeline.now;

  /// The engine's frame number, as reported by `FrameTiming.frameNumber`.
  final int frameNumber;

  final int buildMicros;
  final int rasterMicros;
  final int vsyncOverheadMicros;
  final int totalSpanMicros;
  final DateTime time;

  /// Per-block attribution for this frame: block name to its inclusive
  /// duration (`micros`), its duration exclusive of directly nested
  /// children (`selfMicros`), and how many times it ran.
  final Map<String, ({int micros, int selfMicros, int count})> blocks;

  /// The vsync signal timestamp for this frame, from
  /// `FrameTiming.timestampInMicroseconds(FramePhase.vsyncStart)`.
  ///
  /// NEEDS-LIVE-VALIDATION: the engine documents this timestamp only as
  /// microseconds "from some epoch" shared across every `FrameTiming` field,
  /// explicitly disclaiming parity with `DateTime`'s epoch, and says nothing
  /// about parity with [atUs]'s source, `FlutterTimeline.now` (`Timeline.now`
  /// on the VM, `performance.now()` on web). A widget test only ever
  /// supplies `FrameTiming` through its unit-test factory constructor, which
  /// takes raw integers the test itself chooses, so there is no route from
  /// `flutter test` to compare a real engine-reported vsync timestamp
  /// against a real `FlutterTimeline.now` read. Confirming or refuting clock
  /// parity, on either the VM or web, needs a driven run against a live
  /// engine rather than a unit test.
  final int? vsyncStartUs;

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
        'frameNumber': frameNumber,
        'buildMicros': buildMicros,
        'rasterMicros': rasterMicros,
        'vsyncOverheadMicros': vsyncOverheadMicros,
        'totalSpanMicros': totalSpanMicros,
        'time': time.toIso8601String(),
        'blocks': blocks.map(
          (name, block) => MapEntry(name, {
            'micros': block.micros,
            'selfMicros': block.selfMicros,
            'count': block.count,
          }),
        ),
        if (vsyncStartUs != null) 'vsyncStartUs': vsyncStartUs,
        'atUs': atUs,
        if (interactionId != null) 'interactionId': interactionId,
        if (linkedBy != null) 'linkedBy': linkedBy,
      };
}
