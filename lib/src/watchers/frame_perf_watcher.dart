import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../records/frame_perf_record.dart';
import '../telescope_store.dart';
import 'watcher.dart';

/// Captures per-frame performance by joining two sources the engine reports
/// separately: frame magnitude from [SchedulerBinding.addTimingsCallback],
/// and per-frame attribution drained from [FlutterTimeline] at the end of
/// every frame.
///
/// The two arrive at different times. The post-frame drain runs at the end of
/// frame N and yields that frame's block map, but it does not know the
/// engine's frame number; the timings callback carries
/// [FrameTiming.frameNumber] but arrives late and batched (roughly 100ms
/// later on web). So the drain parks its block map in a bounded pending map
/// and the timings callback is the only emission point, popping the matching
/// map and writing one complete [FramePerfRecord] per [FrameTiming].
///
/// Unlike [ExceptionWatcher] and [DumpWatcher] there is nothing to
/// chain-preserve here: [SchedulerBinding.addTimingsCallback] appends to a
/// list rather than replacing a single global slot, so every other listener
/// (sentry_flutter's among them) keeps receiving timings while this watcher
/// is installed. [uninstall] removes exactly the callback [install] added.
///
/// This watcher is opt-in and NOT auto-installed by
/// [TelescopePlugin.install]. Register it explicitly:
///
/// ```dart
/// TelescopePlugin.registerWatcher(FramePerfWatcher());
/// ```
///
/// Attribution only flows while [FlutterTimeline.debugCollectionEnabled] is
/// true, which a measurement session turns on. Until then the watcher records
/// frame magnitude alone and stays silent about blocks.
class FramePerfWatcher implements TelescopeWatcher {
  /// How many un-joined block maps the pending map holds before the oldest is
  /// dropped.
  ///
  /// The timings batch lags the frame it describes by about 100ms on web,
  /// roughly 6 frames at 60fps, so this bound is not sized against normal
  /// lag. It bounds the case where a batch never arrives at all, which would
  /// otherwise grow the pending map for the life of the session; 300 entries
  /// is five seconds of frames, far past any real batch delay.
  static const int _maxPendingFrames = 300;

  @override
  String get name => 'frame_perf';

  static int _livenessCounter = 0;

  /// Monotonic count of frames actually drawn since the first [install].
  ///
  /// This advancing is the only reliable proof that the engine is rendering,
  /// which is why it is read before any number this watcher reports is
  /// believed. The obvious signal does not work: on a Chrome page that Chrome
  /// had backgrounded (one frame produced in two seconds),
  /// `SchedulerBinding.framesEnabled` was measured reporting `true`,
  /// alongside a `resumed` lifecycle and an armed `onReportTimings`.
  ///
  /// Static because it is read from a VM Service extension handler, and
  /// [TelescopePlugin] keeps its watcher list private with no accessor: there
  /// is no route from a handler to a watcher instance.
  static int get livenessCounter => _livenessCounter;

  @visibleForTesting
  static void resetLivenessCounterForTesting() => _livenessCounter = 0;

  /// The exact callback handed to [SchedulerBinding.addTimingsCallback], kept
  /// so [uninstall] removes that one rather than a fresh tear-off.
  late final TimingsCallback _timingsCallback = _onTimings;

  /// Block maps drained but not yet joined to a [FrameTiming], keyed by
  /// [_nextDrainKey] at the time of the drain.
  final Map<int, Map<String, ({int micros, int count})>> _pendingBlocks =
      <int, Map<String, ({int micros, int count})>>{};

  int _nextDrainKey = 0;
  int _nextJoinKey = 0;
  bool _drainScheduled = false;
  bool _installed = false;

  @override
  void install() {
    if (_installed) return;
    _installed = true;

    // 1. Frame magnitude. Purely additive: no previous handler to save, and
    //    nothing to restore beyond removing this one callback.
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback);

    // 2. Per-frame attribution and liveness, both from the post-frame drain.
    _scheduleDrain();
  }

  @override
  void uninstall() {
    if (!_installed) return;
    _installed = false;

    SchedulerBinding.instance.removeTimingsCallback(_timingsCallback);

    // 3. A scheduled post-frame callback cannot be cancelled, so the drain
    //    stops itself: it reads `_installed` and declines to re-register.
    //    Its parked block maps go with it, and the join cursors restart
    //    together so a later re-install joins from a clean zero.
    _pendingBlocks.clear();
    _nextDrainKey = 0;
    _nextJoinKey = 0;
  }

  void _scheduleDrain() {
    // Guarded rather than unconditional so an install / uninstall / install
    // sequence cannot leave two self-re-registering chains running: the
    // callback queued by the first install is still pending and will pick the
    // chain back up itself.
    if (_drainScheduled) return;
    _drainScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback(_drain);
  }

  void _drain(Duration _) {
    _drainScheduled = false;
    if (!_installed) return;

    // Unconditional, and before the collection guard: liveness has to advance
    // even when no measurement session is running, because "is the engine
    // rendering" is the question asked before a session starts. It counts
    // frames DRAWN, which is why it is incremented here rather than in the
    // microtask below.
    _livenessCounter += 1;

    // A condition, not a caught exception: `debugCollect()` throws a
    // StateError when collection was never enabled, and this watcher is
    // installed long before any session turns it on.
    if (FlutterTimeline.debugCollectionEnabled) {
      // The key is captured now, not read inside the closure, because
      // `_nextDrainKey` advances below and the microtask runs later.
      final int key = _nextDrainKey;
      scheduleMicrotask(() => _park(key, FlutterTimeline.debugCollect()));
    }
    _nextDrainKey += 1;

    // The last act, always. `addPostFrameCallback` is one-shot, so a drain
    // that does not re-register itself here runs exactly once: every frame
    // after the first goes unattributed and, worse, uncounted, leaving the
    // liveness counter frozen at 1 for the rest of the session.
    _scheduleDrain();
  }

  /// Parks one frame's aggregated blocks for the timings callback to pop.
  ///
  /// The collect that feeds this runs in a microtask scheduled by [_drain],
  /// and that hop is load-bearing rather than tidy.
  /// [FlutterTimeline.debugCollect] calls `debugReset()` internally, which
  /// swaps the block buffer while the nesting stack it swaps around
  /// (`_startStack`, `_stackPointer`) is static and survives the swap. A block
  /// still open across the reset writes its stale start time into the NEW
  /// buffer and reports an enormous duration, and the assert that would catch
  /// it is stripped outside debug.
  ///
  /// A post-frame callback is NOT far enough on its own, which is easy to get
  /// wrong because it reads as "after the frame":
  /// `SchedulerBinding.handleDrawFrame` wraps the entire post-frame phase in
  /// its own `POST_FRAME` span, so a callback there runs with
  /// `_stackPointer == 1` and collecting inline trips
  /// `assert(_stackPointer == 0)`. The microtask runs once `handleDrawFrame`
  /// has returned and that span has closed, which is the first point where the
  /// frame's instrumentation has actually unwound. Flutter's own benchmark
  /// harness reaches the same point by overriding `frameDidDraw()`, which a
  /// watcher cannot do without replacing the binding.
  void _park(int key, AggregatedTimings timings) {
    final Map<String, ({int micros, int count})> blocks =
        <String, ({int micros, int count})>{
      for (final AggregatedTimedBlock block in timings.aggregatedBlocks)
        block.name: (micros: block.duration.round(), count: block.count),
    };
    if (blocks.isEmpty) return;

    _pendingBlocks[key] = blocks;
    while (_pendingBlocks.length > _maxPendingFrames) {
      _pendingBlocks.remove(_pendingBlocks.keys.first);
    }
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final FrameTiming timing in timings) {
      // The join is positional, because only one of the two sources knows the
      // engine's frame number: drains and timings each run once per frame in
      // order, so the Nth timing belongs to the Nth drain. Both cursors are
      // monotonic, so a burst of timings after a stall walks past the evicted
      // keys and realigns on the ones still parked.
      final Map<String, ({int micros, int count})>? blocks =
          _pendingBlocks.remove(_nextJoinKey);
      _nextJoinKey += 1;

      // A timing with no block map still emits: frame magnitude without
      // attribution is worth reporting. The reverse is not, so a block map
      // whose timing never arrives is simply dropped by the bound above.
      TelescopeStore.recordFramePerf(
        FramePerfRecord(
          frameNumber: timing.frameNumber,
          buildMicros: timing.buildDuration.inMicroseconds,
          rasterMicros: timing.rasterDuration.inMicroseconds,
          vsyncOverheadMicros: timing.vsyncOverhead.inMicroseconds,
          totalSpanMicros: timing.totalSpan.inMicroseconds,
          time: DateTime.now(),
          blocks: blocks ?? const <String, ({int micros, int count})>{},
        ),
      );
    }
  }
}
