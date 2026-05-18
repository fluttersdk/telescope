import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/records/exception_record.dart';
import 'package:fluttersdk_telescope/src/telescope_store.dart';
import 'package:fluttersdk_telescope/src/watchers/exception_watcher.dart';

void main() {
  group('ExceptionWatcher', () {
    late ExceptionWatcher watcher;

    setUp(() {
      TelescopeStore.resetForTesting();
      // Restore global handlers to null before each test to ensure isolation.
      FlutterError.onError = null;
      PlatformDispatcher.instance.onError = null;
      watcher = ExceptionWatcher();
    });

    tearDown(() {
      // Always uninstall to avoid state bleed between tests.
      watcher.uninstall();
      FlutterError.onError = null;
      PlatformDispatcher.instance.onError = null;
    });

    // -------------------------------------------------------------------------
    // (a) install hooks both handlers
    // -------------------------------------------------------------------------

    group('install()', () {
      test('replaces FlutterError.onError with own handler', () {
        watcher.install();
        expect(FlutterError.onError, isNotNull);
      });

      test('replaces PlatformDispatcher.instance.onError with own handler', () {
        watcher.install();
        expect(PlatformDispatcher.instance.onError, isNotNull);
      });
    });

    // -------------------------------------------------------------------------
    // (b) uninstall restores both previous handlers exactly
    // -------------------------------------------------------------------------

    group('uninstall()', () {
      test('restores FlutterError.onError to the previous handler', () {
        FlutterExceptionHandler? spy;
        spy = (FlutterErrorDetails _) {};
        FlutterError.onError = spy;

        watcher.install();
        watcher.uninstall();

        expect(FlutterError.onError, same(spy));
      });

      test(
          'restores PlatformDispatcher.instance.onError to the previous handler',
          () {
        bool spy(Object error, StackTrace stack) => true;

        PlatformDispatcher.instance.onError = spy;

        watcher.install();
        watcher.uninstall();

        expect(PlatformDispatcher.instance.onError, same(spy));
      });
    });

    // -------------------------------------------------------------------------
    // (c) records flow into TelescopeStore.onExceptionRecord for BOTH paths
    // -------------------------------------------------------------------------

    group('recording', () {
      test('FlutterError.reportError path records into TelescopeStore',
          () async {
        watcher.install();

        final recorded = <ExceptionRecord>[];
        final sub = TelescopeStore.onExceptionRecord.listen(recorded.add);

        FlutterError.reportError(
          FlutterErrorDetails(exception: StateError('flutter-error-path')),
        );

        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(recorded, hasLength(1));
        expect(recorded.first.message, contains('flutter-error-path'));
      });

      test('PlatformDispatcher.onError path records into TelescopeStore',
          () async {
        watcher.install();

        final recorded = <ExceptionRecord>[];
        final sub = TelescopeStore.onExceptionRecord.listen(recorded.add);

        // Simulate a PlatformDispatcher.onError invocation.
        final handled = PlatformDispatcher.instance.onError!(
          ArgumentError('platform-dispatcher-path'),
          StackTrace.current,
        );

        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(handled, isTrue);
        expect(recorded, hasLength(1));
        expect(recorded.first.message, contains('platform-dispatcher-path'));
      });
    });

    // -------------------------------------------------------------------------
    // (d) previous handler is preserved and CALLED when present
    // -------------------------------------------------------------------------

    group('chain-preservation', () {
      test('calls previous FlutterError.onError handler when present', () {
        var previousCalled = false;
        FlutterError.onError = (FlutterErrorDetails _) {
          previousCalled = true;
        };

        watcher.install();

        FlutterError.reportError(
          FlutterErrorDetails(exception: Exception('chain-test')),
        );

        expect(previousCalled, isTrue);
      });

      test('calls previous PlatformDispatcher.onError handler when present',
          () {
        var previousCalled = false;
        PlatformDispatcher.instance.onError = (Object _, StackTrace __) {
          previousCalled = true;
          return true;
        };

        watcher.install();

        PlatformDispatcher.instance.onError!(
          Exception('chain-test-platform'),
          StackTrace.current,
        );

        expect(previousCalled, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // (e) idempotent install: calling install() twice does not double-hook
    // -------------------------------------------------------------------------

    group('idempotency', () {
      test('calling install() twice does not double-wrap FlutterError.onError',
          () {
        watcher.install();
        final handlerAfterFirst = FlutterError.onError;

        watcher.install();
        final handlerAfterSecond = FlutterError.onError;

        // The handler must be the exact same object; no second wrapper.
        expect(handlerAfterSecond, same(handlerAfterFirst));
      });

      test('calling install() twice only records each exception once',
          () async {
        watcher.install();
        watcher.install(); // second call must be a no-op

        final recorded = <ExceptionRecord>[];
        final sub = TelescopeStore.onExceptionRecord.listen(recorded.add);

        FlutterError.reportError(
          FlutterErrorDetails(exception: Exception('idempotency-check')),
        );

        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(recorded, hasLength(1));
      });
    });
  });
}
