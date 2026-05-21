---
paths:
  - "test/**"
---

# Tests

## Layout

Mirror the `lib/src/` tree exactly: `lib/src/watchers/exception_watcher.dart` maps to
`test/src/watchers/exception_watcher_test.dart`. One production file, one test file. The provider test lives at
`test/telescope_artisan_provider_mcp_tools_test.dart` (direct child of `test/`, mirrors the artisan peer).

## Framework and fakes

`flutter_test` only. No mockito. Stub via contract inheritance: write a private `_FakeWatcher`, `_NoOpAdapter`,
`_RecordingStore` class inside the test file. Apply the extract-when-third-caller rule before moving fakes to a
shared file.

No real VM Service connection in any test. Handler tests (`test/src/extensions/`) call the handler functions
directly (they are `@visibleForTesting`) and assert on the returned `ServiceExtensionResponse` JSON.

## State isolation

Every test group that records into `TelescopeStore` adds:

```dart
tearDown(() {
  TelescopeStore.resetForTesting();
});
```

Watcher tests that replace global handlers must also restore them:

```dart
final previous = FlutterError.onError;
addTearDown(() => FlutterError.onError = previous);
```

Missing the teardown lets buffer state contaminate the next test.

## Group naming convention

```dart
group('ClassName', () {
  group('.methodName()', () {
    test('description of the specific behaviour', () { ... });
  });
});
```

Top-level `group` names the class under test. Nested `group` names the method (prefix `.` for instance methods,
no prefix for static methods). Test description is a plain-English sentence starting with the condition or
outcome.

## TDD discipline

Red-green-refactor for every behavioral change. The new test must fail for the right reason before any
implementation lands (not a compile error, not a setup error, a genuine assertion failure). Verify this mentally
before submitting. Empty-buffer edge cases, capacity-overflow FIFO eviction, and chain-preserve pass-through each
need a dedicated test.

## Assertion targets

- **Store tests**: assert on `TelescopeStore.recentX()` return values and `TelescopeStore.onXRecord` stream emissions. Never reach into private `_` fields.
- **Watcher tests**: trigger the watcher hook, then assert via `TelescopeStore.recentX()` that the matching `record*` method was called.
- **Handler tests**: call the handler function directly, decode the JSON response, assert on the decoded map.
- **Provider tests**: instantiate `TelescopeArtisanProvider()`, assert `mcpTools()` length is 9, assert specific `name` and `extensionMethod` per descriptor.

## Baseline + coverage gate

`flutter test --exclude-tags=integration` exits 0 with 249 tests passing after the magic-dev-dep drop.
Pre-existing unrelated failures are flagged in the PR description and not blocking per-step. Run the full suite
once per wave before the wave's commit lands.

Coverage floor 80% enforced by CI (`.github/workflows/ci.yml`); current measurement 95.60%. After behavioral
changes, verify locally:

```bash
flutter test --coverage --exclude-tags=integration --timeout=30s
awk -F: '/^LF:/{lf+=$2} /^LH:/{lh+=$2} END{printf "%.2f%%\n", (lh/lf)*100}' coverage/lcov.info
```
