# Changelog

All notable changes to this project will be documented in this file.

This project follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html). Entries follow the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) shape.

---

## [Unreleased]

### Changed

- `telescope:install` magic-detect branch now injects `import 'package:magic/telescope_integration.dart';` instead of `import 'package:magic/magic.dart';`. Pairs with magic 1.0.0-alpha.15 which extracts the integration class into a dedicated sub-barrel.

### Removed

- `magic: ^1.0.0-alpha` dev_dependency dropped. The package is now vanilla-Flutter clean with zero `magic` references in production or default-test surface. Magic-stack consumers continue to opt into `package:magic/telescope_integration.dart` from the magic repo via the install command's runtime detection.
- `pubspec_overrides.yaml` file deleted. All three former path overrides (`fluttersdk_artisan`, `fluttersdk_dusk`, `magic`) are gone; artisan now resolves from pub.dev hosted (`^0.0.2`) and dusk + magic are no longer dev dependencies.
- `test/src/magic/` integration test directory (6 files: `magic_cache_watcher_test.dart`, `magic_event_watcher_test.dart`, `magic_gate_watcher_test.dart`, `magic_http_facade_adapter_test.dart`, `magic_model_watcher_test.dart`, `magic_query_watcher_test.dart`) deleted. Magic-stack adapter and watcher contract regression now lives in the magic repo.
- `dart_test.yaml` `magic` tag definition + 4-line comment block removed. The `integration` tag remains as the sole entry under `tags:`.
- `--exclude-tags=integration,magic` reduced to `--exclude-tags=integration` in `.github/workflows/ci.yml` and `.github/workflows/publish.yml`. Agent-instruction files (`.github/copilot-instructions.md`, `.github/instructions/tests.instructions.md`, `.claude/rules/tests.md`) cleaned of magic-tag references in lockstep.
- `example_magic/` example directory (154 files) deleted along with its `.pubignore` exclusion block; the vanilla `example/` directory stays as the sole example tree.

---

## [0.0.1] - 2026-05-20

Initial public release of `fluttersdk_telescope`. Passive runtime inspector for Flutter apps with a framework-agnostic core and optional Magic-stack integration. Plugin of `fluttersdk_artisan` ^0.0.1.

### Watchers

9 watchers across vanilla Flutter and Magic-stack:
- `LogWatcher` (auto-installed): `package:logging` Logger calls captured to the `logs` ring buffer.
- `ExceptionWatcher`: `FlutterError.onError` + `PlatformDispatcher.instance.onError`, chain-preserve previous handlers.
- `DumpWatcher`: `debugPrint` capture (vanilla Flutter); debug-only.
- `MagicHttpFacadeAdapter`: Magic `Http` facade interceptor.
- `MagicModelWatcher`: `ModelCreated` / `ModelSaved` / `ModelDeleted` events from Magic.
- `MagicCacheWatcher`: `CacheHit` / `CacheMiss` / `CachePut` / `CacheForget` / `CacheFlush` events.
- `MagicEventWatcher`: curated event subscription (auth, db connection, gate-define).
- `MagicGateWatcher`: `GateAccessChecked` event after every `Gate.allows` / `Gate.denies`.
- `MagicQueryWatcher`: `QueryExecuted` event from the magic database connector.

### Records

9 immutable record types: `HttpRequestRecord`, `LogRecordEntry`, `ExceptionRecord`, `MagicModelRecord`, `MagicCacheRecord`, `EventRecord`, `GateRecord`, `DumpRecord`, `QueryRecord`.

### 9-buffer TelescopeStore

Per-buffer Queue<T> (O(1) ends) + StreamController<T>.broadcast() for live tail. Default capacity 500 entries per buffer (settable via `setCapacity(buffer, capacity)`). `clear()` flushes all 9 atomically.

### VM Service extensions (11)

`ext.telescope.requests`, `.console`, `.exceptions`, `.events`, `.gates`, `.dumps`, `.queries`, `.caches`, `.clear`, `.pause`, `.resume`. Every registration goes through `registerExtensionIdempotent` (from `fluttersdk_artisan`) for hot-restart safety.

### MCP tools (9)

`telescope_tail`, `telescope_requests`, `telescope_exceptions`, `telescope_clear`, `telescope_events`, `telescope_gates`, `telescope_dumps`, `telescope_queries`, `telescope_caches`. Each is a `McpToolDescriptor` const instance contributed via `TelescopeArtisanProvider.mcpTools()`.

### CLI commands (6)

`telescope:install`, `telescope:tail`, `telescope:requests`, `telescope:queries`, `telescope:caches`, `telescope:clear`. `telescope:install` is a one-shot bootstrap that scaffolds the consumer artisan harness, runs `plugin:install fluttersdk_telescope`, and injects `TelescopePlugin.install()` into `lib/main.dart` (Magic-stack anchor or vanilla `runApp` anchor).

### Three public contracts

- `TelescopeWatcher`: `name` getter + `install()` + `uninstall()`.
- `TelescopeHttpAdapter`: same 3-method shape + optional `pendingCount` getter (default 0).
- `McpToolDescriptor`: const-constructible; shape owned by `fluttersdk_artisan`.

### TelescopeStore extension surface

- `pendingHttpCount` getter sums `TelescopeHttpAdapter.pendingCount` across every registered adapter; consumed by `ext.dusk.wait_for_network_idle` for network-idle detection.

### CI + automated publishing

- `.github/workflows/ci.yml`: format + analyze + flutter test (--exclude-tags integration,magic) + 80% line-coverage floor (lcov + awk gate) + codecov upload + dart pub publish --dry-run.
- `.github/workflows/publish.yml`: SemVer tag push triggers validate -> pub.dev publish via the official `dart-lang/setup-dart/.github/workflows/publish.yml@v1` reusable workflow with OIDC authentication + github-release job auto-extracting CHANGELOG entry.
- `.github/dependabot.yml`: weekly pub root + weekly github-actions bumps.

### Documentation

- `README.md` two-path Quick Start (one-shot self-bootstrap via `dart run fluttersdk_telescope telescope:install`; manual wiring for consumers who prefer to drive the artisan dispatcher by hand). After install, the consumer's `./bin/fsa` native AOT launcher is the recommended entry point for every subsequent telescope command.
- `doc/` tree: `getting-started/`, `watchers/`, `mcp/`.
- `llms.txt` at repo root per llmstxt.org spec.
- `skills/fluttersdk-telescope/` LLM-agent skill (SKILL.md + 2 references).

### Compatibility

- Dart SDK >=3.4.0 <4.0.0; Flutter >=3.22.0.
- Platforms: Android, iOS, macOS, Linux, Windows, Web (debug-only on every platform; release builds tree-shake the entire telescope subsystem via `kDebugMode` gate).
- Magic-stack integration optional. Vanilla Flutter consumers use Dio adapter + LogWatcher + ExceptionWatcher + DumpWatcher with no Magic dependency.

### Test coverage

307+ tests green at release time. 80% line coverage floor enforced in CI.
