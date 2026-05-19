import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

import 'internal/http_adapter_registry.dart';
import 'records/dump_record.dart';
import 'records/event_record.dart';
import 'records/exception_record.dart';
import 'records/gate_record.dart';
import 'records/http_request_record.dart';
import 'records/log_record_entry.dart';
import 'records/magic_cache_record.dart';
import 'records/magic_model_record.dart';
import 'records/query_record.dart';

/// In-memory ring-buffer store for the 9 V1+alpha-2 watcher record types.
///
/// Default cap: 500 entries per buffer (configurable via [setCapacity]).
/// Singleton accessed via static methods. Hot-restart resets the buffers
/// naturally (statics re-run their initializers).
class TelescopeStore {
  TelescopeStore._();

  static int _cap = 500;
  static bool _paused = false;

  static final Queue<HttpRequestRecord> _http = Queue<HttpRequestRecord>();
  static final Queue<LogRecordEntry> _logs = Queue<LogRecordEntry>();
  static final Queue<ExceptionRecord> _exceptions = Queue<ExceptionRecord>();
  static final Queue<MagicModelRecord> _models = Queue<MagicModelRecord>();
  static final Queue<MagicCacheRecord> _caches = Queue<MagicCacheRecord>();
  static final Queue<EventRecord> _events = Queue<EventRecord>();
  static final Queue<GateRecord> _gates = Queue<GateRecord>();
  static final Queue<DumpRecord> _dumps = Queue<DumpRecord>();
  static final Queue<QueryRecord> _queries = Queue<QueryRecord>();

  static final StreamController<HttpRequestRecord> _httpStream =
      StreamController<HttpRequestRecord>.broadcast();
  static final StreamController<LogRecordEntry> _logStream =
      StreamController<LogRecordEntry>.broadcast();
  static final StreamController<ExceptionRecord> _exceptionStream =
      StreamController<ExceptionRecord>.broadcast();
  static final StreamController<MagicModelRecord> _modelStream =
      StreamController<MagicModelRecord>.broadcast();
  static final StreamController<MagicCacheRecord> _cacheStream =
      StreamController<MagicCacheRecord>.broadcast();
  static final StreamController<EventRecord> _eventStream =
      StreamController<EventRecord>.broadcast();
  static final StreamController<GateRecord> _gateStream =
      StreamController<GateRecord>.broadcast();
  static final StreamController<DumpRecord> _dumpStream =
      StreamController<DumpRecord>.broadcast();
  static final StreamController<QueryRecord> _queryStream =
      StreamController<QueryRecord>.broadcast();

  /// Set per-buffer capacity (default 500).
  static void setCapacity(int cap) => _cap = cap;

  /// Pause all recording. Calls become no-ops until [resume].
  static void pause() => _paused = true;

  /// Resume recording.
  static void resume() => _paused = false;

  /// Clear all buffers.
  static void clear() {
    _http.clear();
    _logs.clear();
    _exceptions.clear();
    _models.clear();
    _caches.clear();
    _events.clear();
    _gates.clear();
    _dumps.clear();
    _queries.clear();
  }

  static void recordHttp(HttpRequestRecord r) {
    if (_paused) return;
    _http.addLast(r);
    while (_http.length > _cap) {
      _http.removeFirst();
    }
    _httpStream.add(r);
  }

  static void recordLog(LogRecordEntry r) {
    if (_paused) return;
    _logs.addLast(r);
    while (_logs.length > _cap) {
      _logs.removeFirst();
    }
    _logStream.add(r);
  }

  static void recordException(ExceptionRecord r) {
    if (_paused) return;
    _exceptions.addLast(r);
    while (_exceptions.length > _cap) {
      _exceptions.removeFirst();
    }
    _exceptionStream.add(r);
  }

  static void recordMagicModel(MagicModelRecord r) {
    if (_paused) return;
    _models.addLast(r);
    while (_models.length > _cap) {
      _models.removeFirst();
    }
    _modelStream.add(r);
  }

  static void recordMagicCache(MagicCacheRecord r) {
    if (_paused) return;
    _caches.addLast(r);
    while (_caches.length > _cap) {
      _caches.removeFirst();
    }
    _cacheStream.add(r);
  }

  static void recordEvent(EventRecord r) {
    if (_paused) return;
    _events.addLast(r);
    while (_events.length > _cap) {
      _events.removeFirst();
    }
    _eventStream.add(r);
  }

  static void recordGate(GateRecord r) {
    if (_paused) return;
    _gates.addLast(r);
    while (_gates.length > _cap) {
      _gates.removeFirst();
    }
    _gateStream.add(r);
  }

  static void recordDump(DumpRecord r) {
    if (_paused) return;
    _dumps.addLast(r);
    while (_dumps.length > _cap) {
      _dumps.removeFirst();
    }
    _dumpStream.add(r);
  }

  static void recordQuery(QueryRecord r) {
    if (_paused) return;
    _queries.addLast(r);
    while (_queries.length > _cap) {
      _queries.removeFirst();
    }
    _queryStream.add(r);
  }

  static List<HttpRequestRecord> recentHttp({int? limit}) =>
      _recent(_http, limit);
  static List<LogRecordEntry> recentLogs({int? limit, String? minLevel}) {
    final filtered = minLevel == null
        ? _logs.toList()
        : _logs.where((r) => _meetsLevel(r.level, minLevel)).toList();
    return _trim(filtered, limit);
  }

  static List<ExceptionRecord> recentExceptions({int? limit}) =>
      _recent(_exceptions, limit);
  static List<MagicModelRecord> recentModels({int? limit}) =>
      _recent(_models, limit);
  static List<MagicCacheRecord> recentCaches({int? limit}) =>
      _recent(_caches, limit);
  static List<EventRecord> recentEvents({int? limit}) =>
      _recent(_events, limit);
  static List<GateRecord> recentGates({int? limit}) => _recent(_gates, limit);
  static List<DumpRecord> recentDumps({int? limit}) => _recent(_dumps, limit);
  static List<QueryRecord> recentQueries({int? limit}) =>
      _recent(_queries, limit);

  static List<T> _recent<T>(Queue<T> q, int? limit) => _trim(q.toList(), limit);

  static List<T> _trim<T>(List<T> list, int? limit) {
    if (limit == null || list.length <= limit) return list;
    return list.sublist(list.length - limit);
  }

  static bool _meetsLevel(String actual, String min) {
    const order = [
      'finest',
      'finer',
      'fine',
      'config',
      'info',
      'warning',
      'severe',
      'shout',
    ];
    return order.indexOf(actual.toLowerCase()) >=
        order.indexOf(min.toLowerCase());
  }

  /// Total number of HTTP requests currently in flight across every
  /// registered [TelescopeHttpAdapter].
  ///
  /// Sums [TelescopeHttpAdapter.pendingCount] across the live adapter
  /// registry populated by [TelescopePlugin.registerHttpAdapter]. Returns 0
  /// when no adapter is registered OR when no registered adapter overrides
  /// the default [TelescopeHttpAdapter.pendingCount] (default body returns 0).
  ///
  /// Read-only sync getter; safe to call from poll loops (no locks, no IO).
  /// Consumed by `ext.dusk.wait_for_network_idle` to detect a network-idle
  /// window before yielding the next agent action.
  static int get pendingHttpCount {
    var total = 0;
    for (final adapter in httpAdapterRegistry) {
      total += adapter.pendingCount;
    }
    return total;
  }

  static Stream<HttpRequestRecord> get onHttpRecord => _httpStream.stream;
  static Stream<LogRecordEntry> get onLogRecord => _logStream.stream;
  static Stream<ExceptionRecord> get onExceptionRecord =>
      _exceptionStream.stream;
  static Stream<MagicModelRecord> get onModelRecord => _modelStream.stream;
  static Stream<MagicCacheRecord> get onCacheRecord => _cacheStream.stream;
  static Stream<EventRecord> get onEventRecord => _eventStream.stream;
  static Stream<GateRecord> get onGateRecord => _gateStream.stream;
  static Stream<DumpRecord> get onDumpRecord => _dumpStream.stream;
  static Stream<QueryRecord> get onQueryRecord => _queryStream.stream;

  /// Test-only reset.
  @visibleForTesting
  static void resetForTesting() {
    clear();
    _paused = false;
    _cap = 500;
    // The HTTP-adapter registry is a singleton list owned by
    // `internal/http_adapter_registry.dart`; clearing it here keeps test
    // isolation aligned with the existing buffer reset.
    httpAdapterRegistry.clear();
  }
}
