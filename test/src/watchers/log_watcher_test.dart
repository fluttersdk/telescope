import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import 'package:fluttersdk_telescope/src/records/log_record_entry.dart';
import 'package:fluttersdk_telescope/src/telescope_store.dart';
import 'package:fluttersdk_telescope/src/watchers/log_watcher.dart';

void main() {
  group('LogWatcher', () {
    late LogWatcher watcher;

    setUp(() {
      TelescopeStore.resetForTesting();
      // Allow all log levels to flow through the root logger.
      Logger.root.level = Level.ALL;
      watcher = LogWatcher();
    });

    tearDown(() {
      // Always uninstall to cancel the subscription and avoid state bleed.
      watcher.uninstall();
    });

    // -------------------------------------------------------------------------
    // (a) name getter
    // -------------------------------------------------------------------------

    group('name', () {
      test('returns "log"', () {
        expect(watcher.name, 'log');
      });
    });

    // -------------------------------------------------------------------------
    // (b) install() subscribes to Logger.root.onRecord
    // -------------------------------------------------------------------------

    group('install()', () {
      test('a log message emitted after install is recorded in TelescopeStore',
          () async {
        watcher.install();

        final recorded = <LogRecordEntry>[];
        final sub = TelescopeStore.onLogRecord.listen(recorded.add);

        Logger('test').info('hello');

        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(recorded, hasLength(1));
        expect(recorded.first.message, 'hello');
        expect(recorded.first.loggerName, 'test');
      });

      test('recorded entry carries the correct level name', () async {
        watcher.install();

        final recorded = <LogRecordEntry>[];
        final sub = TelescopeStore.onLogRecord.listen(recorded.add);

        Logger('level-check').warning('watch out');

        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(recorded.first.level, 'WARNING');
      });
    });

    // -------------------------------------------------------------------------
    // (c) uninstall() cancels the subscription
    // -------------------------------------------------------------------------

    group('uninstall()', () {
      test('no records flow after uninstall', () async {
        watcher.install();
        watcher.uninstall();

        final recorded = <LogRecordEntry>[];
        final sub = TelescopeStore.onLogRecord.listen(recorded.add);

        Logger('after-uninstall').info('should not appear');

        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(recorded, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // (d) idempotent install: calling install() twice does not double-record
    // -------------------------------------------------------------------------

    group('idempotency', () {
      test('calling install() twice records each log message exactly once',
          () async {
        watcher.install();
        watcher.install(); // second call must be a no-op

        final recorded = <LogRecordEntry>[];
        final sub = TelescopeStore.onLogRecord.listen(recorded.add);

        Logger('idempotency-check').info('one-message');

        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(recorded, hasLength(1));
      });
    });
  });
}
