# Telescope MCP Tool Reference

Catalog of every MCP tool contributed by `fluttersdk_telescope` via
`TelescopeArtisanProvider.mcpTools()`. All 9 tools use the `telescope_` prefix and dispatch
through `ext.telescope.*` VM Service extensions registered inside the running Flutter app by
`registerAllTelescopeExtensions()`.

**Requires a running app.** Every telescope tool dispatches via the VM Service. Boot the
app via the artisan fast-cli (`./bin/fsa start`) or the MCP equivalent (`artisan_start`)
and confirm `artisan_status` shows a live `vmServiceUri` before invoking these tools.

---

## Table of Contents

- [Common conventions](#common-conventions)
- [telescope_tail](#telescope_tail)
- [telescope_requests](#telescope_requests)
- [telescope_exceptions](#telescope_exceptions)
- [telescope_events](#telescope_events)
- [telescope_gates](#telescope_gates)
- [telescope_dumps](#telescope_dumps)
- [telescope_queries](#telescope_queries)
- [telescope_caches](#telescope_caches)
- [telescope_clear](#telescope_clear)
- [Related](#related)

---

## Common Conventions

All buffer-reading tools (every tool except `telescope_clear`) share these conventions:

- **Newest-first ordering.** The most recent record is always at index 0 of the returned array.
- **`limit` parameter.** All buffer tools accept an optional `limit: integer` parameter that caps
  the number of records returned. When omitted, the entire ring buffer is returned (subject to the
  ring-buffer capacity, typically 200-500 records depending on buffer type).
- **Empty array on empty buffer.** When the buffer holds no records (fresh start or after
  `telescope_clear`), the response is `{"records": []}`. This is not an error.
- **JSON envelope.** Every tool returns a JSON object. The outer shape is always
  `{"records": [...]}`. Individual record field shapes are documented per tool below.
- **Error shape.** On failure (app not running, VM Service unreachable), `McpServer` returns
  `CallToolResult` with `isError: true` and an actionable plain-text message.

---

## telescope_tail

Return recent log records from the running Flutter app.

Reads the Telescope log ring buffer populated by every `package:logging` `Logger` call in the app.
Use this to inspect what the app logged without scraping `flutter run` stdout via `artisan_logs`.

**VM Service extension:** `ext.telescope.console`

### Input Schema

| Parameter | Type | Required | Description |
|---|---|---|---|
| `limit` | integer | no | Maximum number of records to return, newest first. Omit for the whole buffer (cap enforced by ring-buffer size, typically 200). |
| `level` | string | no | Minimum log level to include. Common values: `FINE`, `INFO`, `WARNING`, `SEVERE`, `SHOUT`. Omit for all levels. |

### Output Shape

```json
{
  "records": [
    {
      "level": "WARNING",
      "levelValue": 900,
      "message": "Monitor check timed out after 30s",
      "loggerName": "MonitorController",
      "time": "2026-05-20T14:32:10.123Z",
      "error": "TimeoutException: ...",
      "stackTrace": "#0 MonitorController.check ..."
    }
  ]
}
```

| Field | Type | Always present | Description |
|---|---|---|---|
| `level` | string | yes | Log level name (e.g. `INFO`, `WARNING`, `SEVERE`) |
| `levelValue` | integer | yes | Numeric level value from `package:logging` |
| `message` | string | yes | Log message string |
| `loggerName` | string | yes | Name of the `Logger` instance that emitted the record |
| `time` | string | yes | ISO 8601 UTC timestamp |
| `error` | string | no | Error object stringified, when one was attached |
| `stackTrace` | string | no | Stack trace stringified, when one was attached |

### Example Invocations

```
# Last 10 log lines at any level
telescope_tail limit=10

# Last 20 WARNING-and-above entries
telescope_tail limit=20 level=WARNING

# All SEVERE entries in the buffer
telescope_tail level=SEVERE
```

### Related Tools

- `telescope_exceptions`: uncaught exceptions (not expected `try/catch` flows)
- `telescope_requests`: HTTP traffic
- `telescope_clear`: wipe the buffer before a repro

---

## telescope_requests

Return recent HTTP request records from the running Flutter app.

Reads the Telescope HTTP ring buffer populated by the Telescope Dio interceptor or any
`TelescopeHttpAdapter` the app installs (e.g. `MagicHttpFacadeAdapter` from the magic package).
Use this to debug API issues without instrumenting the app or watching network panels in DevTools.

**VM Service extension:** `ext.telescope.requests`

### Input Schema

| Parameter | Type | Required | Description |
|---|---|---|---|
| `limit` | integer | no | Maximum number of HTTP records to return, newest first. Omit for the whole buffer. |

### Output Shape

```json
{
  "records": [
    {
      "url": "https://api.example.com/monitors",
      "method": "GET",
      "statusCode": 200,
      "durationMs": 142,
      "isError": false,
      "timestamp": "2026-05-20T14:32:11.456Z",
      "requestHeaders": {
        "Authorization": "Bearer eyJ..."
      },
      "requestBody": null,
      "responseBody": "{\"data\": [...]}"
    }
  ]
}
```

| Field | Type | Always present | Description |
|---|---|---|---|
| `url` | string | yes | Full request URL |
| `method` | string | yes | HTTP method (`GET`, `POST`, etc.) |
| `statusCode` | integer | yes | HTTP status code; 0 when the call failed before a response |
| `durationMs` | integer | yes | Round-trip time in milliseconds |
| `isError` | boolean | yes | True when the adapter classified the call as failed |
| `timestamp` | string | yes | ISO 8601 UTC timestamp of when the request was recorded |
| `requestHeaders` | object | no | Request headers as a `Map<String, String>` |
| `requestBody` | string | no | Request body as a string, when present and readable |
| `responseBody` | string | no | Response body snippet, when present |
| `attributedHeuristically` | boolean | no | True when the adapter used best-effort FIFO attribution for concurrent requests |

### Example Invocations

```
# Last 5 HTTP requests
telescope_requests limit=5

# All requests in the buffer
telescope_requests
```

### Notes

- Only HTTP calls that go through an installed Telescope adapter are recorded. Raw
  `dart:io HttpClient` calls are invisible to this tool.
- Pair with `telescope_clear` before a user action to isolate exactly the traffic that action
  produces.

---

## telescope_exceptions

Return recent uncaught exception records from the running Flutter app.

Reads the Telescope exception ring buffer populated by the `FlutterError.onError` hook that
`TelescopePlugin.install()` chains. Use this when a crash or unhandled `Exception` was thrown and
you need the stack without scraping `flutter run` stdout.

**VM Service extension:** `ext.telescope.exceptions`

### Input Schema

| Parameter | Type | Required | Description |
|---|---|---|---|
| `limit` | integer | no | Maximum number of exception records to return, newest first. Omit for the whole buffer. |

### Output Shape

```json
{
  "records": [
    {
      "exceptionType": "StateError",
      "message": "Bad state: Stream has already been listened to",
      "time": "2026-05-20T14:33:00.789Z",
      "stackTrace": "#0 _StreamController._subscribe ...",
      "isolate": "main"
    }
  ]
}
```

| Field | Type | Always present | Description |
|---|---|---|---|
| `exceptionType` | string | yes | Runtime type name of the exception object |
| `message` | string | yes | Exception message string |
| `time` | string | yes | ISO 8601 UTC timestamp |
| `stackTrace` | string | no | Full stack trace, when available |
| `isolate` | string | no | Isolate name where the exception was caught |

### Example Invocations

```
# Last 3 uncaught exceptions
telescope_exceptions limit=3

# All exceptions in the buffer
telescope_exceptions
```

### Notes

- Only **uncaught** exceptions routed through `FlutterError.onError` are captured. Expected
  `try/catch` flows do not surface here.
- The watcher chain-preserves the previous `FlutterError.onError` handler (e.g. Sentry) so both
  coexist safely.
- Pair with `telescope_tail` to see what the app logged in the moments before the crash.

---

## telescope_events

Return recent in-app event records from the running Flutter app.

Reads the Telescope events ring buffer populated by `MagicEventWatcher` whenever `Event.dispatch()`
is called via the Magic `Event` facade. Use this to trace event-driven side effects (cache
invalidation, broadcast echoes, model lifecycle transitions) without adding `print` statements.

**VM Service extension:** `ext.telescope.events`

### Input Schema

| Parameter | Type | Required | Description |
|---|---|---|---|
| `limit` | integer | no | Maximum number of event records to return, newest first. Omit for the whole buffer (cap enforced by ring-buffer size, typically 500). |

### Output Shape

```json
{
  "records": [
    {
      "eventType": "MonitorChecked",
      "payload": {
        "monitorId": "abc-123",
        "status": "up"
      },
      "time": "2026-05-20T14:34:00.001Z",
      "listenerCount": 3
    }
  ]
}
```

| Field | Type | Always present | Description |
|---|---|---|---|
| `eventType` | string | yes | Runtime class name of the dispatched event |
| `payload` | object | yes | JSON snapshot of the event payload |
| `time` | string | yes | ISO 8601 UTC timestamp |
| `listenerCount` | integer | no | Number of listeners notified at dispatch time, when available |

### Example Invocations

```
# Last 10 events
telescope_events limit=10

# All events in the buffer
telescope_events
```

### Notes

- Only events dispatched through the Magic `Event` facade are captured. Raw
  `ChangeNotifier.notifyListeners` calls are invisible to this tool.
- For Gate authorization checks use `telescope_gates`; for HTTP traffic use `telescope_requests`.

---

## telescope_gates

Return recent Gate authorization check records from the running Flutter app.

Reads the Telescope gates ring buffer populated by `MagicGateWatcher` on every
`Gate.allows` / `Gate.denies` call via the Magic `Gate` facade. Use this to debug authorization
issues (why a button is hidden, why a route is blocked) without modifying policy classes.

**VM Service extension:** `ext.telescope.gates`

### Input Schema

| Parameter | Type | Required | Description |
|---|---|---|---|
| `limit` | integer | no | Maximum number of gate check records to return, newest first. Omit for the whole buffer (cap enforced by ring-buffer size, typically 500). |

### Output Shape

```json
{
  "records": [
    {
      "ability": "monitors.destroy",
      "result": false,
      "arguments": ["Monitor"],
      "time": "2026-05-20T14:35:00.010Z",
      "userId": "user-42"
    }
  ]
}
```

| Field | Type | Always present | Description |
|---|---|---|---|
| `ability` | string | yes | Ability name passed to `Gate.allows` / `Gate.denies` |
| `result` | boolean | yes | `true` when the gate allowed the action; `false` when denied |
| `arguments` | array | yes | List of argument values (class name strings or serialized primitives) |
| `time` | string | yes | ISO 8601 UTC timestamp |
| `userId` | string | no | Authenticated user ID at check time, when available |

### Example Invocations

```
# Last 20 gate checks
telescope_gates limit=20

# All gate checks in the buffer
telescope_gates
```

### Notes

- Only checks routed through the Magic `Gate` facade are captured. Direct policy class calls
  are not recorded.
- Pair with `telescope_clear` before walking a guarded flow to isolate just the relevant checks.

---

## telescope_dumps

Return recent `debugPrint` output records from the running Flutter app.

Reads the Telescope dumps ring buffer populated by `DumpWatcher`, which overrides `debugPrint`
globally. Use this to read `print()` / `debugPrint()` output from within the running app without
scraping `flutter run` stdout.

**VM Service extension:** `ext.telescope.dumps`

### Input Schema

| Parameter | Type | Required | Description |
|---|---|---|---|
| `limit` | integer | no | Maximum number of dump records to return, newest first. Omit for the whole buffer (cap enforced by ring-buffer size, typically 500). |

### Output Shape

```json
{
  "records": [
    {
      "message": "[MonitorController] reloading monitors...",
      "time": "2026-05-20T14:36:00.200Z",
      "wrapWidth": 80
    }
  ]
}
```

| Field | Type | Always present | Description |
|---|---|---|---|
| `message` | string | yes | Full message string passed to `debugPrint` |
| `time` | string | yes | ISO 8601 UTC timestamp |
| `wrapWidth` | integer | no | Wrap width passed to the original `debugPrint` call, when provided |

### Example Invocations

```
# Last 10 debugPrint calls
telescope_dumps limit=10

# All dump records in the buffer
telescope_dumps
```

### Notes

- Only output routed through the `debugPrint` global override is captured. `dart:io stdout.write`
  calls are invisible to this tool.
- `DumpWatcher` gates on `kDebugMode`: release builds tree-shake it entirely.
- For structured logs use `telescope_tail`; for crashes use `telescope_exceptions`.

---

## telescope_queries

Return recent database query records from the running Flutter app.

Reads the Telescope queries ring buffer populated by `MagicQueryWatcher`, which subscribes to
magic's `QueryExecuted` event dispatched by the Magic QueryBuilder. Each record carries the SQL
string, bindings, execution time, and connection name. Use this to inspect what queries the app
dispatched without attaching a separate SQL profiler.

**VM Service extension:** `ext.telescope.queries`

### Input Schema

| Parameter | Type | Required | Description |
|---|---|---|---|
| `limit` | integer | no | Maximum number of query records to return, newest first. Omit for the whole buffer (cap enforced by ring-buffer size, typically 500). |

### Output Shape

```json
{
  "records": [
    {
      "sql": "SELECT * FROM monitors WHERE team_id = ? LIMIT 50",
      "bindings": ["team-abc"],
      "timeMs": 4,
      "connectionName": "default",
      "time": "2026-05-20T14:37:00.100Z"
    }
  ]
}
```

| Field | Type | Always present | Description |
|---|---|---|---|
| `sql` | string | yes | SQL string the QueryBuilder dispatched to the underlying driver |
| `bindings` | array | yes | Positional or named query bindings |
| `timeMs` | integer | yes | Execution time in milliseconds reported by magic's QueryBuilder |
| `connectionName` | string | yes | Connection name; `"default"` when the consumer did not name it |
| `time` | string | yes | ISO 8601 UTC timestamp |

### Example Invocations

```
# Last 5 queries
telescope_queries limit=5

# All queries in the buffer
telescope_queries
```

### Notes

- Only queries that go through magic's QueryBuilder (dispatching `QueryExecuted` via
  `EventDispatcher`) are recorded. Raw `sqlite3` or direct Dio SQL calls bypass this tool.
- For Magic Cache traffic use `telescope_caches`; for HTTP use `telescope_requests`; for log
  lines use `telescope_tail`.

---

## telescope_caches

Return recent Magic Cache operation records from the running Flutter app.

Reads the Telescope caches ring buffer populated by `MagicCacheWatcher`, which subscribes to
magic's `CacheHit` / `CacheMiss` / `CachePut` / `CacheForget` / `CacheFlush` events. Each record
carries timestamp, operation tag, cache key, and optional TTL. Use this to inspect cache traffic
without instrumenting the consumer code.

**VM Service extension:** `ext.telescope.caches`

### Input Schema

| Parameter | Type | Required | Description |
|---|---|---|---|
| `limit` | integer | no | Maximum number of cache records to return, newest first. Omit for the whole buffer (cap enforced by ring-buffer size, typically 500). |

### Output Shape

```json
{
  "records": [
    {
      "operation": "miss",
      "key": "monitors.team-abc",
      "time": "2026-05-20T14:38:00.300Z",
      "ttlMs": 300000
    }
  ]
}
```

| Field | Type | Always present | Description |
|---|---|---|---|
| `operation` | string | yes | One of: `hit`, `miss`, `put`, `forget`, `flush` |
| `key` | string | yes | Cache key string |
| `time` | string | yes | ISO 8601 UTC timestamp |
| `ttlMs` | integer | no | TTL in milliseconds, when the operation included a TTL |

### Example Invocations

```
# Last 20 cache operations
telescope_caches limit=20

# All cache operations in the buffer
telescope_caches
```

### Notes

- Only Magic `Cache` facade calls dispatch the watcher events. Raw driver-level cache calls
  bypass this tool.
- For DB queries use `telescope_queries`; for HTTP use `telescope_requests`.

---

## telescope_clear

Clear every Telescope ring buffer.

Wipes all ring buffers in one call so the next `telescope_tail` / `telescope_requests` /
`telescope_exceptions` / `telescope_events` / `telescope_gates` / `telescope_dumps` /
`telescope_queries` / `telescope_caches` returns only records produced **after** this clear. Useful
as a "set zero" before reproducing a bug or capturing the output of a specific user action.

**VM Service extension:** `ext.telescope.clear`

### Input Schema

No parameters.

### Output Shape

```json
{
  "cleared": true
}
```

| Field | Type | Always present | Description |
|---|---|---|---|
| `cleared` | boolean | yes | Always `true` on success |

### Example Invocations

```
# Clear all buffers before a repro
telescope_clear

# Common pattern: clear, perform the action, then read
telescope_clear
# ... trigger the user action ...
telescope_requests limit=20
telescope_tail limit=50
```

### Notes

- Idempotent: safe to call when buffers are already empty.
- Does NOT affect the live `package:logging` stream; only the captured ring buffers.
- The `ext.telescope.pause` and `ext.telescope.resume` extensions exist in the running app but
  are not exposed as MCP tools in the current release (V1.x backlog).

---

## Related

- [Overview](overview.md): how the 9 tools surface through `TelescopeArtisanProvider` and route
  through the VM Service.
- [Setup guide](setup.md): install telescope, register `TelescopeArtisanProvider`, and connect
  Claude Code.
- [artisan MCP tool reference](https://fluttersdk.com/artisan/mcp/tool-reference): the 10 substrate
  tools (`artisan_start`, `artisan_stop`, `artisan_tinker`, etc.) and filter configuration.
