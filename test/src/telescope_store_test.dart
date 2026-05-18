import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/records/dump_record.dart';
import 'package:fluttersdk_telescope/src/records/event_record.dart';
import 'package:fluttersdk_telescope/src/records/exception_record.dart';
import 'package:fluttersdk_telescope/src/records/gate_record.dart';
import 'package:fluttersdk_telescope/src/records/http_request_record.dart';
import 'package:fluttersdk_telescope/src/records/log_record_entry.dart';
import 'package:fluttersdk_telescope/src/records/magic_cache_record.dart';
import 'package:fluttersdk_telescope/src/records/magic_model_record.dart';
import 'package:fluttersdk_telescope/src/telescope_store.dart';

void main() {
  // Statics persist across tests within the run; reset before every test.
  setUp(() {
    TelescopeStore.resetForTesting();
  });

  group('TelescopeStore default capacity', () {
    test('default cap is 500 (raised from prior 100)', () {
      // 1. Push 600 records into the http buffer with no setCapacity call.
      for (var i = 0; i < 600; i++) {
        TelescopeStore.recordHttp(_http(i));
      }

      final recent = TelescopeStore.recentHttp();

      // 2. Capacity bound is exactly 500; oldest 100 evicted FIFO.
      expect(recent.length, equals(500));
      expect(recent.first.method, equals('GET-100'));
      expect(recent.last.method, equals('GET-599'));
    });

    test('resetForTesting() restores cap to 500', () {
      TelescopeStore.setCapacity(7);
      TelescopeStore.resetForTesting();

      for (var i = 0; i < 600; i++) {
        TelescopeStore.recordHttp(_http(i));
      }

      expect(TelescopeStore.recentHttp().length, equals(500));
    });
  });

  group('TelescopeStore new buffers (events / gates / dumps)', () {
    // -------------------------------------------------------------------------
    // recordEvent + recentEvents + onEventRecord
    // -------------------------------------------------------------------------

    test('recordEvent appends and recentEvents returns in order', () {
      TelescopeStore.recordEvent(_event('A'));
      TelescopeStore.recordEvent(_event('B'));
      TelescopeStore.recordEvent(_event('C'));

      final recent = TelescopeStore.recentEvents();

      expect(recent.map((r) => r.eventType).toList(), equals(['A', 'B', 'C']));
    });

    test('events buffer enforces FIFO eviction at capacity', () {
      TelescopeStore.setCapacity(3);

      for (var i = 0; i < 5; i++) {
        TelescopeStore.recordEvent(_event('E$i'));
      }

      final recent = TelescopeStore.recentEvents();

      expect(recent.length, equals(3));
      expect(
        recent.map((r) => r.eventType).toList(),
        equals(['E2', 'E3', 'E4']),
      );
    });

    test('recentEvents respects limit (newest-last sublist)', () {
      for (var i = 0; i < 10; i++) {
        TelescopeStore.recordEvent(_event('E$i'));
      }

      final recent = TelescopeStore.recentEvents(limit: 3);

      expect(recent.length, equals(3));
      expect(
        recent.map((r) => r.eventType).toList(),
        equals(['E7', 'E8', 'E9']),
      );
    });

    test('onEventRecord stream emits on recordEvent', () async {
      final record = _event('Streamed');

      final future = expectLater(
        TelescopeStore.onEventRecord,
        emits(same(record)),
      );

      TelescopeStore.recordEvent(record);

      await future;
    });

    // -------------------------------------------------------------------------
    // recordGate + recentGates + onGateRecord
    // -------------------------------------------------------------------------

    test('recordGate appends and recentGates returns in order', () {
      TelescopeStore.recordGate(_gate('monitors.view', true));
      TelescopeStore.recordGate(_gate('monitors.destroy', false));

      final recent = TelescopeStore.recentGates();

      expect(recent.length, equals(2));
      expect(recent.first.ability, equals('monitors.view'));
      expect(recent.first.result, isTrue);
      expect(recent.last.result, isFalse);
    });

    test('gates buffer enforces FIFO eviction at capacity', () {
      TelescopeStore.setCapacity(2);

      TelescopeStore.recordGate(_gate('g1', true));
      TelescopeStore.recordGate(_gate('g2', true));
      TelescopeStore.recordGate(_gate('g3', false));

      final recent = TelescopeStore.recentGates();

      expect(recent.length, equals(2));
      expect(recent.map((r) => r.ability).toList(), equals(['g2', 'g3']));
    });

    test('recentGates respects limit', () {
      for (var i = 0; i < 6; i++) {
        TelescopeStore.recordGate(_gate('g$i', true));
      }

      final recent = TelescopeStore.recentGates(limit: 2);

      expect(recent.length, equals(2));
      expect(recent.map((r) => r.ability).toList(), equals(['g4', 'g5']));
    });

    test('onGateRecord stream emits on recordGate', () async {
      final record = _gate('streamed', true);

      final future = expectLater(
        TelescopeStore.onGateRecord,
        emits(same(record)),
      );

      TelescopeStore.recordGate(record);

      await future;
    });

    // -------------------------------------------------------------------------
    // recordDump + recentDumps + onDumpRecord
    // -------------------------------------------------------------------------

    test('recordDump appends and recentDumps returns in order', () {
      TelescopeStore.recordDump(_dump('hello'));
      TelescopeStore.recordDump(_dump('world'));

      final recent = TelescopeStore.recentDumps();

      expect(recent.map((r) => r.message).toList(), equals(['hello', 'world']));
    });

    test('dumps buffer enforces FIFO eviction at capacity', () {
      TelescopeStore.setCapacity(2);

      TelescopeStore.recordDump(_dump('d1'));
      TelescopeStore.recordDump(_dump('d2'));
      TelescopeStore.recordDump(_dump('d3'));
      TelescopeStore.recordDump(_dump('d4'));

      final recent = TelescopeStore.recentDumps();

      expect(recent.length, equals(2));
      expect(recent.map((r) => r.message).toList(), equals(['d3', 'd4']));
    });

    test('recentDumps respects limit', () {
      for (var i = 0; i < 8; i++) {
        TelescopeStore.recordDump(_dump('d$i'));
      }

      final recent = TelescopeStore.recentDumps(limit: 3);

      expect(recent.length, equals(3));
      expect(
        recent.map((r) => r.message).toList(),
        equals(['d5', 'd6', 'd7']),
      );
    });

    test('onDumpRecord stream emits on recordDump', () async {
      final record = _dump('streamed');

      final future = expectLater(
        TelescopeStore.onDumpRecord,
        emits(same(record)),
      );

      TelescopeStore.recordDump(record);

      await future;
    });
  });

  group('TelescopeStore pause/resume covers all 8 buffers', () {
    test('pause() suppresses every recordX call across all 8 buffers', () {
      TelescopeStore.pause();

      TelescopeStore.recordHttp(_http(0));
      TelescopeStore.recordLog(_log('info', 'm'));
      TelescopeStore.recordException(_exception('boom'));
      TelescopeStore.recordMagicModel(_model('User', 'created'));
      TelescopeStore.recordMagicCache(_cache('k1'));
      TelescopeStore.recordEvent(_event('E'));
      TelescopeStore.recordGate(_gate('g', true));
      TelescopeStore.recordDump(_dump('d'));

      expect(TelescopeStore.recentHttp(), isEmpty);
      expect(TelescopeStore.recentLogs(), isEmpty);
      expect(TelescopeStore.recentExceptions(), isEmpty);
      expect(TelescopeStore.recentModels(), isEmpty);
      expect(TelescopeStore.recentCaches(), isEmpty);
      expect(TelescopeStore.recentEvents(), isEmpty);
      expect(TelescopeStore.recentGates(), isEmpty);
      expect(TelescopeStore.recentDumps(), isEmpty);
    });

    test('resume() restores recording across all 8 buffers', () {
      TelescopeStore.pause();
      TelescopeStore.recordEvent(_event('dropped'));

      TelescopeStore.resume();
      TelescopeStore.recordEvent(_event('kept'));
      TelescopeStore.recordGate(_gate('g', true));
      TelescopeStore.recordDump(_dump('d'));

      expect(TelescopeStore.recentEvents().single.eventType, equals('kept'));
      expect(TelescopeStore.recentGates(), hasLength(1));
      expect(TelescopeStore.recentDumps(), hasLength(1));
    });
  });

  group('TelescopeStore clear() covers all 8 buffers', () {
    test('clear() empties every buffer in a single call', () {
      TelescopeStore.recordHttp(_http(0));
      TelescopeStore.recordLog(_log('info', 'm'));
      TelescopeStore.recordException(_exception('boom'));
      TelescopeStore.recordMagicModel(_model('User', 'created'));
      TelescopeStore.recordMagicCache(_cache('k1'));
      TelescopeStore.recordEvent(_event('E'));
      TelescopeStore.recordGate(_gate('g', true));
      TelescopeStore.recordDump(_dump('d'));

      TelescopeStore.clear();

      expect(TelescopeStore.recentHttp(), isEmpty);
      expect(TelescopeStore.recentLogs(), isEmpty);
      expect(TelescopeStore.recentExceptions(), isEmpty);
      expect(TelescopeStore.recentModels(), isEmpty);
      expect(TelescopeStore.recentCaches(), isEmpty);
      expect(TelescopeStore.recentEvents(), isEmpty);
      expect(TelescopeStore.recentGates(), isEmpty);
      expect(TelescopeStore.recentDumps(), isEmpty);
    });
  });

  group('TelescopeStore existing 5-buffer contract regression', () {
    // -------------------------------------------------------------------------
    // recordHttp / onHttpRecord
    // -------------------------------------------------------------------------

    test('recordHttp appends and onHttpRecord emits', () async {
      final record = _http(42);

      final future = expectLater(
        TelescopeStore.onHttpRecord,
        emits(same(record)),
      );

      TelescopeStore.recordHttp(record);

      expect(TelescopeStore.recentHttp().single, same(record));
      await future;
    });

    // -------------------------------------------------------------------------
    // recordLog / onLogRecord
    // -------------------------------------------------------------------------

    test('recordLog appends and onLogRecord emits', () async {
      final record = _log('info', 'hello');

      final future = expectLater(
        TelescopeStore.onLogRecord,
        emits(same(record)),
      );

      TelescopeStore.recordLog(record);

      expect(TelescopeStore.recentLogs().single, same(record));
      await future;
    });

    // -------------------------------------------------------------------------
    // recordException / onExceptionRecord
    // -------------------------------------------------------------------------

    test('recordException appends and onExceptionRecord emits', () async {
      final record = _exception('boom');

      final future = expectLater(
        TelescopeStore.onExceptionRecord,
        emits(same(record)),
      );

      TelescopeStore.recordException(record);

      expect(TelescopeStore.recentExceptions().single, same(record));
      await future;
    });

    // -------------------------------------------------------------------------
    // recordMagicModel / onModelRecord
    // -------------------------------------------------------------------------

    test('recordMagicModel appends and onModelRecord emits', () async {
      final record = _model('User', 'created');

      final future = expectLater(
        TelescopeStore.onModelRecord,
        emits(same(record)),
      );

      TelescopeStore.recordMagicModel(record);

      expect(TelescopeStore.recentModels().single, same(record));
      await future;
    });

    // -------------------------------------------------------------------------
    // recordMagicCache / onCacheRecord
    // -------------------------------------------------------------------------

    test('recordMagicCache appends and onCacheRecord emits', () async {
      final record = _cache('k1');

      final future = expectLater(
        TelescopeStore.onCacheRecord,
        emits(same(record)),
      );

      TelescopeStore.recordMagicCache(record);

      expect(TelescopeStore.recentCaches().single, same(record));
      await future;
    });

    // -------------------------------------------------------------------------
    // setCapacity contract preserved
    // -------------------------------------------------------------------------

    test('setCapacity bounds future inserts on the existing 5 buffers', () {
      TelescopeStore.setCapacity(2);

      for (var i = 0; i < 5; i++) {
        TelescopeStore.recordHttp(_http(i));
        TelescopeStore.recordLog(_log('info', 'm$i'));
        TelescopeStore.recordException(_exception('e$i'));
        TelescopeStore.recordMagicModel(_model('User', 'created'));
        TelescopeStore.recordMagicCache(_cache('k$i'));
      }

      expect(TelescopeStore.recentHttp(), hasLength(2));
      expect(TelescopeStore.recentLogs(), hasLength(2));
      expect(TelescopeStore.recentExceptions(), hasLength(2));
      expect(TelescopeStore.recentModels(), hasLength(2));
      expect(TelescopeStore.recentCaches(), hasLength(2));
    });
  });

  // ---------------------------------------------------------------------------
  // Backfill: boundary cases for the original 5-buffer surface.
  // ---------------------------------------------------------------------------

  group('TelescopeStore FIFO eviction on original 5 buffers (order check)', () {
    test('recordLog enforces FIFO: oldest entries evicted, newest retained',
        () {
      TelescopeStore.setCapacity(3);

      for (var i = 0; i < 6; i++) {
        TelescopeStore.recordLog(_log('info', 'msg$i'));
      }

      final recent = TelescopeStore.recentLogs();
      expect(recent.length, equals(3));
      expect(recent.first.message, equals('msg3'));
      expect(recent.last.message, equals('msg5'));
    });

    test(
        'recordException enforces FIFO: oldest entries evicted, newest retained',
        () {
      TelescopeStore.setCapacity(3);

      for (var i = 0; i < 5; i++) {
        TelescopeStore.recordException(_exception('err$i'));
      }

      final recent = TelescopeStore.recentExceptions();
      expect(recent.length, equals(3));
      expect(recent.first.message, equals('err2'));
      expect(recent.last.message, equals('err4'));
    });

    test(
        'recordMagicModel enforces FIFO: oldest entries evicted, newest retained',
        () {
      TelescopeStore.setCapacity(2);

      TelescopeStore.recordMagicModel(_model('User', 'created'));
      TelescopeStore.recordMagicModel(_model('Team', 'updated'));
      TelescopeStore.recordMagicModel(_model('Monitor', 'deleted'));

      final recent = TelescopeStore.recentModels();
      expect(recent.length, equals(2));
      expect(recent.first.modelClass, equals('Team'));
      expect(recent.last.modelClass, equals('Monitor'));
    });

    test(
        'recordMagicCache enforces FIFO: oldest entries evicted, newest retained',
        () {
      TelescopeStore.setCapacity(2);

      TelescopeStore.recordMagicCache(_cache('k1'));
      TelescopeStore.recordMagicCache(_cache('k2'));
      TelescopeStore.recordMagicCache(_cache('k3'));

      final recent = TelescopeStore.recentCaches();
      expect(recent.length, equals(2));
      expect(recent.first.key, equals('k2'));
      expect(recent.last.key, equals('k3'));
    });
  });

  group('TelescopeStore recentX(limit:) on original 5 buffers', () {
    test('recentHttp(limit:) returns at most limit items, newest-last', () {
      for (var i = 0; i < 10; i++) {
        TelescopeStore.recordHttp(_http(i));
      }

      final recent = TelescopeStore.recentHttp(limit: 4);
      expect(recent.length, equals(4));
      expect(recent.first.method, equals('GET-6'));
      expect(recent.last.method, equals('GET-9'));
    });

    test('recentLogs(limit:) returns at most limit items, newest-last', () {
      for (var i = 0; i < 8; i++) {
        TelescopeStore.recordLog(_log('info', 'msg$i'));
      }

      final recent = TelescopeStore.recentLogs(limit: 3);
      expect(recent.length, equals(3));
      expect(recent.first.message, equals('msg5'));
      expect(recent.last.message, equals('msg7'));
    });

    test('recentExceptions(limit:) returns at most limit items, newest-last',
        () {
      for (var i = 0; i < 6; i++) {
        TelescopeStore.recordException(_exception('err$i'));
      }

      final recent = TelescopeStore.recentExceptions(limit: 2);
      expect(recent.length, equals(2));
      expect(recent.first.message, equals('err4'));
      expect(recent.last.message, equals('err5'));
    });

    test('recentModels(limit:) returns at most limit items, newest-last', () {
      final classes = ['User', 'Team', 'Monitor', 'Metric', 'Incident'];
      for (final c in classes) {
        TelescopeStore.recordMagicModel(_model(c, 'created'));
      }

      final recent = TelescopeStore.recentModels(limit: 2);
      expect(recent.length, equals(2));
      expect(recent.first.modelClass, equals('Metric'));
      expect(recent.last.modelClass, equals('Incident'));
    });

    test('recentCaches(limit:) returns at most limit items, newest-last', () {
      for (var i = 0; i < 5; i++) {
        TelescopeStore.recordMagicCache(_cache('k$i'));
      }

      final recent = TelescopeStore.recentCaches(limit: 3);
      expect(recent.length, equals(3));
      expect(recent.first.key, equals('k2'));
      expect(recent.last.key, equals('k4'));
    });
  });

  group('TelescopeStore _meetsLevel boundary cases (via recentLogs minLevel:)',
      () {
    test('minLevel equal to record level passes (warning >= warning)', () {
      TelescopeStore.recordLog(_log('warning', 'at-boundary'));

      final recent = TelescopeStore.recentLogs(minLevel: 'warning');
      expect(recent, hasLength(1));
      expect(recent.single.message, equals('at-boundary'));
    });

    test('record level below minLevel is filtered out (info < warning)', () {
      TelescopeStore.recordLog(_log('info', 'too-low'));

      final recent = TelescopeStore.recentLogs(minLevel: 'warning');
      expect(recent, isEmpty);
    });

    test('_meetsLevel is case-insensitive (WARNING matches warning)', () {
      TelescopeStore.recordLog(_log('WARNING', 'upper'));
      TelescopeStore.recordLog(_log('info', 'lower'));

      final recent = TelescopeStore.recentLogs(minLevel: 'Warning');
      expect(recent, hasLength(1));
      expect(recent.single.message, equals('upper'));
    });

    test('severe passes when minLevel is warning (severe > warning)', () {
      TelescopeStore.recordLog(_log('severe', 'critical'));
      TelescopeStore.recordLog(_log('info', 'dropped'));

      final recent = TelescopeStore.recentLogs(minLevel: 'warning');
      expect(recent, hasLength(1));
      expect(recent.single.message, equals('critical'));
    });
  });

  group('TelescopeStore clear() does not close streams', () {
    test('onHttpRecord stream remains usable after clear()', () async {
      TelescopeStore.recordHttp(_http(1));
      TelescopeStore.clear();

      final record = _http(2);

      final future = expectLater(
        TelescopeStore.onHttpRecord,
        emits(same(record)),
      );

      TelescopeStore.recordHttp(record);
      expect(TelescopeStore.recentHttp().single, same(record));
      await future;
    });

    test('onLogRecord stream remains usable after clear()', () async {
      TelescopeStore.recordLog(_log('info', 'before'));
      TelescopeStore.clear();

      final record = _log('info', 'after');

      final future = expectLater(
        TelescopeStore.onLogRecord,
        emits(same(record)),
      );

      TelescopeStore.recordLog(record);
      expect(TelescopeStore.recentLogs().single, same(record));
      await future;
    });
  });

  group(
      'TelescopeStore setCapacity() does not trim existing entries retroactively',
      () {
    test(
        'reducing capacity leaves existing entries untouched until next record',
        () {
      // 1. Fill 5 entries at default capacity.
      for (var i = 0; i < 5; i++) {
        TelescopeStore.recordHttp(_http(i));
      }

      // 2. Lower capacity below current count; no eviction yet.
      TelescopeStore.setCapacity(3);

      expect(TelescopeStore.recentHttp(), hasLength(5));

      // 3. Next record triggers eviction down to the new cap.
      TelescopeStore.recordHttp(_http(5));

      final recent = TelescopeStore.recentHttp();
      expect(recent.length, equals(3));
      expect(recent.first.method, equals('GET-3'));
      expect(recent.last.method, equals('GET-5'));
    });
  });

  group('TelescopeStore resetForTesting() full contract', () {
    test('resetForTesting() clears all buffers', () {
      TelescopeStore.recordHttp(_http(0));
      TelescopeStore.recordLog(_log('info', 'm'));
      TelescopeStore.recordException(_exception('e'));
      TelescopeStore.recordMagicModel(_model('User', 'created'));
      TelescopeStore.recordMagicCache(_cache('k'));
      TelescopeStore.recordEvent(_event('E'));
      TelescopeStore.recordGate(_gate('g', true));
      TelescopeStore.recordDump(_dump('d'));

      TelescopeStore.resetForTesting();

      expect(TelescopeStore.recentHttp(), isEmpty);
      expect(TelescopeStore.recentLogs(), isEmpty);
      expect(TelescopeStore.recentExceptions(), isEmpty);
      expect(TelescopeStore.recentModels(), isEmpty);
      expect(TelescopeStore.recentCaches(), isEmpty);
      expect(TelescopeStore.recentEvents(), isEmpty);
      expect(TelescopeStore.recentGates(), isEmpty);
      expect(TelescopeStore.recentDumps(), isEmpty);
    });

    test('resetForTesting() resets capacity to 500', () {
      TelescopeStore.setCapacity(10);
      TelescopeStore.resetForTesting();

      // Push 501 records; only 500 should be retained.
      for (var i = 0; i < 501; i++) {
        TelescopeStore.recordHttp(_http(i));
      }

      expect(TelescopeStore.recentHttp(), hasLength(500));
    });

    test('resetForTesting() unsets pause so recording resumes immediately', () {
      TelescopeStore.pause();
      TelescopeStore.resetForTesting();

      TelescopeStore.recordHttp(_http(0));
      TelescopeStore.recordLog(_log('info', 'm'));

      expect(TelescopeStore.recentHttp(), hasLength(1));
      expect(TelescopeStore.recentLogs(), hasLength(1));
    });
  });
}

// ---------------------------------------------------------------------------
// Record fixture helpers (keep tests terse; each helper carries a unique
// distinguishing field so order assertions stay readable).
// ---------------------------------------------------------------------------

HttpRequestRecord _http(int n) => HttpRequestRecord(
      method: 'GET-$n',
      url: 'https://example.test/$n',
      statusCode: 200,
      durationMs: 1,
      isError: false,
      timestamp: DateTime(2026, 1, 1),
    );

LogRecordEntry _log(String level, String message) => LogRecordEntry(
      level: level,
      levelValue: 800,
      loggerName: 'test',
      message: message,
      time: DateTime(2026, 1, 1),
    );

ExceptionRecord _exception(String message) => ExceptionRecord(
      exceptionType: 'TestException',
      message: message,
      time: DateTime(2026, 1, 1),
    );

MagicModelRecord _model(String modelClass, String event) => MagicModelRecord(
      modelClass: modelClass,
      event: event,
      modelKey: '1',
      time: DateTime(2026, 1, 1),
    );

MagicCacheRecord _cache(String key) => MagicCacheRecord(
      operation: 'get',
      key: key,
      time: DateTime(2026, 1, 1),
    );

EventRecord _event(String eventType) => EventRecord(
      eventType: eventType,
      payload: const {},
      time: DateTime(2026, 1, 1),
    );

GateRecord _gate(String ability, bool result) => GateRecord(
      ability: ability,
      result: result,
      arguments: const [],
      time: DateTime(2026, 1, 1),
    );

DumpRecord _dump(String message) => DumpRecord(
      message: message,
      time: DateTime(2026, 1, 1),
    );
