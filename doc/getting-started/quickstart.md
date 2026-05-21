# Quickstart

A 3-step walkthrough taking a fresh Flutter project from zero to a working Telescope setup
with runtime buffers populated and the first MCP tool call returning live data.

Prerequisites: Flutter SDK 3.22+, Dart SDK 3.4+, a Flutter project (any vanilla
`flutter create` output works). `fluttersdk_artisan` is pulled in transitively by
telescope; you do not need to install it separately. The `telescope:install` command
scaffolds `bin/dispatcher.dart` for you on first run.

---

### 1. Install Telescope

Add the dependency, then run the one-shot install through telescope's own bootstrap entry
point. The install command scaffolds the artisan harness if needed, registers the plugin,
and patches `lib/main.dart` with the `kDebugMode`-guarded install call:

```bash
flutter pub add fluttersdk_telescope
dart run fluttersdk_telescope telescope:install
```

The command outputs a summary of every file it touched. For a fresh project the summary
looks like:

```
[plugin:install] registered TelescopeArtisanProvider
[main.dart]      injected TelescopePlugin.install() before framework init
[main.dart]      injected MagicTelescopeIntegration.install() after Magic.init() (when using Magic framework)
telescope:install done
```

When using the Magic framework, `MagicTelescopeIntegration.install()` is also injected after
`Magic.init()` so all 9 watchers activate automatically. On a vanilla Flutter app only
the core watchers (`LogWatcher`, plus any you opt into manually) are wired.

Verify the provider registered correctly. From now on, the artisan fast-cli at `./bin/fsa`
(native AOT, ~110ms warm) is the recommended entry point for every subsequent command:

```bash
./bin/fsa list
```

You should see the `telescope:` namespace with 6 commands: `telescope:install`,
`telescope:tail`, `telescope:requests`, `telescope:queries`, `telescope:caches`,
`telescope:clear`. The same surface is also reachable via the ~3s cold-start fallbacks
`dart run fluttersdk_telescope list` and `dart run fluttersdk_artisan list`.

---

### 2. Start the app and generate traffic

Boot the Flutter app via artisan so the VM Service URI is recorded to the state file.
Artisan resolves the running instance from this file for every subsequent CLI and MCP call.

```bash
./bin/fsa start --device=chrome
```

The command scrapes the VM Service URI from `flutter run` output, normalizes it to a
WebSocket address, and writes the full process state (PID, URI, device, project root)
to `~/.artisan/state.json`.

With the app running, navigate the UI to generate HTTP traffic, logs, and any exceptions.
When using the Magic framework, every HTTP call through the `Http` facade, every model save,
and every cache read goes straight into the Telescope ring buffers. On a vanilla Flutter app,
`package:logging` output and `debugPrint` calls fill the log and dump buffers.

You can also exercise the watchers programmatically from the app:

```dart
// Generates a LogRecordEntry in the console buffer.
Logger('MyFeature').info('quickstart test log');

// Generates a DumpRecord in the dump buffer.
debugPrint('quickstart test dump');
```

---

### 3. Query the buffers from Claude Code (MCP)

Start the artisan MCP server. When your project has `.mcp.json` wired with
`dart run fluttersdk_artisan:mcp` as the entry point (written by
`fluttersdk_artisan mcp:install`), Claude Code launches the server automatically on attach.
To start it manually:

```bash
./bin/fsa mcp:serve
```

Inside a Claude Code session, the 9 `telescope_*` tools are now available. A typical
inspection flow:

```
[agent] telescope_tail {}
```

Returns the most recent log records from the ring buffer, newest first. Filter by level:

```
[agent] telescope_tail { "level": "warning", "limit": 20 }
```

Inspect HTTP traffic:

```
[agent] telescope_requests {}
```

Returns every captured HTTP request with method, URL, status code, duration in ms, request
headers, and a body snippet. Useful for verifying what the app actually sent to the API.

Check for uncaught exceptions:

```
[agent] telescope_exceptions {}
```

Review DB queries with timings:

```
[agent] telescope_queries {}
```

Clear all buffers before the next test scenario:

```
[agent] telescope_clear {}
```

All 9 tools follow the same pattern: they query the `ext.telescope.*` VM Service
extensions registered by `registerAllTelescopeExtensions()` at startup. No source changes
are needed between queries; the buffers update passively as the app runs.

---

## What's next?

- Read the full [Installation](installation) doc for manual wiring options and the
  `DioHttpAdapter` setup for vanilla Flutter.
- Browse the watcher catalog at [fluttersdk.com/telescope/watchers](https://fluttersdk.com/telescope/watchers)
  to learn which watchers are opt-in and how chain-preservation works with Sentry and Bugsnag.
- See the full MCP tool input schemas at [fluttersdk.com/telescope/mcp](https://fluttersdk.com/telescope/mcp).

---

All three steps above use only the `fluttersdk_telescope ^0.0.1` package and its
`fluttersdk_artisan` dependency. No additional packages are required for the core
watcher surface. Magic-specific watchers activate automatically when the Magic stack
is present and `MagicTelescopeIntegration.install()` is called.
