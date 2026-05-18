# example

Vanilla Flutter demo for `fluttersdk_telescope`. Boots a single-screen app
that exercises every capture surface the package ships: HTTP requests via a
Dio interceptor, structured logs via `package:logging`, uncaught exceptions
via `ExceptionWatcher`, and `debugPrint` output via `DumpWatcher`. No Magic
dependency; vanilla Flutter only.

## Run the app

```bash
cd references/fluttersdk_telescope/example
flutter pub get
flutter run -d chrome
```

The screen shows four buttons. Each one drives one capture surface:

| Button             | Surface             | Telescope buffer | MCP tool                |
|--------------------|---------------------|------------------|-------------------------|
| Make HTTP call     | Dio + DioHttpAdapter | http             | `telescope_requests`    |
| Log warning        | package:logging      | logs             | `telescope_tail`        |
| Throw exception    | PlatformDispatcher   | exceptions       | `telescope_exceptions`  |
| debugPrint         | DumpWatcher          | dumps            | `telescope_dumps`       |

## Wire the MCP server in parallel

In a second terminal start the artisan MCP server. The agent (Claude Code,
Cursor, anything that speaks stdio JSON-RPC) connects to it and gains the
seven `telescope_*` tools backed by `ext.telescope.*` VM Service extensions.

```bash
dart run fluttersdk_artisan:mcp
```

The server reads `~/.artisan/state.json` for the VM Service URI written by
`flutter run` (no manual URL plumbing). When the demo app is up, every
button tap surfaces through the MCP tools without restart.

## Verify each capture surface

After tapping a button, invoke the matching tool from your agent. Example
call (Claude Code surfaces these as MCP tools you can ask for directly):

```jsonc
{
  "name": "telescope_requests",
  "arguments": { "limit": 5 }
}
```

Returns the most recent HTTP records newest-first. Pair any of the seven
tools with `telescope_clear` (no arguments) before a repro to isolate just
the relevant records.

## Notes

- All install calls live under `kDebugMode`; release builds tree-shake the
  entire telescope branch (dart2js for web, AOT for mobile / desktop).
- The Dio interceptor in `lib/main.dart` is the canonical wiring pattern
  while `DioHttpAdapter` ships as a V1 stub. V1.x will move the Dio glue
  into `fluttersdk_telescope_dio` so the core stays HTTP-library-agnostic.
- The exception button schedules the throw on a microtask so
  `PlatformDispatcher.onError` (chain-preserved by `ExceptionWatcher`)
  receives it instead of crashing the synchronous tap handler.
