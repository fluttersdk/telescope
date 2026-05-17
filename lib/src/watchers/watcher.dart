/// Contract for additional data collectors registered via
/// [TelescopePlugin.registerWatcher].
///
/// Built-in: LogWatcher (auto-installed), ExceptionWatcher (opt-in).
/// Magic ships MagicModelWatcher + MagicCacheWatcher via this interface.
abstract class TelescopeWatcher {
  /// Human-readable watcher name.
  String get name;

  /// Wire the watcher's listening hook (event subscription, override, etc.).
  void install();

  /// Tear down the hook (test isolation).
  void uninstall();
}
