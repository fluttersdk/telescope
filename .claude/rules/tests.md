---
paths:
  - "test/**"
---

# Tests

## Layout

Mirror the `lib/src/` tree exactly. Production file `lib/src/watchers/exception_watcher.dart` maps to test
`test/src/watchers/exception_watcher_test.dart`. New test files match the source path 1:1. Provider test lives
at `test/telescope_artisan_provider_mcp_tools_test.dart` (direct child of `test/`, mirrors the artisan peer).

## Framework and fakes

`flutter_test` only (package declared as dev dep). No mockito. Stub via contract inheritance: write a private
`_FakeWatcher`, `_NoOpAdapter`, `_RecordingStore` class inside the test file. Apply the extract-when-third-caller
rule before moving fakes to a shared file.

The `magic` dev dep (`path: ../magic`) is available for the integration tests under `test/src/magic/`. Those tests
exercise `MagicEventWatcher`, `MagicGateWatcher`, `MagicModelWatcher`, `MagicCacheWatcher`, and
`MagicHttpFacadeAdapter` via magic's `EventDispatcher` and `TelescopeStore` directly. They do NOT spin up a real
Flutter app or VM Service.

No real VM Service connection in any test. Handler tests (`test/src/extensions/`) call the handler functions
directly (they are `@visibleForTesting`) and assert on the returned `ServiceExtensionResponse` JSON.

## State isolation

```dart
tearDown(() {
  TelescopeStore.resetForTesting();
});
```

Add this to every test group that records into `TelescopeStore`. Missing it lets buffer state from one test
contaminate the next. Watcher tests that replace global handlers must also restore them:

```dart
final previous = FlutterError.onError;
addTearDown(() => FlutterError.onError = previous);
```

## Group naming convention

```dart
group('ClassName', () {
  group('.methodName()', () {
    test('description of the specific behaviour', () { ... });
  });
});
```

Top-level `group` names the class under test. Nested `group` names the method (prefix with `.` for instance
methods, no prefix for static methods). Test description is a plain-English sentence starting with the condition
or outcome.

## TDD discipline

Red-green-refactor for every behavioral change. New test must fail for the right reason before any implementation
lands (not a compile error, not a setup error, a genuine assertion failure). Verify this mentally before submitting.
Empty-buffer edge cases, capacity-overflow FIFO eviction, and chain-preserve pass-through each need a dedicated test.

## Assertion targets

- Store tests: assert on `TelescopeStore.recentX()` return values and `TelescopeStore.onXRecord` stream emissions.
  Never reach into private `_` fields.
- Watcher tests: assert that the matching `TelescopeStore.record*` method was called by checking
  `TelescopeStore.recentX()` after triggering the watcher's hook.
- Handler tests: call the handler function directly, decode the JSON response, assert on the decoded map.
- Provider tests: instantiate `TelescopeArtisanProvider()` directly, assert `mcpTools()` returns a list of the
  expected length, and assert specific `name` and `extensionMethod` values for each descriptor.

## Baseline

`flutter test` exits 0 with 33+ tests passing after alpha-2. Pre-existing unrelated failures are flagged in the PR
description and not blocking per-step. Run the full suite once per wave before the wave's commit lands.
