# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- **`TelescopeStore.pendingHttpCount` getter** (Step 3.4). Sums
  [TelescopeHttpAdapter.pendingCount] across every adapter passed to
  [TelescopePlugin.registerHttpAdapter]. Returns 0 when no adapter is
  registered AND when every registered adapter inherits the default
  `pendingCount => 0`. Read-only sync getter, safe to call from poll loops;
  consumed by `ext.dusk.wait_for_network_idle` to detect a network-idle
  window before yielding the next agent action.
- **`TelescopeHttpAdapter.pendingCount` optional method** (Step 3.4). New
  abstract-contract method with a default body returning 0 ; existing
  implementations (`DioHttpAdapter` ; explicit override added to stay
  compatible with `implements`, magic's `MagicHttpFacadeAdapter` ; overrides
  to return the live in-flight FIFO length) get the new surface additively.
  Hosts that ship a third-party `TelescopeHttpAdapter` via `implements`
  must add an explicit `int get pendingCount => 0;` override; `extends`
  callers inherit the default body for free.
- **`lib/src/internal/http_adapter_registry.dart`** (Step 3.4). Library-
  internal mutable list that [TelescopePlugin.registerHttpAdapter] appends
  to and [TelescopeStore.pendingHttpCount] iterates. Not exported from the
  public barrel; kept off [TelescopeStore] itself to preserve the "one new
  public symbol" constraint on the store.

### Backward compat

`TelescopeHttpAdapter`, `TelescopeWatcher`, `TelescopePlugin.install` /
`registerHttpAdapter` / `registerWatcher` signatures, the 9-buffer
`TelescopeStore` read/record/stream APIs, and the existing 9 MCP tool names
all stay frozen. The new `pendingHttpCount` getter, the new
`pendingCount` method on the adapter contract (with default body), and the
library-internal adapter registry are pure additions; no migration
required for existing watchers / adapters / consumers, except that
third-party `TelescopeHttpAdapter implements ...` users must add an
explicit `pendingCount` override (single line, default 0).

---

## [1.0.0-alpha.3] - 2026-05-19

### Added

- **`MagicQueryWatcher` + DB query capture**: subscribes to the magic-side `QueryExecuted` event dispatched by the database connector and records `QueryRecord` entries (sql, bindings, timeMs, connectionName) to the new `queries` ring buffer. Activates the long-pending DB observation surface promised in alpha-1.
- **`MagicCacheWatcher` activated**: previously a buffer placeholder, the watcher now subscribes to five magic-side cache events (`CacheHit`, `CacheMiss`, `CachePut`, `CacheForget`, `CacheFlush`) via the `EventDispatcher`. Each dispatched event lands in the `magic_cache` buffer tagged with the corresponding operation (`hit` / `miss` / `put` / `forget` / `flush`).
- **9-buffer `TelescopeStore`**: adds the `queries` buffer trio (Queue + StreamController + record/recent helpers). `clear()` includes it; capacity rule still 500 per buffer by default.
- **2 new VM Service extensions**: `ext.telescope.queries`, `ext.telescope.caches`. Both follow the existing handler shape: parse `limit` / `offset` from params, return `ServiceExtensionResponse.result(jsonEncode(payload))`, registered idempotently.
- **2 new MCP tools**: `telescope_queries`, `telescope_caches`. Contributed via `TelescopeArtisanProvider.mcpTools()` as `McpToolDescriptor` const instances, both with Claude Code canonical descriptions. Brings the MCP surface to 9 tools.
- **3 new CLI commands**: `telescope:install`, `telescope:queries`, `telescope:caches`. The provider's `commands()` now returns 6 commands (install + tail + requests + queries + caches + clear).
- **`telescope:install` one-shot bootstrap**: orchestrates `consumer:scaffold` + `plugin:install fluttersdk_telescope` + `lib/main.dart` injection. Detects Magic-stack apps via the `await Magic.init(` anchor and injects `TelescopePlugin.install()` BEFORE Magic.init; falls back to `runApp(` anchor for vanilla Flutter apps. Idempotent: skips `WidgetsFlutterBinding.ensureInitialized()` when already present.
- **`bin/fluttersdk_telescope.dart` wrapper**: Flutter-free CLI entry point so the package's own commands run under `dart run fluttersdk_telescope ...` without dragging in `dart:ui`. Pairs with the new `executables: fluttersdk_telescope` pubspec entry.
- **`lib/cli.dart`**: Flutter-free codegen barrel exposing `FluttersdkTelescopeArtisanProvider` typedef alias. Consumed by `lib/app/_plugins.g.dart` auto-discovery without pulling Flutter symbols into the pure-Dart artisan codegen path.
- **`install.yaml` plugin manifest**: V1 manifest with empty publish list + a post-install bootstrap message. Required for `plugin:install fluttersdk_telescope` to be recognized by the artisan PluginInstaller.

### Magic-side coordinated changes (require magic ^[1.0.0-alpha.14] or unreleased main)

- `magic/lib/src/cache/events/cache_events.dart`: 5 new event classes (`CacheHit`, `CacheMiss`, `CachePut`, `CacheForget`, `CacheFlush`). Exported from `package:magic/magic.dart`.
- `magic/lib/src/cache/cache_manager.dart`: `get` / `put` / `forget` / `flush` now dispatch the matching event through `EventDispatcher.instance` after the underlying store operation completes.
- `magic/lib/src/cache/events/query_executed.dart` (existing): unchanged; `MagicQueryWatcher` subscribes to it.

### Test coverage

- Telescope: 307 tests green (was ~80 after alpha-2). New coverage spans `QueryRecord`, the 9-buffer store expansion, `MagicQueryWatcher`, the activated `MagicCacheWatcher`, the 2 new VM Service handlers (parseable envelope + seeded records + limit + empty payload, 4 each), the 2 new MCP tool descriptors, the 3 new CLI commands, and `TelescopeInstallCommand`'s Magic-stack vs vanilla anchor detection.
- Magic: 1120 tests green (+6 from `test/cache/cache_manager_event_dispatch_test.dart`) covering all 5 cache events end-to-end through the `CacheManager` API.

### Backward compat

`TelescopeHttpAdapter`, `TelescopeWatcher`, `TelescopePlugin.install` / `registerHttpAdapter` / `registerWatcher`, `TelescopeStore.recordX` for the 8 existing buffers, and the existing 7 MCP tool names are all unchanged. The 2 new tools, 2 new extensions, 3 new commands, and 1 new buffer are pure additions. The `queries` buffer activates only when `MagicQueryWatcher` (or another producer) calls `TelescopeStore.recordQuery`.

---

## [1.0.0-alpha.2] - 2026-05-19

### Added

- **DumpWatcher**: vanilla-Flutter `debugPrint` capture; intercepts the global `debugPrint` function pointer, records each message to the `dumps` ring buffer, and chain-preserves the previous handler.
- **MagicEventWatcher** (magic-side): curated event subscription covering auth events (`AuthLogin`, `AuthLogout`, `AuthFailed`, `AuthRestored`), database connection events (`DatabaseConnected`), and gate-define events (`GateAbilityDefined`, `GateBeforeRegistered`). Installed via `MagicTelescopeIntegration.install()` alongside existing adapters. Model lifecycle (`ModelCreated`/`Saved`/`Deleted`) and gate-result events (`GateAccessChecked`) are intentionally NOT subscribed here: the existing `MagicModelWatcher` and the new `MagicGateWatcher` own those channels, so double-record is avoided.
- **MagicGateWatcher** (magic-side): gate-result capture via the `GateAccessChecked` event dispatched by `GateManager` after every `Gate.allows` / `Gate.denies` call. Records gate name, arguments, and result to the `gates` ring buffer.
- **3 new VM Service extensions**: `ext.telescope.events`, `ext.telescope.gates`, `ext.telescope.dumps`. Each follows the existing handler shape: parses `limit` / `offset` from `Map<String, String> params`, returns `ServiceExtensionResponse.result(jsonEncode(payload))`.
- **3 new MCP tools**: `telescope_events`, `telescope_gates`, `telescope_dumps`. Contributed via `TelescopeArtisanProvider.mcpTools()` as `McpToolDescriptor` const instances with Claude Code canonical descriptions.
- **`example/`**: vanilla Flutter harness for live e2e validation of the framework-agnostic path (no Magic dependency). Installs `TelescopePlugin` directly with `DioHttpAdapter` and the new `DumpWatcher`.
- **`example_magic/`**: Magic-stack harness for live e2e validation of the full integration path. Registers `MagicTelescopeIntegration` and all Magic-side watchers in `main.dart`.
- **`CLAUDE.md` + `.claude/rules/watchers.md` + `.claude/rules/tests.md`**: agent infrastructure files covering watcher contract, ring-buffer conventions, and test discipline for this package.
- **~25 new test files**: covering `TelescopeStore` buffer expansion, record types, all new watchers (`DumpWatcher`, `MagicEventWatcher`, `MagicGateWatcher`), the 3 new VM Service extension handlers, the 3 new MCP tool descriptors, and the magic-side adapter integration.

### Changed

- **ExceptionWatcher** now also hooks `PlatformDispatcher.instance.onError` in addition to the existing `FlutterError.onError` hook. Both hooks chain-preserve the previous handler (Sentry / Bugsnag pattern). This closes the gap where uncaught async errors routed through the platform dispatcher were invisible to telescope.
- **`TelescopeStore` default capacity** raised from 100 to 500 per buffer. The `setCapacity(buffer, capacity)` method allows per-buffer override at runtime; existing callers that did not call `setCapacity` will now retain more entries by default.

### Backward compat

`TelescopeHttpAdapter`, `TelescopeWatcher`, `TelescopePlugin.install` / `registerHttpAdapter` / `registerWatcher`, and `TelescopeStore.recordX` signatures are all unchanged. No existing integration code requires modification to upgrade from alpha.1 to alpha.2.

---

## [1.0.0-alpha.1] - 2026-05-17

Initial alpha release. Passive runtime inspector for Flutter apps with a framework-agnostic core and optional Magic-stack integration.

### Added

- **5-buffer `TelescopeStore`**: independent ring buffers for `http`, `logs`, `exceptions`, `magic_model`, and `magic_cache`. Each buffer is a `dart:collection.Queue<T>` (O(1) ends) backed by a `StreamController<T>.broadcast()` for live tail. Default capacity: 100 entries per buffer.
- **HTTP capture**: `DioHttpAdapter` intercepts Dio requests and responses, recording `HttpRecord` entries to the `http` buffer.
- **Log capture**: `LogWatcher` subscribes to `package:logging`'s root `Logger.onRecord` stream and records `LogRecord` entries to the `logs` buffer.
- **Exception capture**: `ExceptionWatcher` hooks `FlutterError.onError`, chain-preserving the previous handler, and records `ExceptionRecord` entries to the `exceptions` buffer.
- **Magic model capture**: `MagicModelWatcher` (via `MagicTelescopeIntegration`) intercepts `ModelCreated`, `ModelSaved`, and `ModelDeleted` events from Magic's event bus and records `MagicModelRecord` entries to the `magic_model` buffer.
- **Magic cache placeholder**: `MagicCacheWatcher` wired in `MagicTelescopeIntegration`; buffer present, capture pending full implementation.
- **4 MCP tools**: `telescope_tail` (live stream of all buffers), `telescope_requests` (paginated HTTP buffer query), `telescope_clear` (flush one or all buffers), `telescope_exceptions` (paginated exception buffer query). Contributed via `TelescopeArtisanProvider.mcpTools()`.
- **3 CLI commands**: `telescope:tail`, `telescope:requests`, `telescope:clear`. Each wraps the matching VM Service extension.
- **`MagicTelescopeIntegration`**: single-file Magic-side glue that installs `MagicHttpFacadeAdapter` (Magic `Http` facade interceptor), `MagicModelWatcher`, and `MagicCacheWatcher` via `TelescopePlugin.registerHttpAdapter` / `registerWatcher` extension points. Idempotent `install()` guard via `_installCount`.
- **`TelescopePlugin.install()`**: static entry point with `_installCount` idempotency guard, `TELESCOPE_DISABLE` env-var kill-switch, auto-registration of default watchers, and `registerAllTelescopeExtensions()` aggregator for all VM Service extensions.
