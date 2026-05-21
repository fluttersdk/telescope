# Watchers

Telescope ships 9 watcher units across three categories. Each unit implements one of two contracts:
`TelescopeWatcher` (for event-driven and hook-based capture) or `TelescopeHttpAdapter` (for HTTP
traffic capture). All units feed the matching ring buffer inside `TelescopeStore` and expose their
data via a VM Service extension method.

## kDebugMode gating

The consumer is responsible for gating the entire telescope install behind `kDebugMode`:

```dart
if (kDebugMode) {
  TelescopePlugin.install();
  // register additional watchers here
}
```

This single gate tree-shakes the entire subsystem in release builds (dart2js for web, dart2native
for mobile/desktop AOT). Individual watchers do not need their own gate except `DumpWatcher`, which
has an additional internal guard (see below).

## Chain-preserve pattern

Any watcher that overrides a global Dart/Flutter hook saves the previous handler before replacing it
and calls it inside the new handler body. On `uninstall()`, the previous handler is restored
symmetrically. This is the Sentry/Bugsnag coexistence contract: telescope captures the record AND
forwards to whatever was registered before it. The numbered step comments in `ExceptionWatcher` are
the canonical reference for this pattern:

```dart
// 1. Chain-preserve FlutterError.onError (sync framework errors).
_previousOnError = FlutterError.onError;
FlutterError.onError = (details) {
  TelescopeStore.recordException(...);
  _previousOnError?.call(details);
};

// 2. Chain-preserve PlatformDispatcher.instance.onError (async + isolate errors).
_previousPlatformOnError = PlatformDispatcher.instance.onError;
PlatformDispatcher.instance.onError = (error, stack) {
  TelescopeStore.recordException(...);
  return _previousPlatformOnError?.call(error, stack) ?? true;
};
```

---

## Framework-agnostic watchers

These three units are part of the `fluttersdk_telescope` core package. They have no dependency on
Magic or any other application framework.

### LogWatcher

| Field | Value |
|---|---|
| Contract | `TelescopeWatcher` |
| Name | `log` |
| Auto-install | Yes (auto-registered by `TelescopePlugin.install()`) |
| Ring buffer | `TelescopeStore._logs` |
| VM extension | `ext.telescope.console` |
| Opt-out | Call `TelescopePlugin.install()` then remove it by not calling `LogWatcher().install()` directly; or skip the default auto-install path and register manually |

Subscribes to `Logger.root.onRecord` from `package:logging`. Every log record that flows through
the root logger (at any level) is converted to a `LogRecordEntry` and pushed to the store.

`hierarchicalLoggingEnabled` is set to `true` during install so named child loggers (`Logger('http')`,
`Logger('auth')`, etc.) funnel through root. Install is idempotent: a second call when the
subscription is already live is a no-op.

If the app does not use `package:logging`, the watcher is dormant (no records flow through
`Logger.root`). It is still registered because adding `package:logging` later immediately benefits
from capture without any telescope config change.

Registration (auto-installed, shown for completeness):

```dart
TelescopePlugin.install(); // LogWatcher registered automatically
```

Manual opt-out (skip auto-registration) is not exposed in the V1 API; file a feature request if
selective watcher exclusion is needed.

---

### ExceptionWatcher

| Field | Value |
|---|---|
| Contract | `TelescopeWatcher` |
| Name | `exception` |
| Auto-install | No (opt-in via `TelescopePlugin.registerWatcher(ExceptionWatcher())` after install) |
| Ring buffer | `TelescopeStore._exceptions` |
| VM extension | `ext.telescope.exceptions` |
| Opt-out | Simply do not register; absent registration means no error capture. To coexist with Sentry / Bugsnag, register telescope FIRST so the chain-preserve wraps the next handler. |

Hooks both `FlutterError.onError` (synchronous framework and widget errors) and
`PlatformDispatcher.instance.onError` (asynchronous errors, isolate errors, plugin-originated
errors). Both hooks follow the chain-preserve pattern.

The `PlatformDispatcher.onError` handler returns `_previousPlatformOnError?.call(...) ?? true`.
When a previously-registered handler (e.g. Sentry) returns `false` to signal a fatal error and let
the native crash reporter take over, telescope preserves that semantics. When no previous handler
exists, the default `true` (handled) matches pre-install behavior.

On `uninstall()`, both handlers are restored to exactly the values they held before `install()` was
called. Calling `install()` while already installed is a no-op.

Registration (opt-in; add after `TelescopePlugin.install()`):

```dart
TelescopePlugin.install();
TelescopePlugin.registerWatcher(ExceptionWatcher());
```

Coexistence with Sentry (the chain-preserve contract means order matters; install Sentry first):

```dart
SentryFlutter.init((_) {});         // registers FlutterError.onError + PlatformDispatcher.onError
if (kDebugMode) {
  TelescopePlugin.install();        // wraps Sentry's handlers; Sentry still fires
}
```

---

### DumpWatcher

| Field | Value |
|---|---|
| Contract | `TelescopeWatcher` |
| Name | `dump` |
| Auto-install | No (opt-in via `TelescopePlugin.registerWatcher(DumpWatcher())`) |
| Ring buffer | `TelescopeStore._dumps` |
| VM extension | `ext.telescope.dumps` |
| Opt-out | Do not register it; it is never auto-installed |

Captures all `debugPrint` output by replacing the global `debugPrint` callback with an interceptor.
The interceptor records a `DumpRecord` AND calls the previous `debugPrint` value (chain-preserve).
On `uninstall()`, the previous callback is restored exactly.

Internal `kDebugMode` gate: `install()` is a no-op in release builds unless `allowInRelease` is set
to `true` before calling `install()`. This gate is load-bearing: in release builds `debugPrint`
itself is a no-op, so capture would produce empty records; the gate makes the intent explicit and
ensures AOT tree-shaking eliminates the interceptor.

Registration:

```dart
if (kDebugMode) {
  TelescopePlugin.install();
  TelescopePlugin.registerWatcher(DumpWatcher()); // opt-in
}
```

Opt-out: simply omit the `registerWatcher(DumpWatcher())` call.

---

## HTTP adapters

HTTP adapters implement `TelescopeHttpAdapter` (three methods: `name`, `install`, `uninstall`, plus
the optional `pendingCount` getter). They feed `TelescopeStore.recordHttp` and their in-flight
counts sum into `TelescopeStore.pendingHttpCount` (consumed by Dusk's `wait_for_network_idle`).

### DioHttpAdapter

| Field | Value |
|---|---|
| Contract | `TelescopeHttpAdapter` |
| Name | `dio` |
| Auto-install | No (opt-in via `TelescopePlugin.registerHttpAdapter(DioHttpAdapter())`) |
| Ring buffer | `TelescopeStore._http` |
| VM extension | `ext.telescope.requests` |
| Opt-out | Do not register it |

Vanilla Dio adapter for Flutter apps that use raw Dio instances (not the Magic Http facade). V1
ships as a stub: the actual Dio interceptor subclass requires `package:dio`, which is not in
telescope's own pubspec to keep the core package HTTP-library-agnostic. The consumer adds `package:dio`
to their own pubspec and wires the adapter by calling the static helper:

```dart
// consumer pubspec: dio: ^5.x
import 'package:fluttersdk_telescope/telescope.dart';

// After constructing your Dio instance:
dio.interceptors.add(_MyTelescopeInterceptor());

class _MyTelescopeInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    DioHttpAdapter.recordRequest(
      url: response.requestOptions.uri.toString(),
      method: response.requestOptions.method,
      statusCode: response.statusCode ?? 0,
      durationMs: ...,
    );
    handler.next(response);
  }
}

// Register so the adapter shows up in the store's adapter list:
TelescopePlugin.registerHttpAdapter(DioHttpAdapter());
```

V1.x will move the Dio-coupled glue into a `fluttersdk_telescope_dio` sub-package so the core stays
HTTP-library-agnostic.

---

### MagicHttpFacadeAdapter

| Field | Value |
|---|---|
| Contract | `TelescopeHttpAdapter` |
| Name | `magic_http_facade` |
| Auto-install | Yes (registered by `MagicTelescopeIntegration.install()`) |
| Ring buffer | `TelescopeStore._http` |
| VM extension | `ext.telescope.requests` |
| Opt-out | Call `TelescopePlugin.install()` without calling `MagicTelescopeIntegration.install()` |

Captures every request flowing through Magic's `network` driver by registering a
`MagicNetworkInterceptor` on the driver. The interceptor pairs `onRequest` (start stopwatch) with
`onResponse`/`onError` (stop stopwatch, emit `HttpRequestRecord`) via a FIFO in-flight list.

Attribution is heuristic (`attributedHeuristically: true`) because the `MagicNetworkInterceptor`
contract does not carry a correlation handle across `onRequest`/`onResponse` callbacks; best-effort
matching by call order.

`pendingCount` returns the current length of the in-flight FIFO, surfaced into
`TelescopeStore.pendingHttpCount` for Dusk's network-idle detection.

Registration (via `MagicTelescopeIntegration`, the only documented entry point):

```dart
if (kDebugMode) {
  TelescopePlugin.install();
  MagicTelescopeIntegration.install(); // registers MagicHttpFacadeAdapter + 5 watchers
}
```

`install()` is a no-op if `Magic.bound('network')` returns false (called too early, before
`Magic.init()` completes). Call `MagicTelescopeIntegration.install()` after `Magic.init()`.

---

## Magic-stack watchers

These five watchers are shipped inside the `magic` package via `MagicTelescopeIntegration`. They
are not part of the `fluttersdk_telescope` core. All five are registered by a single
`MagicTelescopeIntegration.install()` call.

### MagicModelWatcher

| Field | Value |
|---|---|
| Contract | `TelescopeWatcher` |
| Name | `magic_model` |
| Auto-install | Yes (via `MagicTelescopeIntegration.install()`) |
| Ring buffer | `TelescopeStore._models` |
| VM extension | `ext.telescope.requests` (via models key; MCP tool: `telescope_models`) |
| Opt-out | Do not call `MagicTelescopeIntegration.install()` |

Subscribes to `ModelCreated`, `ModelSaved`, and `ModelDeleted` events dispatched by Magic's
`EventDispatcher`. Each event is converted to a `MagicModelRecord` carrying: `modelClass` (runtime
type name), `event` tag (`created`/`saved`/`deleted`), `modelKey` (stringified primary key), `time`,
and `attributes` (snapshot of `model.attributes` at capture time).

Registration:

```dart
if (kDebugMode) {
  TelescopePlugin.install();
  MagicTelescopeIntegration.install(); // MagicModelWatcher is included
}
```

`uninstall()` is a no-op: `EventDispatcher` has no per-listener removal API. Tests that need a
clean dispatcher call `EventDispatcher.instance.clear()` in their `setUp`.

---

### MagicCacheWatcher

| Field | Value |
|---|---|
| Contract | `TelescopeWatcher` |
| Name | `magic_cache` |
| Auto-install | Yes (via `MagicTelescopeIntegration.install()`) |
| Ring buffer | `TelescopeStore._caches` |
| VM extension | `ext.telescope.caches` |
| Opt-out | Do not call `MagicTelescopeIntegration.install()` |

Subscribes to five cache lifecycle events emitted by Magic's `CacheManager`: `CacheHit`, `CacheMiss`,
`CachePut`, `CacheForget`, and `CacheFlush`. Each event is converted to a `MagicCacheRecord` carrying
`operation` (`hit`/`miss`/`put`/`forget`/`flush`), `key` (or `*` for flush), `time`, and `ttl`
(present only for `CachePut`).

Registration:

```dart
if (kDebugMode) {
  TelescopePlugin.install();
  MagicTelescopeIntegration.install(); // MagicCacheWatcher is included
}
```

`uninstall()` is a no-op (same `EventDispatcher` constraint as `MagicModelWatcher`).

---

### MagicEventWatcher

| Field | Value |
|---|---|
| Contract | `TelescopeWatcher` |
| Name | `magic_event` |
| Auto-install | Yes (via `MagicTelescopeIntegration.install()`) |
| Ring buffer | `TelescopeStore._events` |
| VM extension | `ext.telescope.events` |
| Opt-out | Do not call `MagicTelescopeIntegration.install()` |

Subscribes to a curated set of Magic app-lifecycle events: `AuthLogin`, `AuthLogout`, `AuthFailed`,
`AuthRestored` (auth lifecycle), `DatabaseConnected` (database connection), and `GateAbilityDefined`,
`GateBeforeRegistered` (gate definition). Model lifecycle events are excluded (owned by
`MagicModelWatcher`) and gate-result events are excluded (owned by `MagicGateWatcher`) to keep each
record on a single channel.

Current payload is the empty map for every event type. Per-event field extraction is deferred to a
follow-up release while the `EventRecord` wire shape stabilises.

Registration:

```dart
if (kDebugMode) {
  TelescopePlugin.install();
  MagicTelescopeIntegration.install(); // MagicEventWatcher is included
}
```

`uninstall()` is a no-op (same `EventDispatcher` constraint).

---

### MagicGateWatcher

| Field | Value |
|---|---|
| Contract | `TelescopeWatcher` |
| Name | `magic_gate` |
| Auto-install | Yes (via `MagicTelescopeIntegration.install()`) |
| Ring buffer | `TelescopeStore._gates` |
| VM extension | `ext.telescope.gates` |
| Opt-out | Do not call `MagicTelescopeIntegration.install()` |

Subscribes to `GateAccessChecked`, which covers both `Gate.allows` and `Gate.denies` outcomes via
its `allowed: bool` field. `GateAccessDenied` is intentionally not subscribed to avoid
double-recording every denial.

Each event is converted to a `GateRecord` with two shape coercions:
- `arguments` (single dynamic on the event) is wrapped into `List<Object?>` of length 1.
- `user.id` (dynamic primary key) is stringified; null user or null id both collapse to
  `userId: null`.

Magic model arguments are converted via `toMap()`; primitives and collections pass through as-is;
anything else falls back to `toString()`.

Registration:

```dart
if (kDebugMode) {
  TelescopePlugin.install();
  MagicTelescopeIntegration.install(); // MagicGateWatcher is included
}
```

`uninstall()` is a no-op (same `EventDispatcher` constraint).

---

### MagicQueryWatcher

| Field | Value |
|---|---|
| Contract | `TelescopeWatcher` |
| Name | `magic_query` |
| Auto-install | Yes (via `MagicTelescopeIntegration.install()`) |
| Ring buffer | `TelescopeStore._queries` |
| VM extension | `ext.telescope.queries` |
| Opt-out | Do not call `MagicTelescopeIntegration.install()` |

Subscribes to `QueryExecuted`, dispatched by Magic's `QueryBuilder` after every SQL run. Each event
is converted to a `QueryRecord` carrying: `sql` (the full SQL string), `bindings` (parameter list),
`timeMs` (execution duration in milliseconds), `connectionName` (driver connection identifier), and
`time` (capture timestamp).

Surfaced via the `telescope:queries` CLI command and the `telescope_queries` MCP tool.

Registration:

```dart
if (kDebugMode) {
  TelescopePlugin.install();
  MagicTelescopeIntegration.install(); // MagicQueryWatcher is included
}
```

`uninstall()` is a no-op (same `EventDispatcher` constraint as the other Magic-stack watchers).
