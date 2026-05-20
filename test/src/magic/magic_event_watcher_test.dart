@Tags(['magic'])
library;

// flutter_test re-exports its own `EventDispatcher` (for pointer events)
// via test_pointer.dart; hide it so the magic-side dispatcher resolves
// unambiguously below.
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import 'package:fluttersdk_telescope/src/records/event_record.dart';
import 'package:fluttersdk_telescope/src/telescope_store.dart';
import 'package:magic/magic.dart';

/// Minimal concrete [Model] for watcher tests (no persistence surface).
class _FakeModel extends Model {
  @override
  String get table => 'fakes';

  @override
  String get resource => 'fakes';
}

/// Minimal [Authenticatable] for auth event construction.
class _FakeAuthUser extends _FakeModel with Authenticatable {
  _FakeAuthUser({required String id}) {
    setAttribute('id', id);
  }
}

void main() {
  group('MagicEventWatcher', () {
    late MagicEventWatcher watcher;

    setUp(() {
      EventDispatcher.instance.clear();
      TelescopeStore.resetForTesting();
      watcher = MagicEventWatcher();
    });

    tearDown(() {
      EventDispatcher.instance.clear();
      TelescopeStore.resetForTesting();
    });

    test('name returns "magic_event"', () {
      expect(watcher.name, 'magic_event');
    });

    // -------------------------------------------------------------------------
    // (a) install subscribes to the expected event types only
    // -------------------------------------------------------------------------

    group('install() subscriptions', () {
      test('records AuthLogin into TelescopeStore', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(
          AuthLogin(_FakeAuthUser(id: 'u-1')),
        );

        final List<EventRecord> events = TelescopeStore.recentEvents();
        expect(events, hasLength(1));
        expect(events.first.eventType, 'AuthLogin');
        expect(events.first.payload, const <String, dynamic>{});
      });

      test('records AuthLogout into TelescopeStore', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(
          AuthLogout(_FakeAuthUser(id: 'u-2')),
        );

        final List<EventRecord> events = TelescopeStore.recentEvents();
        expect(events, hasLength(1));
        expect(events.first.eventType, 'AuthLogout');
      });

      test('records AuthFailed into TelescopeStore', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(
          AuthFailed(const <String, dynamic>{'email': 'x@y.z'}),
        );

        final List<EventRecord> events = TelescopeStore.recentEvents();
        expect(events, hasLength(1));
        expect(events.first.eventType, 'AuthFailed');
      });

      test('records AuthRestored into TelescopeStore', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(
          AuthRestored(_FakeAuthUser(id: 'u-3')),
        );

        final List<EventRecord> events = TelescopeStore.recentEvents();
        expect(events, hasLength(1));
        expect(events.first.eventType, 'AuthRestored');
      });

      test('records DatabaseConnected into TelescopeStore', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(DatabaseConnected('sqlite'));

        final List<EventRecord> events = TelescopeStore.recentEvents();
        expect(events, hasLength(1));
        expect(events.first.eventType, 'DatabaseConnected');
      });

      test('records GateAbilityDefined into TelescopeStore', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(
          GateAbilityDefined('monitors.create'),
        );

        final List<EventRecord> events = TelescopeStore.recentEvents();
        expect(events, hasLength(1));
        expect(events.first.eventType, 'GateAbilityDefined');
      });

      test('records GateBeforeRegistered into TelescopeStore', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(GateBeforeRegistered());

        final List<EventRecord> events = TelescopeStore.recentEvents();
        expect(events, hasLength(1));
        expect(events.first.eventType, 'GateBeforeRegistered');
      });

      test('payload is the empty map for every recorded event (alpha-2 scope)',
          () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(
          AuthLogin(_FakeAuthUser(id: 'u-1')),
        );
        await EventDispatcher.instance.dispatch(DatabaseConnected('sqlite'));

        final List<EventRecord> events = TelescopeStore.recentEvents();
        expect(events, hasLength(2));
        for (final EventRecord e in events) {
          expect(e.payload, const <String, dynamic>{});
        }
      });
    });

    // -------------------------------------------------------------------------
    // (c) does NOT subscribe to model lifecycle / gate events (no double-record)
    // -------------------------------------------------------------------------

    group('exclusions', () {
      test('does NOT subscribe to ModelCreated', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(ModelCreated(_FakeModel()));

        expect(TelescopeStore.recentEvents(), isEmpty);
      });

      test('does NOT subscribe to ModelSaved', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(ModelSaved(_FakeModel()));

        expect(TelescopeStore.recentEvents(), isEmpty);
      });

      test('does NOT subscribe to ModelDeleted', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(ModelDeleted(_FakeModel()));

        expect(TelescopeStore.recentEvents(), isEmpty);
      });

      test('does NOT subscribe to GateAccessChecked (owned by GateWatcher)',
          () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(
          GateAccessChecked(ability: 'x', allowed: true),
        );

        expect(TelescopeStore.recentEvents(), isEmpty);
      });

      test('does NOT subscribe to GateAccessDenied', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(GateAccessDenied(ability: 'x'));

        expect(TelescopeStore.recentEvents(), isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // (d) install is idempotent ; second call must not double-record
    // -------------------------------------------------------------------------

    group('idempotency', () {
      test('calling install() twice still records each event once', () async {
        watcher.install();
        watcher.install();

        await EventDispatcher.instance.dispatch(
          AuthLogin(_FakeAuthUser(id: 'u-1')),
        );

        expect(TelescopeStore.recentEvents(), hasLength(1));
      });
    });

    // -------------------------------------------------------------------------
    // uninstall is a no-op (mirrors MagicModelWatcher; EventDispatcher has
    // no per-listener removal API). Asserting it does not throw is enough.
    // -------------------------------------------------------------------------

    group('uninstall()', () {
      test('does not throw', () {
        watcher.install();
        expect(() => watcher.uninstall(), returnsNormally);
      });
    });
  });
}
