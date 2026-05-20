# Telescope MCP Setup

`fluttersdk_telescope` extends the artisan MCP server with 9 runtime-inspection tools
(`telescope_*`). This page covers everything needed to make those tools appear in Claude Code,
Cursor, or any other MCP-compatible client.

**Prerequisite:** no prior artisan setup is required. Telescope's `telescope:install` command
scaffolds the artisan harness on first run, and `fluttersdk_artisan` is pulled in transitively
through telescope's pubspec.

---

## Step 1: Add the dependency

Add `fluttersdk_telescope` to your `pubspec.yaml` under `dependencies` (not `dev_dependencies`,
because `TelescopePlugin` is imported by `lib/main.dart`):

```yaml
# pubspec.yaml
dependencies:
  fluttersdk_telescope: ^0.0.1
```

Run `dart pub get` after editing.

### Step 1a: bootstrap with `telescope:install` (optional but recommended)

If you only want the MCP tools, jump to Step 2. If you also want the 6 CLI commands wired
to the artisan dispatcher, run the one-shot bootstrap now; it scaffolds `bin/dispatcher.dart`,
registers the plugin, and patches `lib/main.dart` in one go:

```bash
dart run fluttersdk_telescope telescope:install
```

After install, the consumer's fast-cli is available at `./bin/fsa` (native AOT, ~110ms warm).

---

## Step 2: Install the Flutter-side plugin

Inside `lib/main.dart`, install `TelescopePlugin` before `Magic.init()`. Gate on `kDebugMode` so
the entire subsystem tree-shakes out of release builds:

```dart
import 'package:flutter/foundation.dart';
import 'package:fluttersdk_telescope/telescope.dart';

Future<void> main() async {
  if (kDebugMode) {
    TelescopePlugin.install();
    // Optional: register adapters and watchers contributed by magic.
    // MagicTelescopeIntegration.install() after Magic.init().
  }
  await Magic.init(...);
  runApp(MagicApplication());
}
```

`TelescopePlugin.install()` registers all `ext.telescope.*` VM Service extensions and starts the
ring buffers. Extensions are registered via `registerExtensionIdempotent` (from artisan), so hot
restarts are safe.

---

## Step 3: Register TelescopeArtisanProvider in bin/dispatcher.dart

If you ran Step 1a (`telescope:install`), the provider is registered automatically via
`lib/app/_plugins.g.dart` (the codegen barrel auto-discovered by `bin/dispatcher.dart`); skip
to Step 4.

For manual wiring, open `bin/dispatcher.dart` and add `FluttersdkTelescopeArtisanProvider()`
to the `baseProviders` list:

```dart
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:fluttersdk_telescope/cli.dart';  // FluttersdkTelescopeArtisanProvider typedef

Future<void> main(List<String> args) async {
  exit(await runArtisan(
    args,
    baseProviders: [
      FluttersdkTelescopeArtisanProvider(),
      // ...other providers (DuskArtisanProvider, etc.)
    ],
  ));
}
```

The `cli.dart` barrel exports `FluttersdkTelescopeArtisanProvider` (a typedef alias for
`TelescopeArtisanProvider`) so consumer-side auto-discovery can use a stable name.

---

## Step 4: Ensure the artisan MCP server entry is present

The telescope tools surface through artisan's MCP server. The `.mcp.json` entry must point at
`dart run fluttersdk_artisan:mcp` (not a separate telescope entry). If you ran
`dart run fluttersdk_artisan mcp:install` during artisan setup, the entry is already in place:

```json
{
  "mcpServers": {
    "fluttersdk": {
      "command": "dart",
      "args": ["run", "fluttersdk_artisan:mcp"],
      "cwd": "."
    }
  }
}
```

The `cwd` field must resolve to the directory containing `pubspec.yaml` and `bin/dispatcher.dart`.
The server reads both at startup: `pubspec.yaml` for the project root detection and
`bin/dispatcher.dart` (via the registered providers) for the plugin tool catalog.

---

## Step 5: Reconnect the MCP server

After editing `bin/dispatcher.dart` or `.mcp.json`, the running MCP server process must be
restarted for the new tools to appear in the catalog:

**Claude Code:**

```
/mcp reconnect fluttersdk
```

**Cursor / Windsurf:** Reload the MCP panel or restart the IDE session.

**Claude Desktop:** Fully quit and relaunch.

---

## Step 6: Start the Flutter app and verify

Start the app via artisan so the state file is written:

```bash
./bin/fsa start              # web (chrome, default)
./bin/fsa start --device=macos  # desktop
```

Then ask the agent to check telescope connectivity:

```
telescope_tail limit=5
```

A successful response returns a JSON array of recent log records. An empty array means the app is
running but no logs have been emitted yet. An error response means the VM Service URI in
`~/.artisan/state.json` is stale; run `./bin/fsa stop && ./bin/fsa start` to refresh it.

---

## Filtering telescope tools

To hide specific telescope tools from the agent's catalog, add deny rules to `.artisan/mcp.json`:

```json
{
  "packages": {
    "allow": null,
    "deny": []
  },
  "tools": {
    "allow": null,
    "deny": ["telescope_dumps", "telescope_gates"]
  }
}
```

To expose only telescope tools (hiding substrate and dusk tools):

```json
{
  "packages": {
    "allow": ["fluttersdk_telescope"],
    "deny": []
  },
  "tools": {
    "allow": null,
    "deny": []
  }
}
```

After editing `.artisan/mcp.json`, run `/mcp reconnect fluttersdk` in Claude Code to reload the
filter. See the [artisan filter reference](https://fluttersdk.com/artisan/mcp/tool-reference#filter-configuration)
for the full three-layer precedence rules (file, env vars, CLI flags).

---

## Related

- [artisan MCP setup](https://fluttersdk.com/artisan/mcp/setup): full client matrix (Cursor, Claude
  Desktop, VS Code, Windsurf, JetBrains, Cline, OpenCode, Gemini CLI).
- [Overview](overview.md): how the 9 tools surface through `TelescopeArtisanProvider` and route
  through the VM Service.
- [Tool reference](tool-reference.md): per-tool input schema, output shape, and example invocations.
