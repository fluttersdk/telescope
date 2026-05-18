import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttersdk_telescope/telescope.dart';
import 'package:logging/logging.dart';

/// Demo entry. Boots a minimal Material app and (in debug builds only) wires
/// every fluttersdk_telescope capture surface: HTTP via a Dio interceptor that
/// delegates to [DioHttpAdapter.recordRequest], logs via package:logging,
/// uncaught exceptions via [ExceptionWatcher], and debugPrint output via
/// [DumpWatcher]. Release builds tree-shake the entire branch.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  if (kDebugMode) {
    // 1. Boot the telescope plugin (auto-installs LogWatcher + registers
    //    ext.telescope.* VM Service extensions consumed by the MCP server).
    TelescopePlugin.install();

    // 2. Opt-in watchers. ExceptionWatcher hooks both FlutterError.onError and
    //    PlatformDispatcher.onError with chain-preserve. DumpWatcher overrides
    //    debugPrint with chain-preserve.
    TelescopePlugin.registerWatcher(ExceptionWatcher());
    TelescopePlugin.registerWatcher(DumpWatcher());

    // 3. HTTP capture. The V1 DioHttpAdapter is a stub; consumers wire the
    //    interceptor manually per its docstring and call the static
    //    DioHttpAdapter.recordRequest() to feed TelescopeStore.
    dio.interceptors.add(_TelescopeDioInterceptor());
    TelescopePlugin.registerHttpAdapter(DioHttpAdapter());

    // 4. Open the log floodgate so package:logging emits everything down to
    //    FINE; LogWatcher (auto-installed above) forwards each record into
    //    the telescope log buffer.
    Logger.root.level = Level.ALL;
  }

  runApp(DemoApp(dio: dio));
}

/// Captures every Dio request/response/error pair and forwards it to the
/// telescope HTTP ring buffer via [DioHttpAdapter.recordRequest]. Lives in
/// the example because the V1 [DioHttpAdapter] is a deliberate stub (vanilla
/// Flutter friendly: no opinionated `package:dio` dependency in the core).
class _TelescopeDioInterceptor extends Interceptor {
  final Map<RequestOptions, Stopwatch> _timers = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _timers[options] = Stopwatch()..start();
    handler.next(options);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    final stopwatch = _timers.remove(response.requestOptions)?..stop();
    DioHttpAdapter.recordRequest(
      url: response.requestOptions.uri.toString(),
      method: response.requestOptions.method,
      statusCode: response.statusCode ?? 0,
      durationMs: stopwatch?.elapsedMilliseconds ?? 0,
      requestHeaders: response.requestOptions.headers
          .map((key, value) => MapEntry(key, value.toString())),
      requestBody: response.requestOptions.data?.toString(),
      responseBody: response.data?.toString(),
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final stopwatch = _timers.remove(err.requestOptions)?..stop();
    DioHttpAdapter.recordRequest(
      url: err.requestOptions.uri.toString(),
      method: err.requestOptions.method,
      statusCode: err.response?.statusCode ?? 0,
      durationMs: stopwatch?.elapsedMilliseconds ?? 0,
      isError: true,
      requestHeaders: err.requestOptions.headers
          .map((key, value) => MapEntry(key, value.toString())),
      requestBody: err.requestOptions.data?.toString(),
      responseBody: err.response?.data?.toString() ?? err.message,
    );
    handler.next(err);
  }
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key, required this.dio});

  final Dio dio;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fluttersdk_telescope demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: DemoHome(dio: dio),
    );
  }
}

class DemoHome extends StatelessWidget {
  const DemoHome({super.key, required this.dio});

  final Dio dio;

  static final Logger _logger = Logger('demo');

  Future<void> _makeHttpCall() async {
    try {
      await dio.get<dynamic>('https://httpbin.org/get');
    } on DioException catch (error, stack) {
      // Swallowed deliberately: the failed request is already in the
      // telescope HTTP buffer via the error interceptor; we log the catch
      // for the telescope log buffer so reviewers see both surfaces.
      _logger.warning('HTTP call failed', error, stack);
    }
  }

  void _logWarning() {
    _logger
        .warning('Demo warning emitted at ${DateTime.now().toIso8601String()}');
  }

  void _throwException() {
    // Run on the next microtask so the synchronous build/tap path stays
    // clean. PlatformDispatcher.onError (chain-preserved by ExceptionWatcher)
    // picks it up and writes an ExceptionRecord into the telescope buffer.
    Future<void>.microtask(() {
      throw StateError('Intentional demo exception (${DateTime.now()})');
    });
  }

  void _debugPrint() {
    debugPrint(
        'Demo debugPrint emitted at ${DateTime.now().toIso8601String()}');
  }

  @override
  Widget build(BuildContext context) {
    final buttons = <_DemoButton>[
      _DemoButton(label: 'Make HTTP call', onPressed: _makeHttpCall),
      _DemoButton(label: 'Log warning', onPressed: _logWarning),
      _DemoButton(label: 'Throw exception', onPressed: _throwException),
      _DemoButton(label: 'debugPrint', onPressed: _debugPrint),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('fluttersdk_telescope demo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tap a button to exercise a capture surface, then query the '
              'matching telescope_* MCP tool from your agent.',
            ),
            const SizedBox(height: 24),
            for (final button in buttons) ...[
              FilledButton(
                onPressed: button.onPressed,
                child: Text(button.label),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _DemoButton {
  const _DemoButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}
