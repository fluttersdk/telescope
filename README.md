<p align="center">
  <img src="https://raw.githubusercontent.com/fluttersdk/telescope/master/.github/telescope-logo.svg" width="120" alt="Telescope Logo" />
</p>

<h1 align="center">Telescope</h1>

<p align="center">
  <strong>Passive runtime inspector for Flutter apps.</strong><br/>
  HTTP, log, exception, debugPrint, DB query, and Magic model/cache/event/gate capture, surfaced over VM Service extensions to CLI and MCP tools.
</p>

<p align="center">
  <a href="https://pub.dev/packages/fluttersdk_telescope"><img src="https://img.shields.io/pub/v/fluttersdk_telescope.svg" alt="pub package"></a>
  <a href="https://github.com/fluttersdk/telescope/actions"><img src="https://img.shields.io/github/actions/workflow/status/fluttersdk/telescope/ci.yml?branch=master&label=CI" alt="CI"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://pub.dev/packages/fluttersdk_telescope/score"><img src="https://img.shields.io/pub/points/fluttersdk_telescope" alt="pub points"></a>
  <a href="https://github.com/fluttersdk/telescope/stargazers"><img src="https://img.shields.io/github/stars/fluttersdk/telescope?style=flat" alt="GitHub stars"></a>
</p>

<p align="center">
  <a href="https://fluttersdk.com/telescope">Documentation</a> ·
  <a href="https://pub.dev/packages/fluttersdk_telescope">pub.dev</a> ·
  <a href="https://github.com/fluttersdk/telescope/issues">Issues</a>
</p>

---

## Why Telescope?

Debugging a running Flutter app has always required a mix of `print` statements, custom logging sinks, and network proxies that each tell a different slice of the story. When something goes wrong in production or a staging environment, you are left stitching together log files, Charles captures, and Flutter DevTools windows to reconstruct what actually happened. For AI coding agents driving an app via MCP tools, the problem is worse: there is no shared protocol to query runtime state.

**Telescope fixes this.** It registers a set of passive watchers and VM Service extensions at startup. Every HTTP request, log line, exception, `debugPrint` call, DB query, and Magic-framework lifecycle event is captured into a ring buffer. The CLI commands and MCP tools query those buffers without modifying the app's behavior. One `telescope:install` command wires the whole thing end-to-end.

```bash
# One-shot install via artisan
dart run :artisan telescope:install
```

The install command scaffolds the consumer artisan harness if it is missing, runs `plugin:install fluttersdk_telescope`, and patches `lib/main.dart` so `TelescopePlugin.install()` runs before `Magic.init()` (or before `runApp` on vanilla Flutter). Everything is gated under `kDebugMode`; release builds tree-shake the entire subsystem.

## Features

| | Feature | Description |
|:--|:--------|:------------|
| 👁 | **9 Watchers** | LogWatcher, ExceptionWatcher, DumpWatcher, plus 6 Magic-specific adapters covering HTTP, models, cache, events, gates, and DB queries |
| 🤖 | **9 MCP Tools** | `telescope_requests`, `telescope_tail`, `telescope_exceptions`, `telescope_events`, `telescope_gates`, `telescope_dumps`, `telescope_queries`, `telescope_caches`, `telescope_clear` |
| 🖥 | **6 CLI Commands** | `telescope:install`, `telescope:tail`, `telescope:requests`, `telescope:queries`, `telescope:caches`, `telescope:clear` |
| 🔌 | **Adapter Contract** | `TelescopeHttpAdapter` (abstract, 3-method shape) for plugging any HTTP client; ships `DioHttpAdapter` for vanilla Dio |
| 📋 | **9 Record Types** | Immutable: `HttpRequestRecord`, `LogRecordEntry`, `ExceptionRecord`, `MagicModelRecord`, `MagicCacheRecord`, `EventRecord`, `GateRecord`, `DumpRecord`, `QueryRecord` |
| 📡 | **VM Service Extensions** | 11 extensions: `ext.telescope.requests`, `.console`, `.exceptions`, `.events`, `.gates`, `.dumps`, `.queries`, `.caches`, `.clear`, `.pause`, `.resume` |
| ✨ | **Magic Integration** | `MagicTelescopeIntegration.install()` wires Http facade adapter + model/cache/event/gate watchers in one call |
| 🔒 | **Debug-only Gate** | Consumer wraps install inside `if (kDebugMode)`; release builds tree-shake the entire telescope branch on all platforms |
| 🔄 | **Idempotent Install** | Every `registerExtension` call routes through `registerExtensionIdempotent`; hot-restart safe, no `ArgumentError` on re-registration |

## Quick Start

### Option A (recommended): one-shot install

Once the consumer has `fluttersdk_artisan` wired (`bin/artisan.dart` + `.artisan/plugins.json`), let telescope install itself end-to-end:

```bash
dart run :artisan telescope:install
```

The command scaffolds the consumer artisan harness if it's missing, runs `plugin:install fluttersdk_telescope`, and patches `lib/main.dart` so `TelescopePlugin.install()` runs before `Magic.init()` (or before `runApp` on vanilla Flutter). Idempotent; safe to re-run.

### Option B: manual wiring

#### 1. Add the dependency

```yaml
# pubspec.yaml
dependencies:
  fluttersdk_telescope: ^0.0.1
```

#### 2. Install in `main.dart`

Install Telescope before `Magic.init()` (or before `runApp` for plain Flutter). Wrap every install call in `kDebugMode` so the entire tooling branch is tree-shaken in release builds.

```dart
import 'package:flutter/foundation.dart';
import 'package:fluttersdk_telescope/telescope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Install Telescope core (auto-installs LogWatcher + registers VM extensions).
  if (kDebugMode) {
    TelescopePlugin.install();

    // 2. Opt-in watchers registered after install().
    TelescopePlugin.registerWatcher(ExceptionWatcher());
    TelescopePlugin.registerWatcher(DumpWatcher());
  }

  // 3. Magic-side adapters run AFTER Magic.init() because they resolve
  //    framework internals (Http facade, Gate manager) from the IoC container.
  await Magic.init(configFactories: [...]);

  if (kDebugMode) {
    MagicTelescopeIntegration.install();
  }

  runApp(MyApp());
}
```

#### 3. Register the Artisan provider (MCP tools)

In `bin/artisan.dart`, register `TelescopeArtisanProvider` so the 9 `telescope_*` MCP tools are visible to Claude Code and other MCP clients:

```dart
import 'package:fluttersdk_telescope/telescope.dart' show TelescopeArtisanProvider;

exit(await runArtisan(
  args,
  baseProviders: [
    MagicArtisanProvider(),
    TelescopeArtisanProvider(),
    ...plugins.autoDiscoveredProviders(),
  ],
));
```

## Watchers

| Watcher | Captures | Auto-install? | Notes |
|---------|----------|---------------|-------|
| `LogWatcher` | All `package:logging` Logger calls | Yes | Installed automatically by `TelescopePlugin.install()`. |
| `ExceptionWatcher` | Unhandled exceptions via `FlutterError.onError` + `PlatformDispatcher.onError` | No | Call `TelescopePlugin.registerWatcher(ExceptionWatcher())` after install. Both hooks chain-preserve any previously registered handler (Sentry, Bugsnag, etc.). |
| `DumpWatcher` | `debugPrint` + `print` output | No | Overrides `debugPrint` globally; chain-preserves previous override. Active in debug mode only. |
| `MagicHttpFacadeAdapter` | HTTP traffic through the Magic `Http` facade | No | Register via `TelescopePlugin.registerHttpAdapter(MagicHttpFacadeAdapter())`. Requires Magic framework. |
| `MagicModelWatcher` | Magic Eloquent model `create`, `save`, `delete` lifecycle events | No | Register via `TelescopePlugin.registerWatcher(MagicModelWatcher())`. Requires Magic framework. |
| `MagicCacheWatcher` | `Cache.get` / `put` / `forget` / `flush` (hit + miss + put + forget + flush operations) | No | Subscribes to magic-side `CacheHit` / `CacheMiss` / `CachePut` / `CacheForget` / `CacheFlush` events. Requires Magic framework. |
| `MagicEventWatcher` | Events dispatched through the Magic `Event` facade | No | Register via `TelescopePlugin.registerWatcher(MagicEventWatcher())`. Requires Magic framework. |
| `MagicGateWatcher` | `Gate.allows` / `Gate.denies` authorization checks | No | Register via `TelescopePlugin.registerWatcher(MagicGateWatcher())`. Requires Magic framework. |
| `MagicQueryWatcher` | Magic SQLite + remote DB queries (sql, bindings, timeMs, connection) | No | Subscribes to the magic-side `QueryExecuted` event dispatched by the database connector. Requires Magic framework. |

## MCP Tools

Exposed via `TelescopeArtisanProvider` when the consumer registers it in `bin/artisan.dart`. All tools route through `ext.telescope.*` VM Service extensions and require a running Flutter app.

| Tool | Extension method | Captures |
|------|-----------------|----------|
| `telescope_tail` | `ext.telescope.console` | Log ring buffer (`package:logging` records); filter by level + limit. |
| `telescope_requests` | `ext.telescope.requests` | HTTP request ring buffer (method, URL, status, duration, headers, body snippet). |
| `telescope_exceptions` | `ext.telescope.exceptions` | Uncaught exception ring buffer (type, message, stack trace). |
| `telescope_clear` | `ext.telescope.clear` | Wipes all ring buffers atomically. No parameters. |
| `telescope_events` | `ext.telescope.events` | In-app event ring buffer (Magic `Event.dispatch` calls; event type + payload). |
| `telescope_gates` | `ext.telescope.gates` | Gate authorization check ring buffer (ability, result, user id, argument type). |
| `telescope_dumps` | `ext.telescope.dumps` | `debugPrint` output ring buffer (message + timestamp). |
| `telescope_queries` | `ext.telescope.queries` | DB query ring buffer (sql, bindings, timeMs, connectionName). |
| `telescope_caches` | `ext.telescope.caches` | Cache operation ring buffer (operation: hit / miss / put / forget / flush; key; ttlMs). |

## CLI Commands

Registered via `TelescopeArtisanProvider.commands()` and dispatched through `dart run :artisan <command>` once the provider is wired in `bin/artisan.dart`.

| Command | Purpose |
|---------|---------|
| `telescope:install` | One-shot bootstrap: scaffolds consumer artisan harness, runs `plugin:install fluttersdk_telescope`, and injects `TelescopePlugin.install()` into `lib/main.dart`. Detects Magic-stack apps via the `await Magic.init(` anchor and injects BEFORE Magic.init; falls back to `runApp(` for vanilla Flutter. |
| `telescope:tail` | Stream the log buffer. Filter by level + limit. |
| `telescope:requests` | Print the HTTP request buffer (paginated). |
| `telescope:queries` | Print the DB query buffer (paginated). |
| `telescope:caches` | Print the cache operation buffer (paginated). |
| `telescope:clear` | Flush all buffers atomically. |

## Examples

### `example/`

Vanilla Flutter app (no Magic framework) that exercises every framework-agnostic capture surface: HTTP traffic via the Telescope Dio interceptor, log output via `package:logging`, uncaught exceptions via `ExceptionWatcher`, and `debugPrint` output via `DumpWatcher`. Demonstrates the minimal install pattern and the in-app overlay dashboard.

```bash
cd example && flutter run -d chrome
```

### `example_magic/`

Magic-stack app that exercises all 9 watchers including the Magic-specific adapters: `MagicHttpFacadeAdapter` (Http facade traffic), `MagicModelWatcher` (Eloquent lifecycle), `MagicCacheWatcher` (Cache facade lifecycle), `MagicEventWatcher` (Event.dispatch calls), `MagicGateWatcher` (Gate authorization checks), and `MagicQueryWatcher` (DB queries via the magic database connector). Use the artisan MCP server from this directory to verify all 9 `telescope_*` MCP tools surface correctly.

```bash
cd example_magic && flutter run -d chrome
```

## Architecture

Telescope is subsystem-first under `lib/src/`, every directory owns a single concern:

```
lib/
├── telescope.dart              # Single barrel, re-exports the full public API
├── cli.dart                    # Flutter-free codegen barrel (FluttersdkTelescopeArtisanProvider typedef)
└── src/
    ├── watchers/               # TelescopeWatcher abstract contract + LogWatcher, ExceptionWatcher, DumpWatcher
    ├── adapters/               # TelescopeHttpAdapter abstract contract + DioHttpAdapter concrete impl
    ├── records/                # Immutable record types: HttpRequestRecord, LogRecordEntry, ExceptionRecord, etc.
    ├── extensions/             # registerAllTelescopeExtensions() aggregator + per-concern VM Service handlers
    ├── commands/               # TelescopeInstallCommand + 5 tail/query/clear commands
    ├── telescope_store.dart    # 9-buffer ring store (singleton); Queue<T> per buffer + broadcast StreamController<T>
    ├── telescope_plugin.dart   # TelescopePlugin.install() entry + registerHttpAdapter() + registerWatcher()
    └── telescope_artisan_provider.dart  # TelescopeArtisanProvider: 6 commands + 9 MCP tool descriptors
```

Boot flow:

```
TelescopePlugin.install()
    ↓
Register default watchers (LogWatcher auto-installs)
    ↓
registerAllTelescopeExtensions()   # 11 ext.telescope.* VM Service extensions, idempotent
    ↓
Consumer registers TelescopeArtisanProvider in bin/artisan.dart
    ↓
artisan mcp:serve   ->   9 telescope_* tools surface to MCP clients (Claude Code, Cursor, etc.)
```

Every concrete watcher and record type is a `final class`. The two adapter contracts (`TelescopeWatcher`, `TelescopeHttpAdapter`) are `abstract class` with frozen 3-method signatures (`name`, `install`, `uninstall`). Magic-side glue (`MagicHttpFacadeAdapter`, `MagicModelWatcher`, etc.) depends on these contracts; any signature change requires a coordinated bump across both repos.

## AI Agent Integration

Use Telescope with AI coding assistants like Claude Code or Cursor via the artisan MCP server. The 9 `telescope_*` tools give the agent direct read access to every runtime buffer: inspect HTTP traffic without a proxy, read logs without grepping output, catch exceptions without scrolling DevTools.

A typical agent session looks like this:

```
[agent] artisan_start { device: chrome }          // launch the app
[agent] <exercise the feature under inspection>
[agent] telescope_requests {}                     // inspect all HTTP calls made
[agent] telescope_tail { level: warning }         // filter logs to warnings and above
[agent] telescope_exceptions {}                   // check for any uncaught exceptions
[agent] telescope_queries {}                      // review DB queries and timings
[agent] telescope_clear {}                        // flush buffers before the next scenario
[agent] artisan_stop                              // tear down
```

For agents that read structured project context at attach time, the canonical entry point is [`llms.txt`](llms.txt) at the repo root (also published at `https://fluttersdk.com/telescope/llms.txt`). It enumerates the watcher surface, the VM extension catalog, and every MCP tool input schema in agent-readable form.

## Documentation

Full docs with live examples at **[fluttersdk.com/telescope](https://fluttersdk.com/telescope)**.

| Topic | |
|:------|:-|
| [Getting Started](https://fluttersdk.com/telescope/getting-started/) | Overview, requirements, first install |
| [Watchers](https://fluttersdk.com/telescope/watchers/) | All 9 watchers: setup, chain-preserve pattern, Magic adapters |
| [MCP Tools](https://fluttersdk.com/telescope/mcp/) | Every tool, every input schema, filter parameters |

## Contributing

```bash
git clone https://github.com/fluttersdk/telescope.git
cd telescope && dart pub get
flutter test && dart analyze
```

The baseline is 307+ tests green. New behavior ships with the matching test (red, green, refactor). `dart format lib/ test/ bin/` must produce no diff and `dart analyze` must report zero issues across `lib/`, `test/`, and `bin/`.

Before opening a pull request, also run:

```bash
dart format lib/ test/ bin/         # zero diff
dart analyze                         # zero issues
dart pub publish --dry-run           # validate the publish archive
```

[Report a bug](https://github.com/fluttersdk/telescope/issues/new?template=bug_report.yml) · [Request a feature](https://github.com/fluttersdk/telescope/issues/new?template=feature_request.yml)

## License

MIT, see [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>Built with care by <a href="https://github.com/fluttersdk">FlutterSDK</a></sub><br/>
  <sub>If Telescope saves you debugging time, <a href="https://github.com/fluttersdk/telescope">give it a star</a>, it helps others discover it.</sub>
</p>
