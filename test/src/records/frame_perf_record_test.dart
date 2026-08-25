import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/records/frame_perf_record.dart';
import 'package:fluttersdk_telescope/src/records/http_request_record.dart';
import 'package:fluttersdk_telescope/src/telescope_store.dart';

void main() {
  final fixedTime = DateTime.utc(2026, 8, 25, 12, 0, 0);

  setUp(() {
    TelescopeStore.resetForTesting();
  });

  group('FramePerfRecord', () {
    test('constructor sets every field', () {
      final record = FramePerfRecord(
        frameNumber: 42,
        buildMicros: 1200,
        rasterMicros: 3400,
        vsyncOverheadMicros: 500,
        totalSpanMicros: 5100,
        time: fixedTime,
        blocks: const <String, ({int micros, int count})>{
          'Widget.build': (micros: 800, count: 4),
        },
      );

      expect(record.frameNumber, equals(42));
      expect(record.buildMicros, equals(1200));
      expect(record.rasterMicros, equals(3400));
      expect(record.vsyncOverheadMicros, equals(500));
      expect(record.totalSpanMicros, equals(5100));
      expect(record.time, equals(fixedTime));
      expect(
        record.blocks,
        equals(<String, ({int micros, int count})>{
          'Widget.build': (micros: 800, count: 4),
        }),
      );
    });

    test('toJson round-trips every field including an empty block map', () {
      final record = FramePerfRecord(
        frameNumber: 7,
        buildMicros: 100,
        rasterMicros: 200,
        vsyncOverheadMicros: 10,
        totalSpanMicros: 310,
        time: fixedTime,
        blocks: const <String, ({int micros, int count})>{},
      );

      expect(record.toJson(), <String, dynamic>{
        'frameNumber': 7,
        'buildMicros': 100,
        'rasterMicros': 200,
        'vsyncOverheadMicros': 10,
        'totalSpanMicros': 310,
        'time': '2026-08-25T12:00:00.000Z',
        'blocks': <String, dynamic>{},
      });
    });

    test('toJson serializes a non-empty block map as nested micros/count',
        () {
      final record = FramePerfRecord(
        frameNumber: 8,
        buildMicros: 900,
        rasterMicros: 1100,
        vsyncOverheadMicros: 20,
        totalSpanMicros: 2020,
        time: fixedTime,
        blocks: const <String, ({int micros, int count})>{
          'RenderBox.layout': (micros: 300, count: 2),
          'Widget.build': (micros: 600, count: 5),
        },
      );

      final json = record.toJson();

      expect(json['blocks'], <String, dynamic>{
        'RenderBox.layout': {'micros': 300, 'count': 2},
        'Widget.build': {'micros': 600, 'count': 5},
      });

      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(
        (decoded['blocks'] as Map<String, dynamic>)['Widget.build'],
        equals(<String, dynamic>{'micros': 600, 'count': 5}),
      );
    });

    test('two records with same fields are not identical (default identity)',
        () {
      final a = FramePerfRecord(
        frameNumber: 1,
        buildMicros: 1,
        rasterMicros: 1,
        vsyncOverheadMicros: 1,
        totalSpanMicros: 3,
        time: fixedTime,
        blocks: const <String, ({int micros, int count})>{},
      );
      final b = FramePerfRecord(
        frameNumber: 1,
        buildMicros: 1,
        rasterMicros: 1,
        vsyncOverheadMicros: 1,
        totalSpanMicros: 3,
        time: fixedTime,
        blocks: const <String, ({int micros, int count})>{},
      );

      expect(identical(a, b), isFalse);
    });
  });

  group('TelescopeStore frame perf buffer', () {
    FramePerfRecord frame(int n) => FramePerfRecord(
          frameNumber: n,
          buildMicros: n,
          rasterMicros: n,
          vsyncOverheadMicros: n,
          totalSpanMicros: n * 3,
          time: fixedTime,
          blocks: const <String, ({int micros, int count})>{},
        );

    test('recordFramePerf appends and recentFramePerf returns in order', () {
      TelescopeStore.recordFramePerf(frame(1));
      TelescopeStore.recordFramePerf(frame(2));
      TelescopeStore.recordFramePerf(frame(3));

      final recent = TelescopeStore.recentFramePerf();

      expect(
        recent.map((r) => r.frameNumber).toList(),
        equals(<int>[1, 2, 3]),
      );
    });

    test(
        'setting the frame buffer own cap and recording cap+5 evicts the '
        'oldest, leaving exactly cap surviving', () {
      TelescopeStore.setFramePerfCapacity(10);

      for (var i = 0; i < 15; i++) {
        TelescopeStore.recordFramePerf(frame(i));
      }

      final recent = TelescopeStore.recentFramePerf();

      expect(recent.length, equals(10));
      // Oldest 5 (frameNumber 0..4) evicted; surviving range is 5..14.
      expect(recent.first.frameNumber, equals(5));
      expect(recent.last.frameNumber, equals(14));
    });

    test('recording many frames leaves the shared _cap (other buffers) '
        'untouched', () {
      TelescopeStore.setFramePerfCapacity(10);

      for (var i = 0; i < 15; i++) {
        TelescopeStore.recordFramePerf(frame(i));
      }

      TelescopeStore.recordHttp(HttpRequestRecord(
        url: 'https://example.test/',
        method: 'GET',
        statusCode: 200,
        durationMs: 5,
        isError: false,
        timestamp: fixedTime,
      ));

      for (var i = 0; i < 600; i++) {
        TelescopeStore.recordHttp(HttpRequestRecord(
          url: 'https://example.test/',
          method: 'GET',
          statusCode: 200,
          durationMs: i,
          isError: false,
          timestamp: fixedTime,
        ));
      }

      // The shared _cap default (500) governs the http buffer; the frame
      // buffer's own cap of 10 must not have leaked into it.
      expect(TelescopeStore.recentHttp().length, equals(500));
    });

    test('clearFramePerf() empties only the frame buffer', () {
      TelescopeStore.recordFramePerf(frame(1));
      TelescopeStore.recordHttp(HttpRequestRecord(
        url: 'https://example.test/',
        method: 'GET',
        statusCode: 200,
        durationMs: 5,
        isError: false,
        timestamp: fixedTime,
      ));

      TelescopeStore.clearFramePerf();

      expect(TelescopeStore.recentFramePerf(), isEmpty);
      expect(TelescopeStore.recentHttp(), isNotEmpty);
    });

    test('resetForTesting() empties the frame buffer and restores its cap',
        () {
      TelescopeStore.setFramePerfCapacity(5);

      for (var i = 0; i < 8; i++) {
        TelescopeStore.recordFramePerf(frame(i));
      }

      TelescopeStore.resetForTesting();

      expect(TelescopeStore.recentFramePerf(), isEmpty);

      for (var i = 0; i < 4000; i++) {
        TelescopeStore.recordFramePerf(frame(i));
      }

      // Default frame-perf capacity is 3600; verify it was restored rather
      // than left at the small test value of 5.
      expect(TelescopeStore.recentFramePerf().length, equals(3600));
    });
  });
}
