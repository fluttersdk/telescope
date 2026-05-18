# fluttersdk_telescope

Passive runtime inspector for Flutter apps: HTTP capture, log sink, exception capture, debugPrint capture, Magic model/cache/event/gate watchers, and an in-app overlay dashboard.

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
| `MagicCacheWatcher` | Magic `Cache` facade reads, writes, and misses | No | Register via `TelescopePlugin.registerWatcher(MagicCacheWatcher())`. Requires Magic framework. |
| `MagicEventWatcher` | Events dispatched through the Magic `Event` facade | No | Register via `TelescopePlugin.registerWatcher(MagicEventWatcher())`. Requires Magic framework. |
| `MagicGateWatcher` | `Gate.allows` / `Gate.denies` authorization checks | No | Register via `TelescopePlugin.registerWatcher(MagicGateWatcher())`. Requires Magic framework. |

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

## Quick Start

### 1. Add the dependency

```yaml
# pubspec.yaml
dependencies:
  fluttersdk_telescope:
    path: ../path/to/fluttersdk_telescope
```

### 2. Install in `main.dart`

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

### 3. Register the Artisan provider (MCP tools)

In `bin/artisan.dart`, register `TelescopeArtisanProvider` so the 7 `telescope_*` MCP tools are visible to Claude Code and other MCP clients:

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

Magic-stack app that exercises all 8 watchers including the Magic-specific adapters: `MagicHttpFacadeAdapter` (Http facade traffic), `MagicModelWatcher` (Eloquent lifecycle), `MagicCacheWatcher` (Cache facade), `MagicEventWatcher` (Event.dispatch calls), and `MagicGateWatcher` (Gate authorization checks). Use the artisan MCP server from this directory to verify all 7 `telescope_*` MCP tools surface correctly.

```bash
cd example_magic && flutter run -d chrome
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
