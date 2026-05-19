import '../records/http_request_record.dart';
import '../telescope_store.dart';
import 'http_adapter.dart';

/// Vanilla Dio HTTP adapter. Hook by calling
/// `dio.interceptors.add(DioHttpAdapter(dio).asDioInterceptor());`
/// after constructing the adapter.
///
/// NOT a Magic-coupled implementation — vanilla Flutter apps using raw Dio
/// instances feed TelescopeStore via this adapter. Magic-app users get the
/// Magic.Http facade adapter via magic's MagicTelescopeIntegration instead.
///
/// V1 stub: the actual Dio Interceptor subclass requires `package:dio` which
/// is not in telescope's pubspec (vanilla Flutter friendly — we avoid
/// declaring opinionated HTTP lib deps). Consumers add `dio` to THEIR pubspec
/// and wire this adapter manually. V1.x: move this to `fluttersdk_telescope_dio`
/// adapter sub-package.
class DioHttpAdapter implements TelescopeHttpAdapter {
  DioHttpAdapter();

  @override
  String get name => 'dio';

  @override
  void install() {
    // V1 stub. Consumer code wires this adapter by calling
    // `dio.interceptors.add(_DioInterceptor())` where _DioInterceptor extends
    // Dio's Interceptor class and routes onRequest/onResponse/onError to
    // TelescopeStore.recordHttp(HttpRequestRecord(...)).
    //
    // V1.x will move the Dio-coupled glue into `fluttersdk_telescope_dio` so
    // the core telescope package stays HTTP-library-agnostic.
  }

  @override
  void uninstall() {
    // No-op in V1 stub.
  }

  /// V1 stub adapter does not track in-flight requests (the Dio interceptor
  /// wiring lives in consumer code). Explicit override is required because
  /// Dart's `implements` clause does not inherit default method bodies from
  /// the [TelescopeHttpAdapter] contract.
  @override
  int get pendingCount => 0;

  /// Convenience: programmatically record an HTTP request/response pair into
  /// TelescopeStore from any HTTP library wrapper (Dio, http, Chopper, raw).
  static void recordRequest({
    required String url,
    required String method,
    required int statusCode,
    required int durationMs,
    bool isError = false,
    Map<String, String>? requestHeaders,
    String? requestBody,
    String? responseBody,
  }) {
    TelescopeStore.recordHttp(
      HttpRequestRecord(
        url: url,
        method: method,
        statusCode: statusCode,
        durationMs: durationMs,
        isError: isError,
        timestamp: DateTime.now(),
        requestHeaders: requestHeaders,
        requestBody: requestBody,
        responseBody: responseBody,
      ),
    );
  }
}
