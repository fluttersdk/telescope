@Tags(['magic'])
library;

// flutter_test re-exports its own `EventDispatcher` (for pointer events)
// via test_pointer.dart; hide it so the magic-side dispatcher resolves
// unambiguously below.
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import 'package:fluttersdk_telescope/src/records/gate_record.dart';
import 'package:fluttersdk_telescope/src/telescope_store.dart';
import 'package:magic/magic.dart';

/// Minimal concrete [Model] used as both the gate `user` and as the
/// `arguments` payload value inside gate watcher tests.
class _FakeModel extends Model {
  @override
  String get table => 'fakes';

  @override
  String get resource => 'fakes';
}

void main() {
  group('MagicGateWatcher', () {
    late MagicGateWatcher watcher;

    setUp(() {
      EventDispatcher.instance.clear();
      TelescopeStore.resetForTesting();
      watcher = MagicGateWatcher();
    });

    tearDown(() {
      EventDispatcher.instance.clear();
      TelescopeStore.resetForTesting();
    });

    test('name returns "magic_gate"', () {
      expect(watcher.name, 'magic_gate');
    });

    // -------------------------------------------------------------------------
    // (a) install subscribes to GateAccessChecked
    // -------------------------------------------------------------------------

    group('install() subscriptions', () {
      test('records GateAccessChecked into TelescopeStore', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(
          GateAccessChecked(ability: 'monitors.create', allowed: true),
        );

        final List<GateRecord> gates = TelescopeStore.recentGates();
        expect(gates, hasLength(1));
        expect(gates.first.ability, 'monitors.create');
        expect(gates.first.result, isTrue);
      });

      test('records denied checks (allowed: false maps to result: false)',
          () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(
          GateAccessChecked(ability: 'monitors.destroy', allowed: false),
        );

        final List<GateRecord> gates = TelescopeStore.recentGates();
        expect(gates, hasLength(1));
        expect(gates.first.result, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // (b) coercions: arguments wraps single dynamic into List, userId
    //     stringifies Model.id, user: null yields userId: null.
    // -------------------------------------------------------------------------

    group('payload coercions', () {
      test(
          'wraps single dynamic argument into List<Object?> with Model.toMap()',
          () async {
        watcher.install();
        final _FakeModel target = _FakeModel()..setAttribute('id', 42);

        await EventDispatcher.instance.dispatch(
          GateAccessChecked(
            ability: 'monitors.update',
            arguments: target,
            allowed: true,
          ),
        );

        final List<GateRecord> gates = TelescopeStore.recentGates();
        expect(gates, hasLength(1));
        expect(gates.first.arguments, hasLength(1));
        // Magic-side _coerceArg converts Model instances to their toMap()
        // shape so the resulting GateRecord stays JSON-encodable end to end.
        expect(gates.first.arguments.first, equals(target.toMap()));
      });

      test('wraps null argument into List<Object?> with a single null',
          () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(
          GateAccessChecked(ability: 'monitors.view', allowed: true),
        );

        final List<GateRecord> gates = TelescopeStore.recentGates();
        expect(gates, hasLength(1));
        expect(gates.first.arguments, <Object?>[null]);
      });

      test('stringifies Model.id into userId', () async {
        watcher.install();
        final _FakeModel user = _FakeModel()..setAttribute('id', 7);

        await EventDispatcher.instance.dispatch(
          GateAccessChecked(
            ability: 'monitors.create',
            allowed: true,
            user: user,
          ),
        );

        final List<GateRecord> gates = TelescopeStore.recentGates();
        expect(gates, hasLength(1));
        expect(gates.first.userId, '7');
      });

      test('userId is null when user is null', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(
          GateAccessChecked(ability: 'guest.peek', allowed: true),
        );

        final List<GateRecord> gates = TelescopeStore.recentGates();
        expect(gates, hasLength(1));
        expect(gates.first.userId, isNull);
      });

      test('userId is null when user.id is null', () async {
        watcher.install();
        final _FakeModel user = _FakeModel();

        await EventDispatcher.instance.dispatch(
          GateAccessChecked(
            ability: 'monitors.create',
            allowed: true,
            user: user,
          ),
        );

        final List<GateRecord> gates = TelescopeStore.recentGates();
        expect(gates, hasLength(1));
        expect(gates.first.userId, isNull);
      });
    });

    // -------------------------------------------------------------------------
    // (c) exclusions: never records into the event channel (gate-only).
    // -------------------------------------------------------------------------

    group('exclusions', () {
      test('records only into the gate channel, not the event channel',
          () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(
          GateAccessChecked(ability: 'x', allowed: true),
        );

        expect(TelescopeStore.recentEvents(), isEmpty);
        expect(TelescopeStore.recentGates(), hasLength(1));
      });
    });

    // -------------------------------------------------------------------------
    // (d) install is idempotent ; second call must not double-record
    // -------------------------------------------------------------------------

    group('idempotency', () {
      test('calling install() twice still records each gate check once',
          () async {
        watcher.install();
        watcher.install();

        await EventDispatcher.instance.dispatch(
          GateAccessChecked(ability: 'monitors.create', allowed: true),
        );

        expect(TelescopeStore.recentGates(), hasLength(1));
      });
    });

    // -------------------------------------------------------------------------
    // uninstall is a no-op (EventDispatcher has no per-listener removal).
    // -------------------------------------------------------------------------

    group('uninstall()', () {
      test('does not throw', () {
        watcher.install();
        expect(() => watcher.uninstall(), returnsNormally);
      });
    });
  });
}
