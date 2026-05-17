/// Contract for HTTP capture adapters that feed [TelescopeStore].
///
/// [install] hooks the underlying HTTP library (Dio interceptor,
/// package:http overrides, Chopper interceptor, or Magic's Http facade).
/// [uninstall] is the inverse for test isolation.
///
/// V1 ships [DioHttpAdapter] (vanilla Dio). Magic ships
/// `MagicHttpFacadeAdapter` inside the magic package (wraps Magic.Http via
/// MagicNetworkInterceptor + feeds TelescopeStore).
abstract class TelescopeHttpAdapter {
  /// Human-readable adapter name.
  String get name;

  /// Wire the HTTP capture hook.
  void install();

  /// Tear down the hook (test isolation).
  void uninstall();
}
