# example_magic

Magic-stack Flutter app that exercises every capture surface
`MagicTelescopeIntegration` ships. Pair to the vanilla `example/` app: same
goal (manual smoke that fluttersdk_telescope captures the things it claims
to capture), different stack (magic facades instead of raw Dio / logging).

## What this demonstrates

| Button                  | Capture surface                | Telescope buffer                       |
|-------------------------|--------------------------------|----------------------------------------|
| Make Magic.Http call    | `MagicHttpFacadeAdapter`       | `TelescopeStore.recentHttpRequests`    |
| Create DemoModel        | `MagicModelWatcher` (`created`)| `TelescopeStore.recentMagicModels`     |
| Save DemoModel          | `MagicModelWatcher` (`saved`)  | `TelescopeStore.recentMagicModels`     |
| Delete DemoModel        | `MagicModelWatcher` (`deleted`)| `TelescopeStore.recentMagicModels`     |
| Check gate ability      | `MagicGateWatcher`             | `TelescopeStore.recentGates`           |
| Trigger custom event    | `MagicEventWatcher` (AuthFailed)| `TelescopeStore.recentEvents`         |

The Http button performs a real `Http.get('https://httpbin.org/get')`;
network failure does not block capture because the interceptor records on
both response and error. The Model buttons dispatch `ModelCreated` /
`ModelSaved` / `ModelDeleted` directly via `Event.dispatch(...)` instead of
calling `Model.save()` so the demo stays free of a backend / SQLite table
while still exercising the exact event channel the watcher subscribes to.

## Install order

`lib/main.dart` mirrors the canonical pattern from `uptizm-app/lib/main.dart`:

1. `TelescopePlugin.install()` runs BEFORE `Magic.init()`. The framework
   side has no Magic dependency; bringing it up first means VM Service
   extensions and the log sink are live even if Magic boot fails.
2. `MagicTelescopeIntegration.install()` runs AFTER `Magic.init()`. The
   `MagicHttpFacadeAdapter` resolves `NetworkDriver` from the IoC
   container; the watchers bind listener factories on `EventDispatcher`.
3. Both calls live inside `if (kDebugMode) { ... }`. Release builds
   tree-shake every telescope branch on every platform (dart2js for web,
   dart2native for desktop, AOT for mobile).

## Run

```bash
cd references/fluttersdk_telescope/example_magic
flutter pub get
flutter run -d chrome
```

Tap each button. Confirmation snackbars name the matching telescope MCP
tool.

## Verify capture via MCP

The MCP server ships inside `fluttersdk_artisan`. From a consumer that has
`fluttersdk_artisan` registered (uptizm-app or another magic-stack app
with this example running in the same VM), run:

```bash
dart run fluttersdk_artisan:mcp
```

Then call the tools from your MCP client:

- `telescope_requests` for HTTP captures.
- Model lifecycle captures land in the `magic_model` ring buffer but are NOT MCP-surfaced in alpha-2 (`telescope_models` is V1.x backlog). Read them through the artisan `tinker_eval` MCP tool with the expression `TelescopeStore.recentModels().map((r) => r.toJson()).toList()`.
- `telescope_gates` for gate-check captures.
- `telescope_events` for app event captures.

Each call returns the buffered records that the button triggers landed in
`TelescopeStore`.
