import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttersdk_telescope/telescope.dart';
import 'package:logging/logging.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    // 1. Install core watcher (LogWatcher + VM extensions auto-registered).
    TelescopePlugin.install();
    // 2. Opt-in exception + dump watchers.
    TelescopePlugin.registerWatcher(ExceptionWatcher());
    TelescopePlugin.registerWatcher(DumpWatcher());
    // 3. Register the Dio HTTP adapter (stub; consumer wires the interceptor).
    TelescopePlugin.registerHttpAdapter(DioHttpAdapter());
    // 4. Route all package:logging levels into LogWatcher.
    Logger.root.level = Level.ALL;
  }
  final dio = Dio()..interceptors.add(_TelescopeDioInterceptor());
  runApp(App(dio: dio));
}

// ---------------------------------------------------------------------------
// Dio interceptor — canonical V1 pattern for routing Dio traffic into
// TelescopeStore via DioHttpAdapter.recordRequest.
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// App root
// ---------------------------------------------------------------------------

/// Public app root — exposed so widget tests can pump it directly.
class App extends StatelessWidget {
  const App({super.key, required this.dio});

  final Dio dio;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fluttersdk_telescope showroom',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: _Home(dio: dio),
    );
  }
}

// ---------------------------------------------------------------------------
// Home — StatefulWidget so clear() can setState to repopulate initialData.
// ---------------------------------------------------------------------------

class _Home extends StatefulWidget {
  const _Home({required this.dio});

  final Dio dio;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  void _onClear() {
    // setState triggers a rebuild; StreamBuilder initialData reads are
    // re-evaluated against the now-empty TelescopeStore buffers.
    setState(TelescopeStore.clear);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Telescope Showroom')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StatusBar(),
            const SizedBox(height: 12),
            _HttpSection(dio: widget.dio),
            const SizedBox(height: 12),
            const _LogSection(),
            const SizedBox(height: 12),
            const _ExceptionSection(),
            const SizedBox(height: 12),
            const _DumpSection(),
            const SizedBox(height: 12),
            _GlobalControls(onClear: _onClear),
            const SizedBox(height: 64),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status bar — live per-buffer counts.
// ---------------------------------------------------------------------------

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatusChip(
          label: 'HTTP',
          stream: TelescopeStore.onHttpRecord.map(
            (_) => TelescopeStore.recentHttp().length,
          ),
          initialCount: TelescopeStore.recentHttp().length,
        ),
        _StatusChip(
          label: 'Log',
          stream: TelescopeStore.onLogRecord.map(
            (_) => TelescopeStore.recentLogs().length,
          ),
          initialCount: TelescopeStore.recentLogs().length,
        ),
        _StatusChip(
          label: 'Exception',
          stream: TelescopeStore.onExceptionRecord.map(
            (_) => TelescopeStore.recentExceptions().length,
          ),
          initialCount: TelescopeStore.recentExceptions().length,
        ),
        _StatusChip(
          label: 'Dump',
          stream: TelescopeStore.onDumpRecord.map(
            (_) => TelescopeStore.recentDumps().length,
          ),
          initialCount: TelescopeStore.recentDumps().length,
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.stream,
    required this.initialCount,
  });

  final String label;
  final Stream<int> stream;
  final int initialCount;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: stream,
      initialData: initialCount,
      builder: (context, snap) => Chip(label: Text('$label ${snap.data}')),
    );
  }
}

// ---------------------------------------------------------------------------
// HTTP section
// ---------------------------------------------------------------------------

class _HttpSection extends StatelessWidget {
  const _HttpSection({required this.dio});

  final Dio dio;

  Future<void> _runDio(Future<dynamic> Function() call) async {
    try {
      await call();
    } catch (_) {
      // Network failures are expected for status/timeout buttons;
      // the interceptor records the attempt regardless.
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HTTP via DioHttpAdapter', style: titleStyle),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _runDio(
                    () => dio.get<dynamic>('https://httpbin.org/get'),
                  ),
                  child: const Text('GET /get'),
                ),
                FilledButton.tonal(
                  onPressed: () => _runDio(
                    () => dio.post<dynamic>(
                      'https://httpbin.org/post',
                      data: {'demo': true},
                    ),
                  ),
                  child: const Text('POST /post'),
                ),
                OutlinedButton(
                  onPressed: () => _runDio(
                    () => dio.get<dynamic>('https://httpbin.org/status/418'),
                  ),
                  child: const Text('GET /status/418'),
                ),
                OutlinedButton(
                  onPressed: () => _runDio(
                    () => dio.get<dynamic>(
                      'https://httpbin.org/delay/5',
                      options: Options(
                        receiveTimeout: const Duration(seconds: 2),
                      ),
                    ),
                  ),
                  child: const Text('GET /delay/5 (timeout)'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<HttpRequestRecord>(
              stream: TelescopeStore.onHttpRecord,
              initialData: null,
              builder: (context, _) {
                final records = TelescopeStore.recentHttp(limit: 5);
                if (records.isEmpty) {
                  return const Text(
                    'No HTTP requests yet.',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                return Column(
                  children: records.reversed.map((r) {
                    final url = r.url.length > 40
                        ? r.url.substring(0, 40)
                        : r.url;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${r.method} $url — ${r.statusCode} (${r.durationMs}ms)',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      trailing: r.isError
                          ? const Icon(
                              Icons.circle,
                              color: Colors.red,
                              size: 10,
                            )
                          : null,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Log section
// ---------------------------------------------------------------------------

class _LogSection extends StatelessWidget {
  const _LogSection();

  static final _log = Logger('demo');

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Logs via package:logging', style: titleStyle),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _log.info('info at ${DateTime.now()}'),
                  child: const Text('Logger.info'),
                ),
                FilledButton.tonal(
                  onPressed: () => _log.warning('warning at ${DateTime.now()}'),
                  child: const Text('Logger.warning'),
                ),
                OutlinedButton(
                  onPressed: () => _log.severe('severe at ${DateTime.now()}'),
                  child: const Text('Logger.severe'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<LogRecordEntry>(
              stream: TelescopeStore.onLogRecord,
              initialData: null,
              builder: (context, _) {
                final records = TelescopeStore.recentLogs(limit: 5);
                if (records.isEmpty) {
                  return const Text(
                    'No logs yet.',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                return Column(
                  children: records.reversed.map((r) {
                    final dotColor = switch (r.level.toLowerCase()) {
                      'info' => Colors.blue,
                      'warning' => Colors.amber,
                      'severe' => Colors.red,
                      _ => Colors.grey,
                    };
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.circle, color: dotColor, size: 10),
                      title: Text(
                        '${r.level}: ${r.message}',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exception section
// ---------------------------------------------------------------------------

class _ExceptionSection extends StatelessWidget {
  const _ExceptionSection();

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exceptions via ExceptionWatcher', style: titleStyle),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () {
                    // Async throw: routed via Flutter's uncaught-error pipeline.
                    Future<void>.microtask(() {
                      throw StateError('async demo at ${DateTime.now()}');
                    });
                  },
                  child: const Text('Async throw'),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    // Sync caught: reportError routes through FlutterError
                    // pipeline so ExceptionWatcher captures it without crashing.
                    try {
                      throw StateError('sync demo at ${DateTime.now()}');
                    } catch (e, st) {
                      FlutterError.reportError(
                        FlutterErrorDetails(exception: e, stack: st),
                      );
                    }
                  },
                  child: const Text('Sync throw (caught)'),
                ),
                OutlinedButton(
                  onPressed: () {
                    Future<void>.microtask(() {
                      throw Exception('custom: ${DateTime.now()}');
                    });
                  },
                  child: const Text('Custom error'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<ExceptionRecord>(
              stream: TelescopeStore.onExceptionRecord,
              initialData: null,
              builder: (context, _) {
                final records = TelescopeStore.recentExceptions(limit: 5);
                if (records.isEmpty) {
                  return const Text(
                    'No exceptions yet.',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                return Column(
                  children: records.reversed.map((r) {
                    final display = r.message.length > 60
                        ? r.message.substring(0, 60)
                        : r.message;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${r.exceptionType}: $display',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dump section
// ---------------------------------------------------------------------------

class _DumpSection extends StatelessWidget {
  const _DumpSection();

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dumps via DumpWatcher', style: titleStyle),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () => debugPrint('dump at ${DateTime.now()}'),
                  child: const Text('debugPrint single line'),
                ),
                FilledButton.tonal(
                  onPressed: () =>
                      debugPrint('line 1\nline 2\nline 3 at ${DateTime.now()}'),
                  child: const Text('debugPrint multiline'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<DumpRecord>(
              stream: TelescopeStore.onDumpRecord,
              initialData: null,
              builder: (context, _) {
                final records = TelescopeStore.recentDumps(limit: 5);
                if (records.isEmpty) {
                  return const Text(
                    'No dumps yet.',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                return Column(
                  children: records.reversed.map((r) {
                    final display = r.message.length > 80
                        ? r.message.substring(0, 80)
                        : r.message;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        display,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Global controls
// ---------------------------------------------------------------------------

class _GlobalControls extends StatelessWidget {
  const _GlobalControls({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Global controls', style: titleStyle),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear all buffers'),
                  onPressed: () {
                    onClear();
                    _flash(context, 'All buffers cleared.');
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('Pause recording'),
                  onPressed: () {
                    TelescopeStore.pause();
                    _flash(context, 'Recording paused.');
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Resume recording'),
                  onPressed: () {
                    TelescopeStore.resume();
                    _flash(context, 'Recording resumed.');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

void _flash(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
