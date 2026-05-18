# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0-alpha.2] - 2026-05-19

### Added

- **DumpWatcher**: vanilla-Flutter `debugPrint` capture; intercepts the global `debugPrint` function pointer, records each message to the `dumps` ring buffer, and chain-preserves the previous handler.
- **MagicEventWatcher** (magic-side): curated event subscription covering auth events (`AuthLoginSucceeded`, `AuthLogoutSucceeded`), database lifecycle events (`ModelCreated`, `ModelSaved`, `ModelDeleted`), and gate-define events (`GateDefined`). Installed via `MagicTelescopeIntegration.install()` alongside existing adapters.
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
