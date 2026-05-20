// Step 2.2 added eventsHandler / gatesHandler / dumpsHandler as
// @visibleForTesting public functions.
//
// Step 4.4 promotes the original 6 private handlers (_requestsHandler,
// _consoleHandler, _exceptionsHandler, _clearHandler, _pauseHandler,
// _resumeHandler) to @visibleForTesting public functions (requestsHandler,
// consoleHandler, exceptionsHandler, clearHandler, pauseHandler,
// resumeHandler) so they can be invoked directly here without spinning up a
// live VM Service. This is strictly a visibility change; no behavior was
// altered.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/extensions/register_telescope_extensions.dart';
import 'package:fluttersdk_telescope/src/records/dump_record.dart';
import 'package:fluttersdk_telescope/src/records/event_record.dart';
import 'package:fluttersdk_telescope/src/records/exception_record.dart';
import 'package:fluttersdk_telescope/src/records/gate_record.dart';
import 'package:fluttersdk_telescope/src/records/http_request_record.dart';
import 'package:fluttersdk_telescope/src/records/log_record_entry.dart';
import 'package:fluttersdk_telescope/src/records/magic_cache_record.dart';
import 'package:fluttersdk_telescope/src/records/query_record.dart';
import 'package:fluttersdk_telescope/src/telescope_store.dart';

void main() {
  setUp(() {
    TelescopeStore.resetForTesting();
    registerAllTelescopeExtensions();
  });

  // ---------------------------------------------------------------------------
  // Registration ; all 9 extensions must be discoverable
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
  // ext.telescope.events ; handler returns parseable JSON envelope
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
  // ext.telescope.gates ; handler returns parseable JSON envelope
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
  // ext.telescope.dumps ; handler returns parseable JSON envelope
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

  // ---------------------------------------------------------------------------
  // ext.telescope.requests ; backfill tests (Step 4.4)
  // ---------------------------------------------------------------------------

  group('ext.telescope.requests handler', () {
    test('returns a parseable JSON envelope with a records key', () async {
      final result = await requestsHandler('ext.telescope.requests', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      expect(decoded.containsKey('records'), isTrue);
    });

    test('returns records seeded via TelescopeStore.recordHttp', () async {
      TelescopeStore.recordHttp(
        HttpRequestRecord(
          url: 'https://api.example.com/monitors',
          method: 'GET',
          statusCode: 200,
          durationMs: 42,
          isError: false,
          timestamp: DateTime(2026, 1, 1),
        ),
      );

      final result = await requestsHandler('ext.telescope.requests', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final records = decoded['records'] as List<dynamic>;

      expect(records, hasLength(1));
      expect(records.first['url'], equals('https://api.example.com/monitors'));
    });

    test('honors limit param when present', () async {
      for (var i = 0; i < 5; i++) {
        TelescopeStore.recordHttp(
          HttpRequestRecord(
            url: 'https://api.example.com/monitors/$i',
            method: 'GET',
            statusCode: 200,
            durationMs: i,
            isError: false,
            timestamp: DateTime(2026, 1, 1, i),
          ),
        );
      }

      final result =
          await requestsHandler('ext.telescope.requests', {'limit': '2'});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final records = decoded['records'] as List<dynamic>;

      expect(records, hasLength(2));
    });

    test('returns empty list when store has no HTTP records', () async {
      final result = await requestsHandler('ext.telescope.requests', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final records = decoded['records'] as List<dynamic>;

      expect(records, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // ext.telescope.console ; backfill tests (Step 4.4)
  // ---------------------------------------------------------------------------

  group('ext.telescope.console handler', () {
    test('returns a parseable JSON envelope with a messages key', () async {
      final result = await consoleHandler('ext.telescope.console', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      expect(decoded.containsKey('messages'), isTrue);
    });

    test('returns records seeded via TelescopeStore.recordLog', () async {
      TelescopeStore.recordLog(
        LogRecordEntry(
          level: 'INFO',
          levelValue: 800,
          message: 'monitor check passed',
          loggerName: 'MonitorService',
          time: DateTime(2026, 1, 1),
        ),
      );

      final result = await consoleHandler('ext.telescope.console', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final messages = decoded['messages'] as List<dynamic>;

      expect(messages, hasLength(1));
      expect(messages.first['message'], equals('monitor check passed'));
    });

    test('honors limit param when present', () async {
      for (var i = 0; i < 6; i++) {
        TelescopeStore.recordLog(
          LogRecordEntry(
            level: 'INFO',
            levelValue: 800,
            message: 'log $i',
            loggerName: 'TestLogger',
            time: DateTime(2026, 1, 1, i),
          ),
        );
      }

      final result =
          await consoleHandler('ext.telescope.console', {'limit': '3'});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final messages = decoded['messages'] as List<dynamic>;

      expect(messages, hasLength(3));
    });

    test('honors level param and filters below minimum level', () async {
      TelescopeStore.recordLog(
        LogRecordEntry(
          level: 'fine',
          levelValue: 500,
          message: 'debug detail',
          loggerName: 'TestLogger',
          time: DateTime(2026, 1, 1),
        ),
      );
      TelescopeStore.recordLog(
        LogRecordEntry(
          level: 'warning',
          levelValue: 900,
          message: 'something is wrong',
          loggerName: 'TestLogger',
          time: DateTime(2026, 1, 1, 1),
        ),
      );

      final result = await consoleHandler(
        'ext.telescope.console',
        {'level': 'warning'},
      );
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final messages = decoded['messages'] as List<dynamic>;

      expect(messages, hasLength(1));
      expect(messages.first['message'], equals('something is wrong'));
    });

    test('returns empty list when store has no log records', () async {
      final result = await consoleHandler('ext.telescope.console', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final messages = decoded['messages'] as List<dynamic>;

      expect(messages, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // ext.telescope.exceptions ; backfill tests (Step 4.4)
  // ---------------------------------------------------------------------------

  group('ext.telescope.exceptions handler', () {
    test('returns a parseable JSON envelope with an exceptions key', () async {
      final result = await exceptionsHandler('ext.telescope.exceptions', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      expect(decoded.containsKey('exceptions'), isTrue);
    });

    test('returns records seeded via TelescopeStore.recordException', () async {
      TelescopeStore.recordException(
        ExceptionRecord(
          exceptionType: 'FormatException',
          message: 'invalid JSON',
          time: DateTime(2026, 1, 1),
        ),
      );

      final result = await exceptionsHandler('ext.telescope.exceptions', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final exceptions = decoded['exceptions'] as List<dynamic>;

      expect(exceptions, hasLength(1));
      expect(exceptions.first['exceptionType'], equals('FormatException'));
    });

    test('honors limit param when present', () async {
      for (var i = 0; i < 4; i++) {
        TelescopeStore.recordException(
          ExceptionRecord(
            exceptionType: 'Exception$i',
            message: 'error $i',
            time: DateTime(2026, 1, 1, i),
          ),
        );
      }

      final result =
          await exceptionsHandler('ext.telescope.exceptions', {'limit': '2'});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final exceptions = decoded['exceptions'] as List<dynamic>;

      expect(exceptions, hasLength(2));
    });

    test('returns empty list when store has no exception records', () async {
      final result = await exceptionsHandler('ext.telescope.exceptions', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final exceptions = decoded['exceptions'] as List<dynamic>;

      expect(exceptions, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // ext.telescope.clear ; backfill tests (Step 4.4)
  // ---------------------------------------------------------------------------

  group('ext.telescope.clear handler', () {
    test("returns JSON envelope with cleared: true", () async {
      final result = await clearHandler('ext.telescope.clear', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      expect(decoded['cleared'], isTrue);
    });

    test('empties all buffers after seeding records across types', () async {
      // Seed one record into each of the 3 original buffers.
      TelescopeStore.recordHttp(
        HttpRequestRecord(
          url: 'https://api.example.com',
          method: 'GET',
          statusCode: 200,
          durationMs: 1,
          isError: false,
          timestamp: DateTime(2026, 1, 1),
        ),
      );
      TelescopeStore.recordLog(
        LogRecordEntry(
          level: 'INFO',
          levelValue: 800,
          message: 'msg',
          loggerName: 'L',
          time: DateTime(2026, 1, 1),
        ),
      );
      TelescopeStore.recordException(
        ExceptionRecord(
          exceptionType: 'E',
          message: 'm',
          time: DateTime(2026, 1, 1),
        ),
      );
      // Seed one record into each of the 3 new buffers.
      TelescopeStore.recordEvent(
        EventRecord(
          eventType: 'Ev',
          payload: {},
          time: DateTime(2026, 1, 1),
        ),
      );
      TelescopeStore.recordGate(
        GateRecord(
          ability: 'ab',
          result: true,
          arguments: [],
          time: DateTime(2026, 1, 1),
        ),
      );
      TelescopeStore.recordDump(
        DumpRecord(message: 'dm', time: DateTime(2026, 1, 1)),
      );

      await clearHandler('ext.telescope.clear', {});

      // All 6 buffers must be empty after clear.
      expect(TelescopeStore.recentHttp(), isEmpty);
      expect(TelescopeStore.recentLogs(), isEmpty);
      expect(TelescopeStore.recentExceptions(), isEmpty);
      expect(TelescopeStore.recentEvents(), isEmpty);
      expect(TelescopeStore.recentGates(), isEmpty);
      expect(TelescopeStore.recentDumps(), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // ext.telescope.pause + ext.telescope.resume ; backfill tests (Step 4.4)
  // ---------------------------------------------------------------------------

  group('ext.telescope.pause handler', () {
    test("returns JSON envelope with paused: true", () async {
      final result = await pauseHandler('ext.telescope.pause', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      expect(decoded['paused'], isTrue);
    });
  });

  group('ext.telescope.resume handler', () {
    test("returns JSON envelope with resumed: true", () async {
      final result = await resumeHandler('ext.telescope.resume', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      expect(decoded['resumed'], isTrue);
    });
  });

  group('pause then resume recording lifecycle', () {
    test(
        'record before pause is absent after clear; '
        'record after resume is present in recentHttp', () async {
      // 1. Record a request before pausing; then clear so the buffer is empty.
      TelescopeStore.recordHttp(
        HttpRequestRecord(
          url: 'https://before-pause.example.com',
          method: 'GET',
          statusCode: 200,
          durationMs: 1,
          isError: false,
          timestamp: DateTime(2026, 1, 1),
        ),
      );
      await clearHandler('ext.telescope.clear', {});

      // 2. Pause, then try to record; record must be dropped.
      await pauseHandler('ext.telescope.pause', {});
      TelescopeStore.recordHttp(
        HttpRequestRecord(
          url: 'https://during-pause.example.com',
          method: 'GET',
          statusCode: 200,
          durationMs: 2,
          isError: false,
          timestamp: DateTime(2026, 1, 2),
        ),
      );
      expect(TelescopeStore.recentHttp(), isEmpty);

      // 3. Resume, then record; only the post-resume record must be present.
      await resumeHandler('ext.telescope.resume', {});
      TelescopeStore.recordHttp(
        HttpRequestRecord(
          url: 'https://after-resume.example.com',
          method: 'GET',
          statusCode: 200,
          durationMs: 3,
          isError: false,
          timestamp: DateTime(2026, 1, 3),
        ),
      );

      final records = TelescopeStore.recentHttp();
      expect(records, hasLength(1));
      expect(records.first.url, equals('https://after-resume.example.com'));
    });
  });

  // ---------------------------------------------------------------------------
  // ext.telescope.queries handler (alpha-3)
  // ---------------------------------------------------------------------------

  group('ext.telescope.queries handler', () {
    test('returns a parseable JSON envelope with a queries key', () async {
      final result = await queriesHandler('ext.telescope.queries', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      expect(decoded.containsKey('queries'), isTrue);
    });

    test('returns records seeded via TelescopeStore.recordQuery', () async {
      TelescopeStore.recordQuery(
        QueryRecord(
          sql: 'SELECT * FROM monitors WHERE id = ?',
          bindings: const <Object?>[42],
          timeMs: 12,
          time: DateTime(2026, 1, 1),
        ),
      );

      final result = await queriesHandler('ext.telescope.queries', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final records = decoded['queries'] as List<dynamic>;

      expect(records, hasLength(1));
      expect(
          records.first['sql'], equals('SELECT * FROM monitors WHERE id = ?'));
      expect(records.first['timeMs'], equals(12));
      expect(records.first['connectionName'], equals('default'));
    });

    test('honors limit param when present', () async {
      for (var i = 0; i < 5; i++) {
        TelescopeStore.recordQuery(
          QueryRecord(
            sql: 'SELECT $i',
            bindings: const <Object?>[],
            timeMs: i,
            time: DateTime(2026, 1, 1),
          ),
        );
      }

      final result =
          await queriesHandler('ext.telescope.queries', {'limit': '2'});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final records = decoded['queries'] as List<dynamic>;
      expect(records, hasLength(2));
    });

    test('returns empty list when store has no query records', () async {
      final result = await queriesHandler('ext.telescope.queries', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      expect(decoded['queries'], isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // ext.telescope.caches handler (alpha-3)
  // ---------------------------------------------------------------------------

  group('ext.telescope.caches handler', () {
    test('returns a parseable JSON envelope with a caches key', () async {
      final result = await cachesHandler('ext.telescope.caches', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      expect(decoded.containsKey('caches'), isTrue);
    });

    test('returns records seeded via TelescopeStore.recordMagicCache',
        () async {
      TelescopeStore.recordMagicCache(
        MagicCacheRecord(
          operation: 'put',
          key: 'demo-key',
          time: DateTime(2026, 1, 1),
          ttl: const Duration(minutes: 5),
        ),
      );

      final result = await cachesHandler('ext.telescope.caches', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final records = decoded['caches'] as List<dynamic>;

      expect(records, hasLength(1));
      expect(records.first['operation'], equals('put'));
      expect(records.first['key'], equals('demo-key'));
    });

    test('honors limit param when present', () async {
      for (final op in const <String>['put', 'hit', 'miss', 'forget']) {
        TelescopeStore.recordMagicCache(
          MagicCacheRecord(
            operation: op,
            key: 'k-$op',
            time: DateTime(2026, 1, 1),
          ),
        );
      }

      final result =
          await cachesHandler('ext.telescope.caches', {'limit': '2'});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      final records = decoded['caches'] as List<dynamic>;
      expect(records, hasLength(2));
    });

    test('returns empty list when store has no cache records', () async {
      final result = await cachesHandler('ext.telescope.caches', {});
      final decoded = jsonDecode(result.result!) as Map<String, dynamic>;
      expect(decoded['caches'], isEmpty);
    });
  });
}
