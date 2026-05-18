import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/extensions/register_telescope_extensions.dart';
import 'package:fluttersdk_telescope/src/records/dump_record.dart';
import 'package:fluttersdk_telescope/src/records/event_record.dart';
import 'package:fluttersdk_telescope/src/records/gate_record.dart';
import 'package:fluttersdk_telescope/src/telescope_store.dart';

void main() {
  setUp(() {
    TelescopeStore.resetForTesting();
    registerAllTelescopeExtensions();
  });

  // ---------------------------------------------------------------------------
  // Registration — all 9 extensions must be discoverable
  // ---------------------------------------------------------------------------

  group('registerAllTelescopeExtensions()', () {
    test('registers ext.telescope.events without throwing', () {
      // registerAllTelescopeExtensions is idempotent; if it were not registered
      // the lookup below would fail or the invocation test would error.
      expect(() => registerAllTelescopeExtensions(), returnsNormally);
    });

    test('registers ext.telescope.gates without throwing', () {
      expect(() => registerAllTelescopeExtensions(), returnsNormally);
    });

    test('registers ext.telescope.dumps without throwing', () {
      expect(() => registerAllTelescopeExtensions(), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // ext.telescope.events — handler returns parseable JSON envelope
  // ---------------------------------------------------------------------------

  group('ext.telescope.events handler', () {
    test('returns a parseable JSON envelope with an events key', () async {
      final result = await eventsHandler('ext.telescope.events', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      expect(decoded.containsKey('events'), isTrue);
    });

    test('returns records seeded via TelescopeStore.recordEvent', () async {
      TelescopeStore.recordEvent(
        EventRecord(
          eventType: 'UserLoggedIn',
          payload: {'userId': '42'},
          time: DateTime(2026, 1, 1),
        ),
      );

      final result = await eventsHandler('ext.telescope.events', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final events = decoded['events'] as List<dynamic>;

      expect(events, hasLength(1));
      expect(events.first['eventType'], equals('UserLoggedIn'));
    });

    test('honors limit param when present', () async {
      for (var i = 0; i < 5; i++) {
        TelescopeStore.recordEvent(
          EventRecord(
            eventType: 'Event$i',
            payload: {},
            time: DateTime(2026, 1, 1, i),
          ),
        );
      }

      final result =
          await eventsHandler('ext.telescope.events', {'limit': '3'});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final events = decoded['events'] as List<dynamic>;

      expect(events, hasLength(3));
    });

    test('returns all records when limit param is absent', () async {
      for (var i = 0; i < 4; i++) {
        TelescopeStore.recordEvent(
          EventRecord(
            eventType: 'Event$i',
            payload: {},
            time: DateTime(2026, 1, 1, i),
          ),
        );
      }

      final result = await eventsHandler('ext.telescope.events', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final events = decoded['events'] as List<dynamic>;

      expect(events, hasLength(4));
    });

    test('returns empty list when store has no event records', () async {
      final result = await eventsHandler('ext.telescope.events', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final events = decoded['events'] as List<dynamic>;

      expect(events, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // ext.telescope.gates — handler returns parseable JSON envelope
  // ---------------------------------------------------------------------------

  group('ext.telescope.gates handler', () {
    test('returns a parseable JSON envelope with a gates key', () async {
      final result = await gatesHandler('ext.telescope.gates', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      expect(decoded.containsKey('gates'), isTrue);
    });

    test('returns records seeded via TelescopeStore.recordGate', () async {
      TelescopeStore.recordGate(
        GateRecord(
          ability: 'monitors.destroy',
          result: true,
          arguments: [],
          time: DateTime(2026, 1, 1),
        ),
      );

      final result = await gatesHandler('ext.telescope.gates', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final gates = decoded['gates'] as List<dynamic>;

      expect(gates, hasLength(1));
      expect(gates.first['ability'], equals('monitors.destroy'));
    });

    test('honors limit param when present', () async {
      for (var i = 0; i < 5; i++) {
        TelescopeStore.recordGate(
          GateRecord(
            ability: 'ability$i',
            result: i.isEven,
            arguments: [],
            time: DateTime(2026, 1, 1, i),
          ),
        );
      }

      final result = await gatesHandler('ext.telescope.gates', {'limit': '2'});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final gates = decoded['gates'] as List<dynamic>;

      expect(gates, hasLength(2));
    });

    test('returns all records when limit param is absent', () async {
      for (var i = 0; i < 3; i++) {
        TelescopeStore.recordGate(
          GateRecord(
            ability: 'ability$i',
            result: true,
            arguments: [],
            time: DateTime(2026, 1, 1, i),
          ),
        );
      }

      final result = await gatesHandler('ext.telescope.gates', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final gates = decoded['gates'] as List<dynamic>;

      expect(gates, hasLength(3));
    });

    test('returns empty list when store has no gate records', () async {
      final result = await gatesHandler('ext.telescope.gates', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final gates = decoded['gates'] as List<dynamic>;

      expect(gates, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // ext.telescope.dumps — handler returns parseable JSON envelope
  // ---------------------------------------------------------------------------

  group('ext.telescope.dumps handler', () {
    test('returns a parseable JSON envelope with a dumps key', () async {
      final result = await dumpsHandler('ext.telescope.dumps', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      expect(decoded.containsKey('dumps'), isTrue);
    });

    test('returns records seeded via TelescopeStore.recordDump', () async {
      TelescopeStore.recordDump(
        DumpRecord(
          message: 'hello telescope',
          time: DateTime(2026, 1, 1),
        ),
      );

      final result = await dumpsHandler('ext.telescope.dumps', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final dumps = decoded['dumps'] as List<dynamic>;

      expect(dumps, hasLength(1));
      expect(dumps.first['message'], equals('hello telescope'));
    });

    test('honors limit param when present', () async {
      for (var i = 0; i < 6; i++) {
        TelescopeStore.recordDump(
          DumpRecord(
            message: 'dump $i',
            time: DateTime(2026, 1, 1, i),
          ),
        );
      }

      final result = await dumpsHandler('ext.telescope.dumps', {'limit': '4'});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final dumps = decoded['dumps'] as List<dynamic>;

      expect(dumps, hasLength(4));
    });

    test('returns all records when limit param is absent', () async {
      for (var i = 0; i < 5; i++) {
        TelescopeStore.recordDump(
          DumpRecord(
            message: 'dump $i',
            time: DateTime(2026, 1, 1, i),
          ),
        );
      }

      final result = await dumpsHandler('ext.telescope.dumps', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final dumps = decoded['dumps'] as List<dynamic>;

      expect(dumps, hasLength(5));
    });

    test('returns empty list when store has no dump records', () async {
      final result = await dumpsHandler('ext.telescope.dumps', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final dumps = decoded['dumps'] as List<dynamic>;

      expect(dumps, isEmpty);
    });
  });
}
