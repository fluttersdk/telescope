import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/records/dump_record.dart';
import 'package:fluttersdk_telescope/src/telescope_store.dart';
import 'package:fluttersdk_telescope/src/watchers/dump_watcher.dart';

void main() {
  group('DumpWatcher', () {
    late DumpWatcher watcher;
    late DebugPrintCallback previousDebugPrint;

    setUp(() {
      TelescopeStore.resetForTesting();
      // Save and restore the real debugPrint around every test.
      previousDebugPrint = debugPrint;
      watcher = DumpWatcher();
    });

    tearDown(() {
      // Always uninstall so the global is clean for next test.
      watcher.uninstall();
      // Belt-and-suspenders: restore directly in case uninstall is under test.
      debugPrint = previousDebugPrint;
    });

    // -------------------------------------------------------------------------
    // (a) install replaces debugPrint
    // -------------------------------------------------------------------------

    group('install()', () {
      test('replaces the global debugPrint with own callback', () {
        final before = debugPrint;
        watcher.install();
        expect(debugPrint, isNot(same(before)));
      });
    });

    // -------------------------------------------------------------------------
    // (b) uninstall restores previous reference exactly
    // -------------------------------------------------------------------------

    group('uninstall()', () {
      test('restores debugPrint to the exact previous reference', () {
        // Set a known spy as the "previous" before install.
        void spy(String? msg, {int? wrapWidth}) {}
        debugPrint = spy;

        watcher.install();
        watcher.uninstall();

        expect(debugPrint, same(spy));
      });
    });

    // -------------------------------------------------------------------------
    // (c) debugPrint('hello') after install records DumpRecord to stream
    // -------------------------------------------------------------------------

    group('recording', () {
      test(
          'debugPrint call after install records a DumpRecord to onDumpRecord stream',
          () async {
        watcher.install();

        final recorded = <DumpRecord>[];
        final sub = TelescopeStore.onDumpRecord.listen(recorded.add);

        debugPrint('hello');

        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(recorded, hasLength(1));
        expect(recorded.first.message, equals('hello'));
      });

      test('records null message as empty string', () async {
        watcher.install();

        final recorded = <DumpRecord>[];
        final sub = TelescopeStore.onDumpRecord.listen(recorded.add);

        // debugPrint allows null message per its signature.
        debugPrint(null);

        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(recorded, hasLength(1));
        expect(recorded.first.message, equals(''));
      });

      test('preserves wrapWidth in DumpRecord when provided', () async {
        watcher.install();

        final recorded = <DumpRecord>[];
        final sub = TelescopeStore.onDumpRecord.listen(recorded.add);

        debugPrint('wide message', wrapWidth: 80);

        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(recorded, hasLength(1));
        expect(recorded.first.wrapWidth, equals(80));
      });
    });

    // -------------------------------------------------------------------------
    // (d) previous debugPrint is CALLED on record (chain-preserve)
    // -------------------------------------------------------------------------

    group('chain-preservation', () {
      test('calls previous debugPrint callback when recording', () {
        var previousCalled = false;
        String? capturedMsg;
        int? capturedWrapWidth;

        debugPrint = (String? msg, {int? wrapWidth}) {
          previousCalled = true;
          capturedMsg = msg;
          capturedWrapWidth = wrapWidth;
        };

        watcher.install();
        debugPrint('chain-test', wrapWidth: 42);

        expect(previousCalled, isTrue);
        expect(capturedMsg, equals('chain-test'));
        expect(capturedWrapWidth, equals(42));
      });
    });

    // -------------------------------------------------------------------------
    // (e) idempotent install: calling install() twice results in install once
    // -------------------------------------------------------------------------

    group('idempotency', () {
      test('calling install() twice does not double-wrap debugPrint', () {
        watcher.install();
        final handlerAfterFirst = debugPrint;

        watcher.install();
        final handlerAfterSecond = debugPrint;

        expect(handlerAfterSecond, same(handlerAfterFirst));
      });

      test('calling install() twice only records each message once', () async {
        watcher.install();
        watcher.install(); // second call must be a no-op

        final recorded = <DumpRecord>[];
        final sub = TelescopeStore.onDumpRecord.listen(recorded.add);

        debugPrint('idempotency-check');

        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(recorded, hasLength(1));
      });
    });

    // -------------------------------------------------------------------------
    // (f) name getter returns 'dump'
    // -------------------------------------------------------------------------

    group('name', () {
      test('returns "dump"', () {
        expect(watcher.name, equals('dump'));
      });
    });
  });
}
