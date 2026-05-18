---
paths:
  - "lib/src/watchers/**"
  - "test/src/watchers/**"
---

# Watchers Subsystem

## Contract shape

Every watcher implements `TelescopeWatcher` (in `lib/src/watchers/watcher.dart`):

```dart
abstract class TelescopeWatcher {
  String get name;
  void install();
  void uninstall();
}
```

The three-method shape is frozen: magic-side glue (`MagicModelWatcher`, `MagicCacheWatcher`, `MagicEventWatcher`,
`MagicGateWatcher`) depends on it. No new abstract methods without a coordinated magic-side bump.

## Idempotency

Every watcher uses a `bool _installed` guard. `install()` returns immediately when `_installed == true`.
`uninstall()` returns immediately when `_installed == false`. Tests verify both directions: installing twice is a
no-op (previous handler saved only once); uninstalling when not installed is a no-op. Use a private `_installed`
field on the instance (not a static flag) so multiple watcher instances in test isolation are independent.

## Chain-preserve pattern

Any watcher that overrides a global hook (`FlutterError.onError`, `PlatformDispatcher.instance.onError`,
`debugPrint`) must save the previous handler before replacing it and call it inside the new handler body. Restoring
the previous handler on `uninstall()` is symmetric. This is how Sentry and Bugsnag coexist with telescope without
masking each other. Steps inside `install()` that do this should use numbered comments:

```dart
// 1. Chain-preserve FlutterError.onError (sync framework errors).
_previousOnError = FlutterError.onError;
FlutterError.onError = (details) { ... _previousOnError?.call(details); };

// 2. Chain-preserve PlatformDispatcher.instance.onError (async + isolate errors).
_previousPlatformOnError = PlatformDispatcher.instance.onError;
PlatformDispatcher.instance.onError = (error, stack) { ... return true; };
```

`ExceptionWatcher` (the reference implementation) hooks both `FlutterError.onError` and
`PlatformDispatcher.instance.onError`. The `PlatformDispatcher.onError` handler always returns `true` to signal
handled status. `DumpWatcher` chain-preserves `debugPrint` using the same pattern.

## kDebugMode gate for DumpWatcher

`DumpWatcher.install()` wraps the override in `if (kDebugMode || _allowInRelease)` where `_allowInRelease` is a
private field defaulting to `false`. This prevents capture in release builds where `debugPrint` is a no-op anyway
but the guard makes intent explicit and matches the plan-wide guardrail. `ExceptionWatcher` does NOT gate behind
`kDebugMode` internally: the consumer's `if (kDebugMode)` at install time is the gate for all watchers.

## Record feeding

Every watcher calls the matching `TelescopeStore.record*` static method and nothing else. Watchers do not reach
into the store's internal `Queue` or `StreamController` fields. Imports stay minimal: the watcher file imports
its specific record type and `TelescopeStore`; it does not import `telescope_plugin.dart` or `adapters/`.

## Test placement

Mirror the `lib/src/watchers/` tree under `test/src/watchers/`. One production file, one test file. Group by class,
then by method:

```
group('ExceptionWatcher', () {
  group('.install()', () { ... });
  group('.uninstall()', () { ... });
});
```

Tests for chain-preserve: install a sentinel handler first, then install the watcher, trigger an error, assert the
sentinel was also called. Verify `uninstall()` restores the sentinel correctly. Use `TelescopeStore.resetForTesting()`
in `tearDown` and restore any replaced global handlers via `addTearDown` to keep test isolation clean.
