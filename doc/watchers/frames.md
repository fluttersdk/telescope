# FramePerfWatcher

| Field | Value |
|---|---|
| Contract | `TelescopeWatcher` |
| Name | `frame_perf` |
| Auto-install | No (opt-in via `TelescopePlugin.registerWatcher(FramePerfWatcher())`) |
| Ring buffer | `TelescopeStore._framePerf` (own capacity, default 3600, independent of the shared 500-entry cap) |
| VM extension | `ext.telescope.frames` |
| CLI command | `telescope:frames` |
| MCP tool | `telescope_frames` |
| Opt-out | Do not register it; it is never auto-installed |

Captures per-frame performance by joining two sources the engine reports separately: frame
magnitude from `SchedulerBinding.addTimingsCallback`, and per-frame attribution drained from
`FlutterTimeline` at the end of every frame. The two arrive at different times, so the post-frame
drain parks its block map in a bounded pending map and the timings callback is the only emission
point, popping the matching map and writing one complete `FramePerfRecord` per `FrameTiming`.

`addTimingsCallback` appends to a list rather than replacing a single global slot, so there is
nothing to chain-preserve here: every other listener (sentry_flutter's among them) keeps receiving
timings while this watcher is installed.

## Liveness

A static `livenessCounter`, incremented once per drawn frame regardless of whether a measurement
session is running, is the only reliable proof the engine is rendering. It is exposed alongside
every `ext.telescope.frames` response so a caller can tell an empty result caused by a quiet app
from one caused by a stalled engine (a backgrounded Chrome tab suspends `requestAnimationFrame`
while every other in-app health signal keeps reading healthy).

## Attribution

Attribution only flows while `FlutterTimeline.debugCollectionEnabled` is true, which a measurement
session turns on. Until then the watcher records frame magnitude alone and every record's `blocks`
map is empty. Each block entry carries `micros` (inclusive of nested children), `selfMicros`
(exclusive: `micros` minus the combined duration of directly nested children), and `count`.

## Clock and interaction link

Every record carries `atUs`, a monotonic microsecond timestamp from `FlutterTimeline.now`, and the
optional `interactionId` / `linkedBy` pair that correlates it to other records captured during the
same interaction. `vsyncStartUs` (from `FrameTiming.timestampInMicroseconds(FramePhase.vsyncStart)`)
rides alongside `atUs` but its clock parity with `atUs` is NOT proven: the engine documents its
timestamp only as microseconds "from some epoch" shared across every `FrameTiming` field, and a unit
test can only inject synthetic `FrameTiming` values, never a real engine-reported one. Treat
`vsyncStartUs` vs. `atUs` comparisons as needing a driven, live-engine run to validate.

## Registration

```dart
if (kDebugMode) {
  TelescopePlugin.install();
  TelescopePlugin.registerWatcher(FramePerfWatcher()); // opt-in
}
```

Opt-out: simply omit the `registerWatcher(FramePerfWatcher())` call.

See the [MCP tool reference](../mcp/tool-reference.md#telescope_frames) for the full
`telescope_frames` input schema and output shape.
