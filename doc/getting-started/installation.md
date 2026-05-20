# Installation

- [Requirements](#requirements)
- [Option A: one-shot install via artisan](#option-a-one-shot-install)
- [Option B: manual wiring](#option-b-manual-wiring)
- [Wire the Artisan provider](#wire-the-artisan-provider)
- [Verify installation](#verify-installation)

`fluttersdk_telescope` requires a Flutter project with `fluttersdk_artisan` already wired.
If artisan is not yet set up, run `dart run fluttersdk_artisan install` first.

<a name="requirements"></a>
## Requirements

| Dependency | Minimum Version | Notes |
|:-----------|:----------------|:------|
| Dart SDK | `>= 3.4.0` | |
| Flutter SDK | `>= 3.22.0` | VM Service extensions require the Flutter runtime. |
| fluttersdk_artisan | `^0.0.1` | Provides the `telescope:install` command and MCP server. |
| Magic stack | optional | Enables 6 additional Magic-specific watchers. |

<a name="option-a-one-shot-install"></a>
## Option A: one-shot install via artisan (recommended)

Once the consumer has `fluttersdk_artisan` wired (`bin/artisan.dart` present), let
Telescope install itself end-to-end with a single command:

```bash
dart run :artisan telescope:install
```

The command performs three operations in order:

1. Scaffolds the consumer artisan harness (`bin/artisan.dart`, `lib/app/_plugins.g.dart`)
   if it is missing. This is a no-op when the harness is already present.
2. Runs `plugin:install fluttersdk_telescope`, which registers `TelescopeArtisanProvider`
   in `.artisan/plugins.json` and refreshes the codegen barrel.
3. Patches `lib/main.dart` to call `TelescopePlugin.install()` before `Magic.init()` on
   Magic-stack apps, or before `runApp` on vanilla Flutter. The patch is wrapped in a
   `kDebugMode` guard automatically.

The command is idempotent. Re-running it when the files are already patched is safe.

<a name="option-b-manual-wiring"></a>
## Option B: manual wiring

Use this path when you need fine-grained control over the install, or when the automated
patch cannot locate the correct anchor in `lib/main.dart`.

### 1. Add the dependency

Add `fluttersdk_telescope` to `pubspec.yaml`:

```yaml
dependencies:
  fluttersdk_telescope: ^0.0.1
```

Then fetch dependencies:

```bash
dart pub get
```

### 2. Wire TelescopePlugin in lib/main.dart

Install Telescope before `Magic.init()` on Magic-stack apps, or before `runApp` on
vanilla Flutter. Wrap every install call in `kDebugMode`:

```dart
import 'package:flutter/foundation.dart';
import 'package:fluttersdk_telescope/telescope.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    // 1. Install Telescope core (LogWatcher auto-installs, VM extensions register).
    TelescopePlugin.install();

    // 2. Opt-in to exception and debugPrint capture.
    TelescopePlugin.registerWatcher(ExceptionWatcher());
    TelescopePlugin.registerWatcher(DumpWatcher());
  }

  // 3. Magic.init() runs after Telescope so the Http facade is wired before
  //    MagicTelescopeIntegration tries to wrap it.
  await Magic.init(configFactories: [...]);

  if (kDebugMode) {
    // 4. Magic-specific adapters resolve framework internals from the IoC container;
    //    they must run after Magic.init().
    MagicTelescopeIntegration.install();
  }

  runApp(MyApp());
}
```

For vanilla Flutter (no Magic stack), omit `Magic.init()` and the
`MagicTelescopeIntegration.install()` call. Wire `DioHttpAdapter` instead if you use Dio:

```dart
if (kDebugMode) {
  TelescopePlugin.install();
  TelescopePlugin.registerHttpAdapter(DioHttpAdapter(dio));
  TelescopePlugin.registerWatcher(ExceptionWatcher());
  TelescopePlugin.registerWatcher(DumpWatcher());
}
```

<a name="wire-the-artisan-provider"></a>
## Wire the Artisan provider

Register `TelescopeArtisanProvider` in `bin/artisan.dart` to surface the 9 `telescope_*`
MCP tools and the 6 CLI commands:

```dart
import 'package:fluttersdk_telescope/telescope.dart' show TelescopeArtisanProvider;

exit(await runArtisan(
  args,
  baseProviders: [
    MagicArtisanProvider(),
    TelescopeArtisanProvider(),
    ...plugins.autoDiscoveredProviders(),
  ],
));
```

If you used Option A (`telescope:install`), the provider registration is written
automatically via `plugin:install`; you do not need to edit `bin/artisan.dart` by hand.

<a name="verify-installation"></a>
## Verify installation

Start your Flutter app and confirm Telescope is active by tailing the log buffer:

```bash
dart run :artisan telescope:tail
```

Expected output on a running app shows the most recent log records from the ring buffer.
If you see `Error: no running app found`, the artisan state file is missing: run
`dart run :artisan start` first, then retry `telescope:tail`.

To confirm all 9 MCP tools are registered, list the artisan command catalog:

```bash
dart run :artisan list
```

The output includes a `telescope` namespace with `telescope:install`, `telescope:tail`,
`telescope:requests`, `telescope:queries`, `telescope:caches`, and `telescope:clear`.
