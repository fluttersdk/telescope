# fluttersdk_telescope showroom

A vanilla Flutter app that demonstrates every core telescope capture surface: HTTP via `DioHttpAdapter`, structured logs via `package:logging`, exceptions via `ExceptionWatcher`, and debug prints via `DumpWatcher`. The app resolves `fluttersdk_telescope` directly from the sibling source tree via `path: ../`, so any edit to the parent package is immediately reflected on the next hot restart. Framework-stack integration (such as the artisan provider or watcher auto-wiring) is out of scope; this is a plain `runApp` entry point wired manually.

## How to run

```bash
cd example
flutter pub get
flutter run -d chrome    # or -d macos, -d linux, etc.
```

## Sections

| Section | Triggers | Inspect via |
|---------|----------|-------------|
| HTTP via DioHttpAdapter | GET /get, POST /post, GET /status/418, GET /delay/5 (timeout) | `dart run fluttersdk_telescope telescope:requests` |
| Logs via package:logging | Logger.info, Logger.warning, Logger.severe | `dart run fluttersdk_telescope telescope:tail` |
| Exceptions via ExceptionWatcher | Async throw, Sync throw (caught), Custom error | `telescope_exceptions` MCP tool |
| Dumps via DumpWatcher | debugPrint single line, debugPrint multiline | `telescope_dumps` MCP tool |

## Manual QA checklist

- Boot the app via `flutter run -d chrome`.
- Tap each button at least once.
- Confirm the matching live-tail panel updates within ~1 second.
- Verify the status bar chip counters (HTTP / Log / Exception / Dump) increment per buffer.
- Tap "Clear all buffers": all chips return to 0 and live-tail panels empty (equivalent to running `dart run fluttersdk_telescope telescope:clear` from the CLI).
- Tap "Pause recording": subsequent button taps do NOT update buffers (chips stay flat).
- Tap "Resume recording": buffers update again.

## Path dependency note

This example depends on the parent telescope package via `path: ../`. Source edits to the parent require nothing more than a hot restart in the running example app. Downstream consumers that install from pub.dev use the hosted `^0.0.1` constraint instead.

## License

[MIT](../LICENSE) — same license as the parent `fluttersdk_telescope` package.
