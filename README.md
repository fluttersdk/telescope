<p align="center">
  <img src="https://raw.githubusercontent.com/fluttersdk/telescope/master/.github/telescope-logo.svg" width="120" alt="Telescope Logo" />
</p>

<h1 align="center">Telescope</h1>

<p align="center">
  <strong>Passive runtime inspector for Flutter. Read by humans, queried by AI agents.</strong><br/>
  HTTP, logs, exceptions, <code>debugPrint</code>, DB queries, and Magic events captured over VM Service extensions, surfaced as <code>telescope:*</code> CLI commands and as 9 MCP tools for Claude Code.
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

**Stop pasting stack traces into Claude. Let your agent read them itself.**

Debugging a running Flutter app has always required a mix of `print` statements, custom logging sinks, and network proxies that each tell a different slice of the story. When something breaks, you stitch together log files, Charles captures, and Flutter DevTools windows to reconstruct what happened. The AI workflow is worse: you copy the stack trace out of the console, paste it into Claude Code, copy the failing HTTP response, paste it back, repeat.

**Telescope closes that loop.** Passive watchers and 11 VM Service extensions register at startup. Every HTTP request, log line, exception, `debugPrint` call, DB query, and Magic-framework lifecycle event lands in a ring buffer. CLI commands (`telescope:tail`, `telescope:requests`) stream the buffers for humans; **9 MCP tools** (`telescope_requests`, `telescope_exceptions`, `telescope_tail`, ...) expose the same buffers to AI coding agents like Claude Code, Cursor, and Codex. No copy-paste, no screenshots, no SaaS account. Debug-only; `kDebugMode` tree-shakes the entire subsystem on release builds.

```bash
# One-shot self-bootstrap install (works from a fresh consumer)
flutter pub add fluttersdk_telescope
dart run fluttersdk_telescope telescope:install
```

The install command scaffolds the consumer artisan harness if it is missing, runs `plugin:install fluttersdk_telescope`, and patches `lib/main.dart` so `TelescopePlugin.install()` runs before `Magic.init()` (or before `runApp` on vanilla Flutter). Everything is gated under `kDebugMode`; release builds tree-shake the entire subsystem.

After install, the consumer gets the artisan fast-cli at `./bin/fsa` (native AOT, ~110ms warm startup) for every subsequent telescope command. `dart run fluttersdk_telescope <cmd>` keeps working as a slower (~3s cold) fallback.

## Features

| | Feature | Description |
|:--|:--------|:------------|
| 👁 | **9 Watchers** | LogWatcher, ExceptionWatcher, DumpWatcher, plus 6 Magic-specific adapters covering HTTP, models, cache, events, gates, and DB queries |
| 🤖 | **9 MCP Tools** | `telescope_requests`, `telescope_tail`, `telescope_exceptions`, `telescope_events`, `telescope_gates`, `telescope_dumps`, `telescope_queries`, `telescope_caches`, `telescope_clear` |
| 🖥 | **6 CLI Commands** | `telescope:install`, `telescope:tail`, `telescope:requests`, `telescope:queries`, `telescope:caches`, `telescope:clear` |
| 🔌 | **Adapter Contract** | `TelescopeHttpAdapter` (abstract, 3-method shape) for plugging any HTTP client; ships `DioHttpAdapter` for vanilla Dio |
| 📋 | **9 Record Types** | Immutable: `HttpRequestRecord`, `LogRecordEntry`, `ExceptionRecord`, `MagicModelRecord`, `MagicCacheRecord`, `EventRecord`, `GateRecord`, `DumpRecord`, `QueryRecord` |
| 📡 | **VM Service Extensions** | 11 extensions: `ext.telescope.requests`, `.console`, `.exceptions`, `.events`, `.gates`, `.dumps`, `.queries`, `.caches`, `.clear`, `.pause`, `.resume` |
| ✨ | **Magic Integration** | `MagicTelescopeIntegration.install()` wires Http facade adapter + model/cache/event/gate watchers in one call (ships in the `magic_devtools` dev_dependency) |
| 🔒 | **Debug-only Gate** | Consumer wraps install inside `if (kDebugMode)`; release builds tree-shake the entire telescope branch on all platforms |
| 🔄 | **Idempotent Install** | Every `registerExtension` call routes through `registerExtensionIdempotent`; hot-restart safe, no `ArgumentError` on re-registration |

## Quick Start

### Option A (recommended): one-shot install

Add the dependency, then let telescope bootstrap itself via its own CLI entry point. No prior `fluttersdk_artisan` wiring is required; telescope's binary carries the artisan substrate so the install works from a fresh consumer:

```bash
flutter pub add fluttersdk_telescope
dart run fluttersdk_telescope telescope:install
```

The command scaffolds the consumer artisan harness if it's missing (`bin/dispatcher.dart` + `lib/app/_plugins.g.dart`), runs `plugin:install fluttersdk_telescope`, and patches `lib/main.dart` so `TelescopePlugin.install()` runs before `Magic.init()` (or before `runApp` on vanilla Flutter). Idempotent; safe to re-run.

For everyday repeat usage, the consumer's `./bin/fsa` (artisan native AOT binary built during install) gives ~110ms warm startup:

```bash
./bin/fsa telescope:tail
./bin/fsa telescope:requests
```

`dart run fluttersdk_telescope <cmd>` remains a slower (~3s cold) fallback that always works without the AOT bundle.

### Option B: manual wiring

#### 1. Add the dependency

```yaml
# pubspec.yaml
dependencies:
  fluttersdk_telescope: ^0.0.4
```

#### 2. Install in `main.dart`

Install Telescope before `Magic.init()` (or before `runApp` for plain Flutter). Wrap every install call in `kDebugMode` so the entire tooling branch is tree-shaken in release builds.

```dart
import 'package:flutter/foundation.dart';
import 'package:fluttersdk_telescope/telescope.dart';
import 'package:magic_devtools/telescope.dart'; // magic_devtools dev_dependency (Magic-stack apps only)

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
    // MagicTelescopeIntegration ships in magic_devtools (not magic core).
    // Add magic_devtools to dev_dependencies in pubspec.yaml.
    MagicTelescopeIntegration.install();
  }

  runApp(MyApp());
}
```

#### 3. Register the Artisan provider (MCP tools)

In the consumer's `bin/dispatcher.dart` (generated by `dart run fluttersdk_artisan install`), telescope is auto-discovered through `lib/app/_plugins.g.dart` after `plugin:install fluttersdk_telescope`. If you are wiring providers by hand, add `FluttersdkTelescopeArtisanProvider()` to the `baseProviders` list so the 9 `telescope_*` MCP tools are visible to Claude Code and other MCP clients:

```dart
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:fluttersdk_telescope/cli.dart' show FluttersdkTelescopeArtisanProvider;

exit(await runArtisan(
  args,
  baseProviders: [
    FluttersdkTelescopeArtisanProvider(),
    // ...other providers (DuskArtisanProvider, etc.)
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

Exposed via `TelescopeArtisanProvider` when the consumer registers it (auto-wired by `telescope:install` through `lib/app/_plugins.g.dart` + `bin/dispatcher.dart`). All tools route through `ext.telescope.*` VM Service extensions and require a running Flutter app.

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

Registered via `TelescopeArtisanProvider.commands()`. After `telescope:install` you can invoke any command three ways: through the consumer's fast-cli (`./bin/fsa <command>`, recommended), through telescope's standalone bin (`dart run fluttersdk_telescope <command>`), or through the consumer dispatcher fallback (`dart run fluttersdk_artisan <command>`).

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
Consumer registers TelescopeArtisanProvider (auto-wired by `telescope:install` via bin/dispatcher.dart + _plugins.g.dart)
    ↓
artisan mcp:serve   ->   9 telescope_* tools surface to MCP clients (Claude Code, Cursor, etc.)
```

Every concrete watcher and record type is a `final class`. The two adapter contracts (`TelescopeWatcher`, `TelescopeHttpAdapter`) are `abstract class` with frozen 3-method signatures (`name`, `install`, `uninstall`). Magic-side glue (`MagicHttpFacadeAdapter`, `MagicModelWatcher`, etc.) depends on these contracts; any signature change requires a coordinated bump across both repos.

## Compared to

| Tool | What it does | Where telescope wins |
|---|---|---|
| **[Sentry Flutter](https://pub.dev/packages/sentry_flutter)** | Production crash + perf reporting via external SaaS | Local-only; debug-only; CLI + MCP queryable from your agent; no DSN, no SaaS account |
| **[Talker / talker_flutter](https://pub.dev/packages/talker_flutter)** | In-app log overlay, Dio interceptor | VM Service surface (queryable by tools); MCP server for AI agents; framework-aware model / cache / event / gate watchers |
| **[Alice](https://pub.dev/packages/alice)** | In-app HTTP request overlay UI | Captures 9 buffers (not just HTTP); passive (no shake-to-open overlay); CLI streaming; AI agent access; debug tree-shake |
| **[Flutter DevTools](https://docs.flutter.dev/tools/devtools/overview)** | Official browser-based inspector | Programmatic access (CLI + MCP), not just human-via-browser; ring-buffered records you can query between iterations; domain-aware (Magic) watchers |
| **[mcp_flutter](https://github.com/Arenukvern/mcp_flutter)** | MCP toolkit for AI-driven UI interaction (tap, scroll, snapshot) | Complementary, not competitive: telescope owns runtime telemetry (HTTP, exceptions, queries); mcp_flutter owns UI automation |

## AI Agent Integration

Telescope is the first Flutter MCP server focused on **runtime observability** (HTTP, exceptions, queries, cache) rather than UI automation. The 9 `telescope_*` tools give Claude Code, Cursor, Codex, or any MCP-compatible agent direct read access to every runtime buffer: inspect HTTP traffic without a proxy, read logs without grepping output, catch exceptions without scrolling DevTools.

### One-line `.mcp.json` install

`telescope:install` auto-writes `.mcp.json` for you. Or wire it manually for any MCP-compatible client:

```jsonc
// .mcp.json (project root) — Claude Code / Codex / Cursor / Goose / VS Code Copilot
{
  "mcpServers": {
    "fluttersdk": {
      "command": "./bin/fsa",
      "args": ["mcp:serve"],
      "cwd": "."
    }
  }
}
```

After this, restart your MCP client. The 9 `telescope_*` tools (plus the substrate's `artisan_*` tools) surface automatically in `/mcp`.

### Before / after

| Without telescope | With telescope |
|---|---|
| Stack trace appears in your console. You copy it. You paste it into Claude. Claude asks for the HTTP response that triggered it. You scroll, copy, paste. | Claude calls `telescope_exceptions` → reads the last 500 captured exceptions with timestamps + stack traces. Claude calls `telescope_requests` → reads matched HTTP records. Claude proposes the fix. |
| You hot-reload, retry, paste again. | Claude calls `telescope_clear` between iterations. The fix loop closes without you in the middle. |

### Typical agent session

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

The baseline is 249 tests green (post magic-dev-dep drop). New behavior ships with the matching test (red, green, refactor). `dart format lib/ test/ bin/` must produce no diff and `dart analyze` must report zero issues across `lib/`, `test/`, and `bin/`.

Before opening a pull request, also run:

```bash
dart format lib/ test/ bin/         # zero diff
dart analyze                         # zero issues
dart pub publish --dry-run           # validate the publish archive
```

[Report a bug](https://github.com/fluttersdk/telescope/issues/new?template=bug_report.yml) · [Request a feature](https://github.com/fluttersdk/telescope/issues/new?template=feature_request.yml)

## Inspiration

Telescope is inspired by [**Laravel Telescope**](https://laravel.com/docs/telescope), the elegant developer-tools assistant for Laravel that records every request, exception, log, query, cache hit, and event into a queryable timeline. The same pattern, ported to Flutter, with two additions that make sense for 2026: a CLI-first surface for terminal-native developers and a 9-tool MCP server so AI coding agents can read the timeline directly.

## Part of the Magic SDK suite

Telescope is one of seven packages in the [FlutterSDK Magic suite](https://fluttersdk.com), a Laravel-inspired Flutter ecosystem:

- **[magic](https://pub.dev/packages/magic)** — Laravel-style framework (facades, ORM, providers, controllers, routing)
- **[wind](https://pub.dev/packages/fluttersdk_wind)** — Tailwind-style className UI primitives for Flutter
- **[fluttersdk_artisan](https://pub.dev/packages/fluttersdk_artisan)** — Pure Dart CLI + MCP substrate that telescope extends
- **[fluttersdk_dusk](https://pub.dev/packages/fluttersdk_dusk)** — E2E gesture / snapshot driver via VM extensions
- **fluttersdk_telescope** (this package) — Runtime observability via VM extensions + MCP
- **[magic_tinker](https://pub.dev/packages/magic_tinker)** — Connected REPL into the running app
- **[magic_starter](https://pub.dev/packages/magic_starter)** — Auth / profile / teams scaffolding

## License

MIT, see [LICENSE](LICENSE) for details.

---

<p align="center">
  <sub>Built with care by <a href="https://github.com/fluttersdk">FlutterSDK</a></sub><br/>
  <sub>If Telescope saves you debugging time, <a href="https://github.com/fluttersdk/telescope">give it a star</a>, it helps others discover it.</sub>
</p>
