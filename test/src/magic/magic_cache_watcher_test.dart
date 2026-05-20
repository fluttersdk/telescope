// flutter_test re-exports its own `EventDispatcher` (for pointer events)
// via test_pointer.dart; hide it so the magic-side dispatcher resolves
// unambiguously below.
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import 'package:fluttersdk_telescope/src/telescope_store.dart';
import 'package:magic/magic.dart';

void main() {
  group('MagicCacheWatcher', () {
    late MagicCacheWatcher watcher;

    setUp(() {
      EventDispatcher.instance.clear();
      TelescopeStore.resetForTesting();
      watcher = MagicCacheWatcher();
    });

    tearDown(() {
      EventDispatcher.instance.clear();
      TelescopeStore.resetForTesting();
    });

    test('name returns "magic_cache"', () {
      expect(watcher.name, 'magic_cache');
    });

    test('install subscribes to CacheHit and records with op="hit"', () async {
      watcher.install();

      await EventDispatcher.instance.dispatch(CacheHit('demo-key', 'value'));

      final caches = TelescopeStore.recentCaches();
      expect(caches, hasLength(1));
      expect(caches.single.operation, equals('hit'));
      expect(caches.single.key, equals('demo-key'));
    });

    test('install subscribes to CacheMiss and records with op="miss"',
        () async {
      watcher.install();

      await EventDispatcher.instance.dispatch(CacheMiss('absent-key'));

      expect(TelescopeStore.recentCaches().single.operation, equals('miss'));
      expect(TelescopeStore.recentCaches().single.key, equals('absent-key'));
    });

    test('install subscribes to CachePut and records key + ttl', () async {
      watcher.install();

      await EventDispatcher.instance.dispatch(
          CachePut('demo-key', 'value', ttl: const Duration(minutes: 5)));

      final record = TelescopeStore.recentCaches().single;
      expect(record.operation, equals('put'));
      expect(record.key, equals('demo-key'));
      expect(record.ttl, equals(const Duration(minutes: 5)));
    });

    test('install subscribes to CacheForget and records with op="forget"',
        () async {
      watcher.install();

      await EventDispatcher.instance.dispatch(CacheForget('demo-key'));

      expect(TelescopeStore.recentCaches().single.operation, equals('forget'));
      expect(TelescopeStore.recentCaches().single.key, equals('demo-key'));
    });

    test(
        'install subscribes to CacheFlush and records with op="flush" + key="*"',
        () async {
      watcher.install();

      await EventDispatcher.instance.dispatch(CacheFlush());

      final record = TelescopeStore.recentCaches().single;
      expect(record.operation, equals('flush'));
      expect(record.key, equals('*'));
    });

    test('install is idempotent (calling twice records each event once)',
        () async {
      watcher.install();
      watcher.install();

      await EventDispatcher.instance.dispatch(CacheHit('k', 'v'));

      expect(TelescopeStore.recentCaches(), hasLength(1));
    });

    test('uninstall is a no-op (does not throw, does not clear store)',
        () async {
      watcher.install();
      await EventDispatcher.instance.dispatch(CacheHit('k', 'v'));

      expect(() => watcher.uninstall(), returnsNormally);
      expect(TelescopeStore.recentCaches(), hasLength(1));
    });

    test('full lifecycle: put + hit + miss + forget + flush all captured',
        () async {
      watcher.install();

      await EventDispatcher.instance
          .dispatch(CachePut('k', 'v', ttl: const Duration(seconds: 30)));
      await EventDispatcher.instance.dispatch(CacheHit('k', 'v'));
      await EventDispatcher.instance.dispatch(CacheMiss('absent'));
      await EventDispatcher.instance.dispatch(CacheForget('k'));
      await EventDispatcher.instance.dispatch(CacheFlush());

      final ops =
          TelescopeStore.recentCaches().map((r) => r.operation).toList();
      expect(ops, equals(<String>['put', 'hit', 'miss', 'forget', 'flush']));
    });
  });
}
