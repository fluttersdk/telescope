# Buffers

`TelescopeStore` keeps ten in-memory ring buffers, one per record type. Each is a FIFO queue: when a buffer
is over its capacity the oldest record is evicted, silently.

## Capacity

Every buffer holds 500 records by default, except frame performance, which holds 3600 (about a minute at
60fps).

```dart
TelescopeStore.setCapacity(2000);                              // every buffer but frame perf
TelescopeStore.setCapacity(5000, kind: TelescopeKind.logs);    // one buffer
TelescopeStore.setCapacity(7200, kind: TelescopeKind.framePerf);
```

`TelescopeKind` names the ten buffers: `http`, `logs`, `exceptions`, `models`, `caches`, `events`, `gates`,
`dumps`, `queries`, `framePerf`.

- A cap for one kind wins over the shared cap, whichever was set last. The shared call leaves a kind cap
  alone.
- A cap below the buffer's current length trims on the next record, not retroactively.
- A cap of zero or less keeps nothing.
- `setFramePerfCapacity(n)` is `setCapacity(n, kind: TelescopeKind.framePerf)`.
- `TelescopeStore.resetForTesting()` (test only) empties the buffers, restores both default caps, clears the
  per-kind caps and unregisters the `TelescopeRedaction.redactor`.

## Monotonic timestamps

`LogRecordEntry` carries `atUs`, stamped at construction from `FlutterTimeline.now`, the clock
`EventRecord.atUs` already used. It is serialized in `toJson`, so a log line orders against an event
whatever the wall clock did. `time` stays the wall-clock field for display. `atUs` is also the cursor that
`ext.telescope.console` and `ext.telescope.events` page on (see [Cursor and filters](../mcp/cursor-and-filters.md)).

## Reading with `limit` and `minLevel`

`TelescopeStore.recentX(limit:)` returns the newest `limit` records, oldest first.

- A zero or negative `limit` returns an empty list. It used to throw a `RangeError`.
- `recentLogs(minLevel:)` keeps records at or above the named `package:logging` level. A name that is not
  a level (`FINEST`, `FINER`, `FINE`, `CONFIG`, `INFO`, `WARNING`, `SEVERE`, `SHOUT`, any case) matches
  nothing and returns an empty list. It used to match every line, which an agent would read as a clean
  log.
