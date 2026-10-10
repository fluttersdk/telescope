import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/cursor_follow.dart';

void main() {
  group('followCursor', () {
    test('passes each returned cursor to the next read', () async {
      final seen = <int?>[];
      final cursors = <int?>[300, 400, 500];

      await followCursor(
        read: (int? since) async {
          seen.add(since);
          return cursors[seen.length - 1];
        },
        delay: (Duration d) async {},
        shouldStop: () => seen.length >= 3,
      );

      expect(seen, equals(<int?>[null, 300, 400]));
    });

    test('starts from the given since', () async {
      final seen = <int?>[];

      await followCursor(
        read: (int? since) async {
          seen.add(since);
          return since;
        },
        since: 100,
        delay: (Duration d) async {},
        shouldStop: () => true,
      );

      expect(seen, equals(<int?>[100]));
    });

    test('keeps the last cursor while a read returns none', () async {
      final seen = <int?>[];
      final cursors = <int?>[300, null, null];

      await followCursor(
        read: (int? since) async {
          seen.add(since);
          return cursors[seen.length - 1];
        },
        delay: (Duration d) async {},
        shouldStop: () => seen.length >= 3,
      );

      expect(seen, equals(<int?>[null, 300, 300]));
    });

    test('reads once and does not wait when told to stop at once', () async {
      var reads = 0;
      final delays = <Duration>[];

      await followCursor(
        read: (int? since) async {
          reads++;
          return null;
        },
        delay: (Duration d) async => delays.add(d),
        shouldStop: () => true,
      );

      expect(reads, equals(1));
      expect(delays, isEmpty);
    });

    test('waits the interval between two reads', () async {
      final delays = <Duration>[];
      var reads = 0;

      await followCursor(
        read: (int? since) async => ++reads,
        interval: const Duration(milliseconds: 250),
        delay: (Duration d) async => delays.add(d),
        shouldStop: () => reads >= 3,
      );

      expect(
          delays,
          equals(const [
            Duration(milliseconds: 250),
            Duration(milliseconds: 250),
          ]));
    });

    test('on the real clock waits the interval and runs until a read fails',
        () async {
      var reads = 0;
      final clock = Stopwatch()..start();

      await expectLater(
        followCursor(
          read: (int? since) async {
            if (++reads == 3) throw StateError('The app is gone.');
            return reads;
          },
          interval: const Duration(milliseconds: 50),
        ),
        throwsStateError,
      );

      expect(reads, equals(3));
      expect(clock.elapsed,
          greaterThanOrEqualTo(const Duration(milliseconds: 90)));
    });

    test('defaults to a one second interval', () async {
      final delays = <Duration>[];
      var reads = 0;

      await followCursor(
        read: (int? since) async => ++reads,
        delay: (Duration d) async => delays.add(d),
        shouldStop: () => reads >= 2,
      );

      expect(delays, equals(const [Duration(seconds: 1)]));
    });
  });
}
