import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'adapters/http_adapter.dart';
import 'extensions/register_telescope_extensions.dart';
import 'internal/http_adapter_registry.dart';
import 'watchers/log_watcher.dart';
import 'watchers/watcher.dart';

/// fluttersdk_telescope plugin install entry. Idempotent.
///
/// V1 auto-installs [LogWatcher] (zero ceremony, package:logging is the
/// de-facto standard). ExceptionWatcher is opt-in (call install()
/// separately). HTTP adapters are registered via [registerHttpAdapter].
class TelescopePlugin {
  TelescopePlugin._();

  static final List<TelescopeHttpAdapter> _httpAdapters = [];
  static final List<TelescopeWatcher> _watchers = [];

  /// Register a pluggable HTTP capture adapter (Dio, package:http, Chopper,
  /// Magic's Http facade). The adapter's install() is called immediately.
  ///
  /// Also pushes the adapter onto the library-internal [httpAdapterRegistry]
  /// so [TelescopeStore.pendingHttpCount] can sum
  /// [TelescopeHttpAdapter.pendingCount] across every registered adapter
  /// without taking a new public API on [TelescopeStore].
  static void registerHttpAdapter(TelescopeHttpAdapter adapter) {
    _httpAdapters.add(adapter);
    httpAdapterRegistry.add(adapter);
    adapter.install();
  }

  /// Register an additional watcher (Magic model, Magic cache, custom).
  /// The watcher's install() is called immediately.
  static void registerWatcher(TelescopeWatcher watcher) {
    _watchers.add(watcher);
    watcher.install();
  }

  /// Idempotent install. Auto-installs LogWatcher + registers extensions.
  static void install() {
    final disable = telescopeDisableEnvValue.toLowerCase().trim();
    if (disable == '1' || disable == 'true' || disable == 'yes') {
      developer.log(
        '[fluttersdk_telescope] install() skipped — TELESCOPE_DISABLE set.',
        name: 'telescope',
      );
      return;
    }
    if (_installCount > 0) {
      developer.log(
        '[fluttersdk_telescope] install() called ${_installCount + 1} times — '
        'skipping duplicate.',
        name: 'telescope',
      );
      _installCount++;
      return;
    }
    _installCount++;

    // Auto-install LogWatcher (zero-ceremony default).
    final logWatcher = LogWatcher();
    logWatcher.install();
    _watchers.add(logWatcher);

    registerAllTelescopeExtensions();

    developer.log(
      '[fluttersdk_telescope] installed (kDebugMode=$kDebugMode, kIsWeb=$kIsWeb)',
      name: 'telescope',
    );
  }

  static int _installCount = 0;

  @visibleForTesting
  static int get installCount => _installCount;

  @visibleForTesting
  static String telescopeDisableEnvValue = const String.fromEnvironment(
    'TELESCOPE_DISABLE',
    defaultValue: '',
  );
}
