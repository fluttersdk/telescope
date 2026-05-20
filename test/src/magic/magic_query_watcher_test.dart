// flutter_test re-exports its own `EventDispatcher` (for pointer events)
// via test_pointer.dart; hide it so the magic-side dispatcher resolves
// unambiguously below.
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import 'package:fluttersdk_telescope/src/telescope_store.dart';
import 'package:magic/magic.dart';

void main() {
  group('MagicQueryWatcher', () {
    late MagicQueryWatcher watcher;

    setUp(() {
      EventDispatcher.instance.clear();
      TelescopeStore.resetForTesting();
      watcher = MagicQueryWatcher();
    });

    tearDown(() {
      EventDispatcher.instance.clear();
      TelescopeStore.resetForTesting();
    });

    test('name returns "magic_query"', () {
      expect(watcher.name, 'magic_query');
    });

    test('install subscribes to QueryExecuted and records on dispatch',
        () async {
      watcher.install();

      await EventDispatcher.instance.dispatch(QueryExecuted(
        sql: 'SELECT * FROM monitors WHERE id = ?',
        bindings: const <dynamic>[42],
        timeMs: 12,
        connectionName: 'primary',
      ));

      final queries = TelescopeStore.recentQueries();
      expect(queries, hasLength(1));
      final record = queries.first;
      expect(record.sql, equals('SELECT * FROM monitors WHERE id = ?'));
      expect(record.bindings, equals(<Object?>[42]));
      expect(record.timeMs, equals(12));
      expect(record.connectionName, equals('primary'));
    });

    test('records carry the default connection name when not specified',
        () async {
      watcher.install();

      await EventDispatcher.instance.dispatch(QueryExecuted(
        sql: 'SELECT 1',
        bindings: const <dynamic>[],
        timeMs: 1,
      ));

      expect(TelescopeStore.recentQueries().single.connectionName,
          equals('default'));
    });

    test('install is idempotent (calling twice records each query once)',
        () async {
      watcher.install();
      watcher.install();

      await EventDispatcher.instance.dispatch(QueryExecuted(
        sql: 'SELECT 1',
        bindings: const <dynamic>[],
        timeMs: 1,
      ));

      expect(TelescopeStore.recentQueries(), hasLength(1));
    });

    test('uninstall is a no-op (does not throw, does not clear store)',
        () async {
      watcher.install();

      await EventDispatcher.instance.dispatch(QueryExecuted(
        sql: 'SELECT 2',
        bindings: const <dynamic>[],
        timeMs: 1,
      ));

      expect(() => watcher.uninstall(), returnsNormally);
      expect(TelescopeStore.recentQueries(), hasLength(1));
    });

    test('multiple QueryExecuted dispatches accumulate in order', () async {
      watcher.install();

      for (var i = 0; i < 3; i++) {
        await EventDispatcher.instance.dispatch(QueryExecuted(
          sql: 'SELECT $i',
          bindings: const <dynamic>[],
          timeMs: i,
        ));
      }

      final queries = TelescopeStore.recentQueries();
      expect(queries, hasLength(3));
      expect(queries.map((q) => q.sql).toList(),
          equals(<String>['SELECT 0', 'SELECT 1', 'SELECT 2']));
    });
  });
}
