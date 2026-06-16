# Changelog

All notable changes to this project will be documented in this file.

This project follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html). Entries follow the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) shape.

---

## [Unreleased]

### Changed

- **`telescope:install` now injects `import 'package:magic_devtools/telescope.dart';` and gates the Magic-stack wiring on the `magic_devtools` dependency** instead of the removed `package:magic/telescope_integration.dart`. Coordinated with the `magic_devtools` extraction that moved `MagicTelescopeIntegration` out of the magic core package. The injected `MagicTelescopeIntegration.install()` call and all other wiring are unchanged.

## [0.0.4] - 2026-06-17

### Changed

- **`fluttersdk_artisan` constraint bumped `^0.0.6` -> `^0.0.8`.** Required for co-installability with `fluttersdk_dusk` 0.0.7, which declares `fluttersdk_artisan: ^0.0.8`. Without this bump, a downstream package listing both `fluttersdk_dusk: ^0.0.7` and `fluttersdk_telescope` would fail pub dependency resolution. No public API change; constraint only.

## [0.0.3] - 2026-05-28

### Added

- Skill v0.0.3: new `## 8. Community: star + issue (optional, once per session)` section in `skills/fluttersdk-telescope/SKILL.md` plus a new `skills/fluttersdk-telescope/references/community.md` reference page. Trigger split: star CTA fires after the user confirms a telescope task end-to-end (captured HTTP record after a gesture, level-filtered tail slice, surfaced uncaught exception, `clear`-then-repro delta, or clean `telescope:install`); issue CTA fires only on a genuine telescope-side bug (malformed MCP envelope, `kInvalidParams` for documented params, `TelescopeStore` losing entries before the 500-cap, `clear` returning anything but `{"cleared": true}`, shipped watchers throwing on a clean install, `telescope:install` exiting non-zero on a fresh consumer, or `registerExtensionIdempotent` violating idempotency). Issue CTA explicitly excludes the documented wired-but-empty buffers, swallowed `try / catch` invisibility, consumer-app exceptions, raw `dart:io HttpClient` traffic gaps, the missing `telescope_models` MCP tool, and FIFO eviction past 500. Preflight gates on `gh` presence and auth; failure prints the URL only, no `open` / `xdg-open` / `start`. Both CTAs are prose-permission (not `AskUserQuestion`), maximum one star and one issue per session, declining one suppresses only that CTA. Labels: only `bug` is applied (the `agent-reported` label does not exist on `fluttersdk/telescope`, drop the flag).
- Repo flow adopted GitHub Flow (single long-lived `master`; retired the `develop` accumulator). `CLAUDE.md` and `.github/copilot-instructions.md` now carry Golden Rule 7 plus a `## Branching` section documenting task-branch naming, squash-merge policy, and the release-tag shape. `delete_branch_on_merge: true` enabled on origin so merged branches auto-cleanup.

### Changed

- **`fluttersdk_artisan` constraint bumped `^0.0.4` -> `^0.0.6`.** Consumers were already pulling 0.0.6 transitively (via the post-install `fluttersdk_artisan: any` line the telescope:install bootstrap appends to the consumer pubspec); telescope's own dev resolution now tracks the same version so tests, format, and `pub publish --dry-run` run against the artisan that consumers actually execute. Picks up the 0.0.5 + 0.0.6 fixes: `_plugins.g.dart` AOT staleness detection, MCP `serverInfo.version` sync to `0.0.6`, atomic `.mcp.json` writes via `.tmp` + rename, the `mcp:install --invocation` plugin-aware fallback, and the `dusk_evaluate` VM-routed fix. Future artisan 0.0.7 will need a coordinated bump.
- **`telescope_*` MCP tool descriptions now state the actual wire shape ("oldest-first; last entry is newest").** Previously seven of the eight read tools claimed "Returns newest-first" while the handler delivered oldest-first; the SKILL.md Law 5 disclaimer ("presenter shorthand") that papered over the gap has been retired. Clients reading the description verbatim no longer assume a reversed order.
- `mcp:install` fallback now writes `dart run fluttersdk_telescope mcp:serve` when `bin/fsa` is absent (via the wrapper's `--invocation` pass-through to artisan's `mcp:install`, gated on the 0.0.6 trim-whitespace behavior).
- **`telescope:install` no longer depends on the AOT-compiled `bin/fsa`.** The chained subprocess calls (`install` + `plugin:install fluttersdk_telescope`) now spawn `dart run fluttersdk_telescope ...` directly through the telescope CLI wrapper, mirroring the Cat C subprocess pattern landed in `fluttersdk_dusk`. Consumers on a clean checkout (where fsa has not been compiled yet) can complete the bootstrap chain without a `ProcessException: No such file or directory` failure. **Behavior delta**: even consumers with `bin/fsa` scaffolded now invoke `plugin:install` through `dart run` (a few seconds slower than the fsa AOT proxy on a single `telescope:install` invocation). Requires `dart` on `PATH` (always true on a Flutter dev box). Matches dusk's unconditional `dart run` pattern for cross-plugin consistency.

### Fixed

- **`telescope_clear` MCP descriptor claimed it cleared "three ring buffers (http, logs, exceptions)" but the implementation has always wiped all 9 buffers atomically (per Core Law 6).** Rewrote the description and Usage bullets in `lib/src/telescope_artisan_provider.dart` to enumerate the 9 buffers (http, logs, exceptions, events, gates, dumps, queries, caches, magic models), document the `{"cleared": true}` envelope, and make the upstream-sink isolation (Sentry, Bugsnag still receive events) explicit. The wire behavior was already correct; this is a descriptor-string fix only.
- `bin/fluttersdk_telescope.dart` now forces `collectMcpTools: true` when dispatching `mcp:serve`, so `dart run fluttersdk_telescope mcp:serve` surfaces all 9 `telescope_*` MCP tools. Previously returned 0 plugin tools.

---

## [0.0.2] - 2026-05-22

### Fixed

- CHANGELOG correction. The `0.0.1` archive on pub.dev shipped with a populated `[Unreleased]` block left over from release prep: every entry listed there (magic dev-dep drop, `pubspec_overrides.yaml` removal, `test/src/magic/` deletion, `magic` tag cleanup in `dart_test.yaml` + CI workflows + agent-instruction files, `example_magic/` removal, sub-barrel import path swap in `telescope:install`) actually shipped INSIDE `0.0.1`; nothing was published before it. This `0.0.2` republishes the corrected CHANGELOG so the consolidated `0.0.1` history surfaces on pub.dev.
- README pinned-install snippet bumped from `^0.0.1` to `^0.0.2` so the example matches the published version.

### Unchanged

- No code, no test, no runtime behavior, no public API surface changed. `lib/`, `bin/`, `test/`, `example/`, and all 11 `ext.telescope.*` VM Service extensions plus 9 `telescope_*` MCP tools are byte-identical to `0.0.1`.

---

## [0.0.1] - 2026-05-22

Initial public release of `fluttersdk_telescope`. Passive runtime inspector for Flutter apps with a framework-agnostic core and optional Magic-stack integration. Plugin of `fluttersdk_artisan` ^0.0.4 (hosted-only; no path overrides). Vanilla-Flutter clean: zero `magic` references in the production or default-test surface. Magic-stack integration is opt-in via runtime detection in `telescope:install`, which injects `import 'package:magic/telescope_integration.dart';` and an `if (kDebugMode) MagicTelescopeIntegration.install();` block after `await Magic.init(` when the consumer's pubspec lists `magic:`.

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

- `.github/workflows/ci.yml`: format + analyze + flutter test (--exclude-tags integration) + 80% line-coverage floor (lcov + awk gate) + codecov upload + dart pub publish --dry-run.
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

249 tests green at release time across watchers, records, commands, extensions, and the artisan provider. 80% line coverage floor enforced in CI (current measured coverage 95.60%).
