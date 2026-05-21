import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_telescope/telescope.dart';
import 'package:logging/logging.dart';

import 'package:example/main.dart';

// Install the telescope core (LogWatcher + VM extensions) once for the process.
// TelescopePlugin.install() is idempotent; repeated calls after the first are
// no-ops, so setUpAll is the right place for the core install.
void _installTelescopeCore() {
  TelescopePlugin.install();
  Logger.root.level = Level.ALL;
}

Widget _buildApp() => App(dio: Dio());

void main() {
  setUpAll(_installTelescopeCore);
  tearDown(TelescopeStore.resetForTesting);

  // ---------------------------------------------------------------------------
  // Smoke test: 4 Card sections + status bar + global controls render.
  // ---------------------------------------------------------------------------

  testWidgets(
    'HomePage builds with 4 watcher sections + status bar + global controls',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Telescope Showroom'), findsOneWidget);
      expect(find.text('HTTP via DioHttpAdapter'), findsOneWidget);
      expect(find.text('Logs via package:logging'), findsOneWidget);
      expect(find.text('Exceptions via ExceptionWatcher'), findsOneWidget);
      expect(find.text('Dumps via DumpWatcher'), findsOneWidget);
      expect(find.text('Global controls'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // Log trigger: Logger.info tap routes into TelescopeStore.recentLogs.
  // LogWatcher is auto-installed by TelescopePlugin.install() in setUpAll.
  // ---------------------------------------------------------------------------

  testWidgets('Logger.info button increments TelescopeStore.recentLogs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Logger.info'));
    await tester.pumpAndSettle();

    expect(TelescopeStore.recentLogs().length, 1);
  });

  // ---------------------------------------------------------------------------
  // Dump trigger: debugPrint button routes into TelescopeStore.recentDumps.
  //
  // DumpWatcher replaces the global debugPrint function. The test framework's
  // debugAssertAllFoundationVarsUnset check fires if debugPrint is not restored
  // before the test ends. We install DumpWatcher INSIDE pumpWidget's callback
  // scope and uninstall via addTearDown (which runs before invariant checks).
  //
  // The debugPrint reference captured by DumpWatcher is the flutter_test
  // framework's own override. Restoring it in uninstall() returns debugPrint
  // to exactly the value it had before install(), satisfying the invariant.
  // ---------------------------------------------------------------------------

  testWidgets(
    'debugPrint single line button increments TelescopeStore.recentDumps',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // DumpWatcher replaces the global debugPrint. The test binding's
      // _verifyInvariants() runs BEFORE addTearDown callbacks, so we must
      // install + uninstall within the test body to restore debugPrint before
      // the invariant check fires.
      final dumpWatcher = DumpWatcher()..install();

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('debugPrint single line'));
      await tester.pumpAndSettle();

      final dumpCount = TelescopeStore.recentDumps().length;

      // Restore debugPrint before the test body exits so _verifyInvariants
      // sees the original flutter_test override (debugPrintSynchronously).
      dumpWatcher.uninstall();

      expect(dumpCount, 1);
    },
  );

  // ---------------------------------------------------------------------------
  // Exception trigger: tap "Sync throw (caught)" which calls
  // FlutterError.reportError from a caught block. ExceptionWatcher records via
  // the FlutterError.onError chain.
  //
  // The test binding sets FlutterError.onError to a rethrowing handler. We
  // null it out before installing ExceptionWatcher so the watcher's chain
  // terminates after recording (no rethrow). The previous test-binding handler
  // is restored after the test via addTearDown to maintain isolation.
  //
  // Using the "Sync throw (caught)" button (FlutterError.reportError path)
  // rather than "Async throw" (Future.microtask path) because fake_async in
  // the test scheduler intercepts microtask errors before PlatformDispatcher
  // can route them, making the async path unreliable in widget tests.
  // ---------------------------------------------------------------------------

  testWidgets(
    'Sync throw (caught) button records into TelescopeStore.recentExceptions',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 1. Capture and clear the binding's FlutterError handler so the watcher
      //    chain terminates without rethrowing when FlutterError.reportError is
      //    called inside the button. The test binding's default handler rethrows
      //    in test mode; we suppress that here to let the watcher record cleanly.
      final previousFlutterOnError = FlutterError.onError;
      FlutterError.onError = null;
      final exceptionWatcher = ExceptionWatcher()..install();

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sync throw (caught)'));
      await tester.pumpAndSettle();

      final exceptionCount = TelescopeStore.recentExceptions().length;

      // 2. Restore both FlutterError.onError and PlatformDispatcher.onError
      //    before _verifyInvariants runs (which happens before addTearDown).
      exceptionWatcher.uninstall();
      FlutterError.onError = previousFlutterOnError;

      expect(exceptionCount, greaterThanOrEqualTo(1));
    },
  );

  // ---------------------------------------------------------------------------
  // HTTP section: buttons are present in the widget tree.
  //
  // NOTE: HTTP trigger assertions are intentionally omitted from the automated
  // suite. httpbin.org network calls are non-deterministic in CI (DNS failures,
  // rate limits, timeouts) and produce flaky results. The 4 HTTP buttons are
  // verified present by this test. The recordRequest interceptor path is
  // exercised in the root telescope test suite. For HTTP visual QA, run
  // `flutter run -d chrome` and tap each HTTP button; the live-tail panel in
  // the HTTP section updates within ~1 second per request.
  // ---------------------------------------------------------------------------

  testWidgets('HTTP section buttons are present in the widget tree'
      ' (network QA via flutter run)', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.text('GET /get'), findsOneWidget);
    expect(find.text('POST /post'), findsOneWidget);
    expect(find.text('GET /status/418'), findsOneWidget);
    expect(find.text('GET /delay/5 (timeout)'), findsOneWidget);
  });
}
