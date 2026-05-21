---
paths:
  - "lib/src/watchers/**"
  - "test/src/watchers/**"
---

# Watchers Subsystem

## Contract

Every watcher implements `TelescopeWatcher` (in `lib/src/watchers/watcher.dart`):

```dart
abstract class TelescopeWatcher {
  String get name;
  void install();
  void uninstall();
}
```

The three-method shape is **frozen**: magic-side glue (`MagicModelWatcher`, `MagicCacheWatcher`,
`MagicEventWatcher`, `MagicGateWatcher`, `MagicQueryWatcher`) depends on it. No new abstract methods without a
coordinated magic-side bump.

## Idempotency

Every watcher uses a private `bool _installed` instance field (not a static flag, so multiple instances in test
isolation are independent). `install()` returns immediately when `_installed == true`; `uninstall()` returns
immediately when `_installed == false`. Tests verify both directions: installing twice is a no-op (previous
handler saved only once); uninstalling when not installed is a no-op.

## Chain-preserve pattern

Any watcher that overrides a global hook (`FlutterError.onError`, `PlatformDispatcher.instance.onError`,
`debugPrint`) saves the previous handler before replacing it and calls the previous handler inside the new
handler body. `uninstall()` restores the previous handler symmetrically. This is how Sentry and Bugsnag coexist
with telescope without masking each other. Use numbered step comments:

```dart
// 1. Chain-preserve FlutterError.onError (sync framework errors).
_previousOnError = FlutterError.onError;
FlutterError.onError = (details) { ... _previousOnError?.call(details); };

// 2. Chain-preserve PlatformDispatcher.instance.onError (async + isolate errors).
_previousPlatformOnError = PlatformDispatcher.instance.onError;
PlatformDispatcher.instance.onError = (error, stack) { ... return true; };
```

`ExceptionWatcher` is the reference for both `FlutterError.onError` and `PlatformDispatcher.instance.onError`;
the `PlatformDispatcher.onError` handler always returns `true` to signal handled status. `DumpWatcher`
chain-preserves `debugPrint` using the same pattern.

## DumpWatcher kDebugMode gate

`DumpWatcher.install()` wraps the override in `if (kDebugMode || _allowInRelease)` where `_allowInRelease`
defaults to `false`. Prevents capture in release builds (where `debugPrint` is a no-op anyway) and makes intent
explicit. `ExceptionWatcher` does NOT gate behind `kDebugMode` internally: the consumer's `if (kDebugMode)` at
install time is the gate for all watchers.

## Record feeding

Every watcher calls the matching `TelescopeStore.record*` static method and nothing else. Watchers do not reach
into the store's internal `Queue` or `StreamController` fields. Imports stay minimal: the watcher file imports
its specific record type and `TelescopeStore`; it does not import `telescope_plugin.dart` or `adapters/`.

## Test placement

Mirror `lib/src/watchers/` under `test/src/watchers/`. One production file, one test file. Tests for
chain-preserve: install a sentinel handler first, then install the watcher, trigger an error, assert the sentinel
was also called. Verify `uninstall()` restores the sentinel correctly. Use `TelescopeStore.resetForTesting()` in
`tearDown` and restore replaced global handlers via `addTearDown` (see `.claude/rules/tests.md` for the full test
discipline).
