import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/records/frame_perf_record.dart';
import 'package:fluttersdk_telescope/src/telescope_store.dart';
import 'package:fluttersdk_telescope/src/watchers/frame_perf_watcher.dart';

/// Builds a [FrameTiming] with the raw microsecond timestamps the public
/// factory takes. That factory exists for unit tests (its own docstring says
/// so); `tester.pump()` delivers no [FrameTiming] of its own, so every timing
/// in this file is injected.
FrameTiming buildTiming({
  int frameNumber = 1,
  int vsyncOverheadMicros = 1000,
  int buildMicros = 5000,
  int rasterMicros = 2000,
}) {
  const int vsyncStart = 0;
  final int buildStart = vsyncStart + vsyncOverheadMicros;
  final int buildFinish = buildStart + buildMicros;
  final int rasterStart = buildFinish;
  final int rasterFinish = rasterStart + rasterMicros;

  return FrameTiming(
    vsyncStart: vsyncStart,
    buildStart: buildStart,
    buildFinish: buildFinish,
    rasterStart: rasterStart,
    rasterFinish: rasterFinish,
    rasterFinishWallTime: rasterFinish,
    frameNumber: frameNumber,
  );
}

/// Fires a timings batch the way the engine would.
///
/// Asserts the dispatcher is armed first: `removeTimingsCallback` nulls
/// `onReportTimings` once the last callback is gone, and a silently-null
/// `?.call` would make every negative assertion in this file vacuous.
void fireTimings(List<FrameTiming> timings) {
  final TimingsCallback? report = PlatformDispatcher.instance.onReportTimings;
  expect(
    report,
    isNotNull,
    reason: 'the platform dispatcher must be armed for an injected batch '
        'to reach any timings callback at all',
  );
  report!(timings);
}

void main() {
  group('FramePerfWatcher', () {
    late FramePerfWatcher watcher;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      TelescopeStore.resetForTesting();
      FramePerfWatcher.resetLivenessCounterForTesting();
      watcher = FramePerfWatcher();
    });

    tearDown(() {
      watcher.uninstall();
      TelescopeStore.resetForTesting();
      FramePerfWatcher.resetLivenessCounterForTesting();
      // Statics restored: collection left enabled would make the next file's
      // frames collect blocks, and a stale counter would fail the liveness
      // assertions below.
      FlutterTimeline.debugCollectionEnabled = false;
    });

    test('carries the frozen watcher name', () {
      expect(watcher.name, 'frame_perf');
    });

    group('install()', () {
      test('installing twice then firing one batch records exactly one frame',
          () {
        watcher.install();
        watcher.install();

        fireTimings(<FrameTiming>[buildTiming(frameNumber: 7)]);

        final List<FramePerfRecord> records = TelescopeStore.recentFramePerf();
        expect(records, hasLength(1));
        expect(records.single.frameNumber, 7);
        expect(records.single.buildMicros, 5000);
        expect(records.single.rasterMicros, 2000);
        expect(records.single.vsyncOverheadMicros, 1000);
        expect(records.single.totalSpanMicros, 8000);
      });

      testWidgets(
          'a SECOND watcher instance does not double the liveness '
          'counter', (WidgetTester tester) async {
        // Two registrations is the expected case, not a mistake:
        // MagicPerfIntegration registers one and this class's own docs tell a
        // host to register one, while TelescopePlugin.registerWatcher appends
        // without deduping. The counter is static, so a second installed
        // instance would increment it twice per frame. That is not cosmetic:
        // a backgrounded page produces exactly ONE frame, two watchers make
        // that an advance of two, and perf_end's refusal trips at one, so the
        // page that rendered nothing would get a report of near-zeros.
        final FramePerfWatcher second = FramePerfWatcher();
        addTearDown(second.uninstall);

        watcher.install();
        second.install();

        tester.binding.scheduleFrame();
        await tester.pump();

        expect(FramePerfWatcher.livenessCounter, 1);
      });

      test('a timings callback registered before the watcher still fires', () {
        // The additive-coexistence guarantee: `addTimingsCallback` appends to
        // a list, so sentry_flutter's own listener must survive our install.
        var sentinelCalls = 0;
        void sentinel(List<FrameTiming> _) => sentinelCalls += 1;

        SchedulerBinding.instance.addTimingsCallback(sentinel);
        addTearDown(() => SchedulerBinding.instance.removeTimingsCallback(
              sentinel,
            ));

        watcher.install();
        fireTimings(<FrameTiming>[buildTiming()]);

        expect(sentinelCalls, 1);
        expect(TelescopeStore.recentFramePerf(), hasLength(1));
      });

      testWidgets('a frame does not throw while collection is disabled',
          (WidgetTester tester) async {
        expect(FlutterTimeline.debugCollectionEnabled, isFalse);

        watcher.install();

        await tester.pumpWidget(const SizedBox.shrink());

        expect(tester.takeException(), isNull);
        expect(FramePerfWatcher.livenessCounter, 1);
      });
    });

    group('uninstall()', () {
      test('firing a batch after uninstall records nothing', () {
        watcher.install();
        watcher.uninstall();

        fireTimings(<FrameTiming>[buildTiming()]);

        expect(TelescopeStore.recentFramePerf(), isEmpty);
      });

      test('uninstalling before installing is a no-op', () {
        expect(watcher.uninstall, returnsNormally);

        // And the watcher is still installable afterwards.
        watcher.install();
        fireTimings(<FrameTiming>[buildTiming()]);
        expect(TelescopeStore.recentFramePerf(), hasLength(1));
      });
    });

    group('livenessCounter', () {
      testWidgets('equals exactly N after N successive pumps',
          (WidgetTester tester) async {
        await tester.pumpWidget(const SizedBox.shrink());

        watcher.install();
        expect(FramePerfWatcher.livenessCounter, 0);

        // `scheduleFrame()` before every pump is required, not decorative:
        // `AutomatedTestWidgetsFlutterBinding.pump` runs a frame only
        // `if (hasScheduledFrame)` (flutter_test binding.dart:2257) and
        // `addPostFrameCallback` does not schedule one. A bare pump with
        // nothing dirty produces no frame at all and the counter stays at 0,
        // which is the correct product semantics (no frame drawn, no liveness)
        // rather than a harness quirk to work around.
        for (int i = 0; i < 3; i++) {
          tester.binding.scheduleFrame();
          await tester.pump();
        }

        // Exactly 3, not "greater than 0": a one-shot post-frame callback
        // that never re-registers itself reads 1 here and then stops
        // forever, which is a drain that dies on frame 1.
        expect(FramePerfWatcher.livenessCounter, 3);
      });
    });

    group('the frame join', () {
      testWidgets('a record carries both the frame timing and its block map',
          (WidgetTester tester) async {
        FlutterTimeline.debugCollectionEnabled = true;

        watcher.install();

        await tester.pumpWidget(
          Builder(
            builder: (BuildContext context) {
              FlutterTimeline.startSync('JoinProbe');
              FlutterTimeline.finishSync();
              return const SizedBox.shrink();
            },
          ),
        );

        fireTimings(<FrameTiming>[buildTiming(frameNumber: 99)]);

        final FramePerfRecord record = TelescopeStore.recentFramePerf().single;
        expect(record.frameNumber, 99);
        expect(record.buildMicros, 5000);
        expect(record.blocks, isNotEmpty);
        expect(record.blocks['JoinProbe']?.count, 1);
      });

      testWidgets('a timing with no block map still records, with an empty map',
          (WidgetTester tester) async {
        watcher.install();

        await tester.pumpWidget(const SizedBox.shrink());
        fireTimings(<FrameTiming>[buildTiming(frameNumber: 3)]);

        final FramePerfRecord record = TelescopeStore.recentFramePerf().single;
        expect(record.frameNumber, 3);
        expect(record.blocks, isEmpty);
      });
    });
  });
}
