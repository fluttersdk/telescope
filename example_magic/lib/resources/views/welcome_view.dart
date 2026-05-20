import 'package:flutter/material.dart';
import 'package:fluttersdk_telescope/telescope.dart';
import 'package:logging/logging.dart' as logging;
// Magic re-exports `package:dio` types (Dio, Interceptor, RequestOptions,
// Response, DioException), so a single magic import covers both Magic-stack
// and native-Dio paths in this demo.
import 'package:magic/magic.dart';

/// Telescope full demo screen ; one button per capture surface, grouped by
/// NATIVE Flutter path vs MAGIC-stack path. Includes the two alpha-3
/// additions (Magic DB QueryExecuted + Magic Cache events).
class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  late final Dio _dio = Dio()..interceptors.add(_TelescopeDioInterceptor());

  // ----- NATIVE -----
  Future<void> _nativeDio() async {
    try {
      await _dio.get<dynamic>('https://httpbin.org/get?source=native');
    } catch (_) {}
    Magic.snackbar('telescope', 'Dio.get dispatched (native)');
  }

  void _nativeLogger() {
    logging.Logger('native').warning('native warning at ${DateTime.now()}');
    Magic.snackbar('telescope', 'Logger.warning emitted (native)');
  }

  void _nativeException() {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError('native exception at ${DateTime.now()}'),
        library: 'telescope demo',
      ),
    );
    Magic.snackbar('telescope', 'FlutterError.reportError emitted (native)');
  }

  void _nativeDump() {
    debugPrint('native debugPrint at ${DateTime.now()}');
    Magic.snackbar('telescope', 'debugPrint emitted (native)');
  }

  // ----- MAGIC -----
  Future<void> _magicHttp() async {
    try {
      await Http.get('https://httpbin.org/get?source=magic');
    } catch (_) {}
    Magic.snackbar('telescope', 'Magic.Http.get dispatched');
  }

  void _magicLog() {
    Log.info('magic Log.info at ${DateTime.now()}');
    Magic.snackbar('telescope', 'Magic.Log.info emitted');
  }

  Future<void> _magicModelLifecycle() async {
    final model = _DemoModel()
      ..setAttribute('id', 'demo-${DateTime.now().millisecondsSinceEpoch}');
    await Event.dispatch(ModelCreated(model));
    await Event.dispatch(ModelSaved(model));
    await Event.dispatch(ModelDeleted(model));
    Magic.snackbar('telescope', 'ModelCreated/Saved/Deleted x3 dispatched');
  }

  void _magicGate() {
    final allowed = Gate.allows('demo.allow');
    Magic.snackbar('telescope', 'Gate.allows = $allowed');
  }

  Future<void> _magicEvent() async {
    await Event.dispatch(AuthFailed(const <String, dynamic>{}));
    Magic.snackbar('telescope', 'AuthFailed dispatched');
  }

  // ----- ALPHA-3 (DB query + Cache) -----
  Future<void> _magicCacheLifecycle() async {
    // Real Cache facade calls: dispatch CachePut + CacheHit + CacheMiss +
    // CacheForget via CacheManager. MagicCacheWatcher records each as a
    // MagicCacheRecord with the matching op tag.
    try {
      await Cache.put(
        'demo-key',
        'demo-value',
        ttl: const Duration(minutes: 5),
      );
      Cache.get('demo-key'); // hit
      Cache.get('absent-key'); // miss
      await Cache.forget('demo-key');
      Magic.snackbar(
        'telescope',
        'Cache put + get(hit) + get(miss) + forget dispatched',
      );
    } catch (e) {
      // File-driver cache on web may throw; fall back to synthetic dispatch
      // so the demo still exercises the watcher capture path.
      await Event.dispatch(
        CachePut('demo-key', 'demo-value', ttl: const Duration(minutes: 5)),
      );
      await Event.dispatch(CacheHit('demo-key', 'demo-value'));
      await Event.dispatch(CacheMiss('absent-key'));
      await Event.dispatch(CacheForget('demo-key'));
      Magic.snackbar(
        'telescope',
        'Cache events dispatched synthetically (driver: $e)',
      );
    }
  }

  Future<void> _magicDbQuery() async {
    // Synthetic dispatch (no real DB schema needed). MagicQueryWatcher
    // subscribes to QueryExecuted and records into TelescopeStore.
    await Event.dispatch(
      QueryExecuted(
        sql: 'SELECT * FROM demos WHERE id = ?',
        bindings: [42],
        timeMs: 12,
      ),
    );
    Magic.snackbar('telescope', 'QueryExecuted dispatched');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('fluttersdk_telescope demo')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          const Text(
            'CLI: `dart run artisan telescope:tail` / `telescope:requests`. '
            'For MCP-only surfaces (exceptions/dumps/models/gates/events/'
            'queries/caches), use `tinker --eval "TelescopeStore.recentX()"`.',
          ),
          const SizedBox(height: 16),
          _SectionHeader(
            title: 'Native (vanilla Flutter)',
            color: Colors.indigo,
          ),
          FilledButton(
            onPressed: _nativeDio,
            child: const Text('Dio.get  →  telescope:requests'),
          ),
          FilledButton(
            onPressed: _nativeLogger,
            child: const Text('Logger.warning  →  telescope:tail'),
          ),
          FilledButton(
            onPressed: _nativeException,
            child: const Text(
              'FlutterError.reportError  →  telescope_exceptions',
            ),
          ),
          FilledButton(
            onPressed: _nativeDump,
            child: const Text('debugPrint  →  telescope_dumps'),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Magic stack (facade + adapter)',
            color: Colors.deepPurple,
          ),
          FilledButton(
            onPressed: _magicHttp,
            child: const Text(
              'Magic.Http.get  →  telescope:requests (MagicHttpFacadeAdapter)',
            ),
          ),
          FilledButton(
            onPressed: _magicLog,
            child: const Text(
              'Magic.Log.info  →  telescope:tail (via Magic LogManager)',
            ),
          ),
          FilledButton(
            onPressed: _magicModelLifecycle,
            child: const Text(
              'Model x3 (created/saved/deleted)  →  MagicModelWatcher',
            ),
          ),
          FilledButton(
            onPressed: _magicGate,
            child: const Text(
              'Gate.allows  →  telescope_gates (MagicGateWatcher)',
            ),
          ),
          FilledButton(
            onPressed: _magicEvent,
            child: const Text(
              'AuthFailed event  →  telescope_events (MagicEventWatcher)',
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Alpha-3 (DB query + Cache lifecycle)',
            color: Colors.teal,
          ),
          FilledButton(
            onPressed: _magicCacheLifecycle,
            child: const Text(
              'Cache lifecycle (put+hit+miss+forget)  →  telescope_caches',
            ),
          ),
          FilledButton(
            onPressed: _magicDbQuery,
            child: const Text(
              'DB QueryExecuted  →  telescope_queries (MagicQueryWatcher)',
            ),
          ),
        ],
      ),
    ),
  );
}

/// Bridges Dio's interceptor callbacks to telescope's static HTTP record API.
class _TelescopeDioInterceptor extends Interceptor {
  final Map<int, Stopwatch> _watches = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _watches[options.hashCode] = Stopwatch()..start();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _record(
      response.requestOptions,
      statusCode: response.statusCode ?? 0,
      error: null,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _record(
      err.requestOptions,
      statusCode: err.response?.statusCode ?? 0,
      error: err.message ?? err.toString(),
    );
    handler.next(err);
  }

  void _record(
    RequestOptions options, {
    required int statusCode,
    required String? error,
  }) {
    final watch = _watches.remove(options.hashCode);
    DioHttpAdapter.recordRequest(
      url: options.uri.toString(),
      method: options.method,
      statusCode: statusCode,
      durationMs: watch?.elapsedMilliseconds ?? 0,
      isError: error != null || statusCode >= 400,
      requestHeaders: <String, String>{
        for (final e in options.headers.entries) e.key: e.value.toString(),
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.color});
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4, top: 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _DemoModel extends Model with HasTimestamps, InteractsWithPersistence {
  @override
  String get table => 'demos';

  @override
  String get resource => 'demos';

  @override
  List<String> get fillable => const ['id', 'name'];
}
