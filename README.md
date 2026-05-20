# fluttersdk_telescope

Passive runtime inspector for Flutter apps: HTTP, log, exception, debugPrint, DB query, and Magic model / cache / event / gate capture, surfaced over VM Service extensions to CLI + MCP tools.

---

> **Alpha Release**: Telescope is under active development. APIs may change before stable.

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
  fluttersdk_telescope:
    path: ../path/to/fluttersdk_telescope
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

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
