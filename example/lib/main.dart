import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:fluttersdk_telescope/telescope.dart';
import 'package:logging/logging.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    TelescopePlugin.install();
    TelescopePlugin.registerWatcher(ExceptionWatcher());
    TelescopePlugin.registerWatcher(DumpWatcher());
    // package:logging emits to LogWatcher (auto-installed by TelescopePlugin).
    // Opt the root logger into ALL so demo Logger.warning calls flow through.
    Logger.root.level = Level.ALL;
  }

  // Dio + telescope HTTP capture wired manually via an interceptor (the
  // shipped DioHttpAdapter.install() is a V1 stub; consumers plug an
  // interceptor and call DioHttpAdapter.recordRequest from inside it).
  final dio = Dio()..interceptors.add(_TelescopeDioInterceptor());

  runApp(_App(dio: dio));
}

/// Bridges Dio request/response/error callbacks into telescope's HTTP store.
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

class _App extends StatelessWidget {
  const _App({required this.dio});
  final Dio dio;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'fluttersdk_telescope demo',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
    home: _Home(dio: dio),
  );
}

class _Home extends StatelessWidget {
  const _Home({required this.dio});
  final Dio dio;

  Future<void> _http(BuildContext context) async {
    try {
      await dio.get<dynamic>('https://httpbin.org/get');
    } catch (_) {
      // Captured by the interceptor regardless of network outcome.
    }
    _flash(context, 'HTTP GET dispatched; check telescope:requests');
  }

  void _log(BuildContext context) {
    Logger('demo').warning('warning at ${DateTime.now()}');
    _flash(context, 'Warning logged; check telescope:tail');
  }

  void _throw(BuildContext context) {
    // Async throw routes through PlatformDispatcher.onError where
    // ExceptionWatcher captures it; a sync throw would crash the button.
    Future<void>.microtask(() {
      throw StateError('demo exception at ${DateTime.now()}');
    });
    _flash(context, 'Exception thrown; check telescope_exceptions (MCP)');
  }

  void _dump(BuildContext context) {
    debugPrint('debugPrint at ${DateTime.now()}');
    _flash(context, 'debugPrint emitted; check telescope_dumps (MCP)');
  }

  void _flash(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('fluttersdk_telescope demo')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const Text(
            'Each button triggers one telescope capture surface. After '
            'tapping, pull the matching artisan CLI command or MCP tool.',
          ),
          FilledButton(
            onPressed: () => _http(context),
            child: const Text('Dio HTTP GET  →  telescope:requests'),
          ),
          FilledButton(
            onPressed: () => _log(context),
            child: const Text('Logger.warning  →  telescope:tail'),
          ),
          FilledButton(
            onPressed: () => _throw(context),
            child: const Text('throw (async)  →  telescope_exceptions (MCP)'),
          ),
          FilledButton(
            onPressed: () => _dump(context),
            child: const Text('debugPrint  →  telescope_dumps (MCP)'),
          ),
        ],
      ),
    ),
  );
}
