# Getting Started

Everything you need to add `fluttersdk_telescope` to your project, wire the watchers,
and start inspecting runtime state from the CLI or an MCP-connected AI agent.

## Pick your path

- [**Installation**](installation): Add fluttersdk_telescope to a Flutter project step by step.
- [**Quickstart**](quickstart): 3-step end-to-end walkthrough from install to first MCP tool call.

## What is fluttersdk_telescope?

Telescope is a passive runtime inspector for Flutter apps. It registers a set of watchers and VM
Service extensions at startup, captures every HTTP request, log line, exception, `debugPrint` call,
DB query, and Magic-framework lifecycle event into ring buffers, then surfaces those buffers through
CLI commands and MCP tools without ever modifying app behavior.

One `telescope:install` command wires everything end-to-end. Telescope ships its own
bootstrap CLI entry point so the command works from a fresh consumer without any prior
`fluttersdk_artisan` wiring:

```bash
flutter pub add fluttersdk_telescope
dart run fluttersdk_telescope telescope:install
```

The command scaffolds the consumer artisan harness if it is missing, runs
`plugin:install fluttersdk_telescope`, and patches `lib/main.dart` so
`TelescopePlugin.install()` runs at startup inside a `kDebugMode` guard. Release builds
tree-shake the entire subsystem; there is zero production overhead. The guard belongs to the call
site: `kDebugMode` is what the installer writes, and `!kReleaseMode` is the guard to use when profile
builds should carry telescope too (see [Call-site guard](../watchers/index.md#call-site-guard)).

After install, the artisan native AOT launcher at `./bin/fsa` gives ~110ms warm startup
for every subsequent telescope command (`./bin/fsa telescope:tail`, etc.).

## Requirements

| Dependency | Minimum Version | Notes |
|:-----------|:----------------|:------|
| Dart SDK | `>= 3.4.0` | Required. |
| Flutter SDK | `>= 3.22.0` | Required. Telescope needs the Flutter runtime for VM Service extensions. |
| fluttersdk_artisan | `^0.0.19` | Pulled in transitively by telescope; the install command and MCP tools work without prior setup. |
| Magic stack | optional | Enables 6 additional watchers: HTTP facade, models, cache, events, gates, queries. |

Telescope is a development package: it must never run in a release build. A `kDebugMode` or
`!kReleaseMode` guard at the consumer install site is load-bearing, because all release-mode
tree-shaking depends on it. Telescope itself installs no guard.

## What gets captured

Out of the box after `telescope:install`, Telescope captures:

- **Logs**: all `package:logging` records via `LogWatcher` (auto-installed).
- **Exceptions**: uncaught errors via `ExceptionWatcher` (opt-in, chain-preserves Sentry/Bugsnag).
- **debugPrint output**: via `DumpWatcher` (opt-in, chain-preserves prior override).

With the Magic stack (`MagicTelescopeIntegration.install()` from `magic_devtools`):

- **HTTP traffic** through the Magic `Http` facade.
- **Model lifecycle**: create, save, delete events on Magic Eloquent models.
- **Cache operations**: hit, miss, put, forget, flush via the `Cache` facade.
- **In-app events** dispatched through `Event.dispatch`.
- **Gate checks**: every `Gate.allows` / `Gate.denies` call with result + user id.
- **DB queries**: SQL, bindings, and execution time via the magic database connector.

## Host features

- [**Redaction**](redaction): the credential lists and `TelescopeRedaction.redactor`, the host hook that
  masks every log, event, exception and HTTP record at insert.
- [**File sink**](file-sink): `TelescopeFileSink`, a rotating JSONL timeline on disk that writes only
  redacted records, read back through `telescope:files`.
- [**Buffers**](buffers): per-kind capacity with `TelescopeStore.setCapacity`, the `atUs` clock, and how
  `limit` and `minLevel` behave.
- [**Cursor and filters**](../mcp/cursor-and-filters): `since`, `type`, `logger` and `cursor` on the read
  extensions, and `--json` / `--follow` on the CLI.

## Next steps

- New here? Start with [Installation](installation).
- Already installed? Run the [Quickstart](quickstart).
- Full reference at [fluttersdk.com/telescope](https://fluttersdk.com/telescope).
