/// An immutable per-frame performance record captured by `FramePerfWatcher`.
///
/// Carries the fields `FrameTiming` actually exposes (`buildMicros`,
/// `rasterMicros`, `vsyncOverheadMicros`, `totalSpanMicros`) plus the
/// per-frame attribution join, `blocks`: a map from block name (a widget
/// build span, a layout span, ...) to how much time it consumed and how
/// many times it ran during that frame.
///
/// `blocks` serializes to a plain JSON object of nested objects, each
/// carrying `micros` and `count`:
/// ```json
/// {"Widget.build": {"micros": 600, "count": 5}}
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
  });

  /// The engine's frame number, as reported by `FrameTiming.frameNumber`.
  final int frameNumber;

  final int buildMicros;
  final int rasterMicros;
  final int vsyncOverheadMicros;
  final int totalSpanMicros;
  final DateTime time;

  /// Per-block attribution for this frame: block name to its total
  /// duration in microseconds and how many times it ran.
  final Map<String, ({int micros, int count})> blocks;

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
            'count': block.count,
          }),
        ),
      };
}
