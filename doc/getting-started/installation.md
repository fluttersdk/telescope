# Installation

- [Requirements](#requirements)
- [Option A: one-shot install via artisan](#option-a-one-shot-install)
- [Option B: manual wiring](#option-b-manual-wiring)
- [Wire the Artisan provider](#wire-the-artisan-provider)
- [Verify installation](#verify-installation)

`fluttersdk_telescope` works from a fresh Flutter project. The recommended install path
uses telescope's own bootstrap entry point (`dart run fluttersdk_telescope telescope:install`)
which carries the artisan substrate, so no prior `fluttersdk_artisan` setup is required.

<a name="requirements"></a>
## Requirements

| Dependency | Minimum Version | Notes |
|:-----------|:----------------|:------|
| Dart SDK | `>= 3.4.0` | |
| Flutter SDK | `>= 3.22.0` | VM Service extensions require the Flutter runtime. |
| fluttersdk_artisan | `^0.0.2` | Pulled in transitively by telescope; no manual setup needed for the install path. |
| Magic stack | optional | Enables 6 additional Magic-specific watchers. |

<a name="option-a-one-shot-install"></a>
## Option A: one-shot self-bootstrap install (recommended)

Add `fluttersdk_telescope` to `pubspec.yaml`, run `dart pub get`, then bootstrap via
telescope's own CLI entry point. The standalone binary carries the artisan substrate, so
this works from a completely fresh consumer with no prior `fluttersdk_artisan` wiring:

```bash
dart run fluttersdk_telescope telescope:install
```

The command performs three operations in order:

1. Scaffolds the consumer artisan harness (`bin/dispatcher.dart`, `lib/app/_plugins.g.dart`)
   if it is missing. This is a no-op when the harness is already present.
2. Runs `plugin:install fluttersdk_telescope`, which registers `TelescopeArtisanProvider`
   in `.artisan/plugins.json` and refreshes the codegen barrel.
3. Patches `lib/main.dart` to call `TelescopePlugin.install()` before `runApp`. When using
   the Magic framework, the patch places the call before `Magic.init()` so the Http facade
   is wired before MagicTelescopeIntegration runs. The patch is wrapped in a `kDebugMode`
   guard automatically.

The command is idempotent. Re-running it when the files are already patched is safe.

### After install: prefer the artisan fast-cli

The artisan scaffold ships a precompiled launcher at `./bin/fsa` (native AOT, ~110ms warm
startup). For everyday telescope work, use it instead of `dart run`:

```bash
./bin/fsa telescope:tail
./bin/fsa telescope:requests
./bin/fsa telescope:clear
```

`dart run fluttersdk_telescope <cmd>` and `dart run fluttersdk_artisan <cmd>` keep working
as ~3-second cold-start fallbacks; they are useful in CI or before the AOT bundle is built.

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

Install Telescope before `runApp`, wrapped in `kDebugMode`. When using the Magic framework,
place the call before `Magic.init()` so the Http facade is wired before
MagicTelescopeIntegration runs:

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

  // 3. Framework init (e.g. Magic.init()) runs after Telescope so the Http facade
  //    is wired before MagicTelescopeIntegration tries to wrap it.
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

If you used Option A (`telescope:install`), the provider registration is written
automatically: `plugin:install fluttersdk_telescope` adds `FluttersdkTelescopeArtisanProvider`
to `lib/app/_plugins.g.dart`, which the scaffolded `bin/dispatcher.dart` reads via
`plugins.autoDiscoveredProviders()`. No manual edit is required.

If you used Option B (manual wiring), import the provider in your `bin/dispatcher.dart`
yourself:

```dart
import 'package:fluttersdk_artisan/artisan.dart';
import 'package:fluttersdk_telescope/cli.dart' show FluttersdkTelescopeArtisanProvider;

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

<a name="verify-installation"></a>
## Verify installation

Start your Flutter app and confirm Telescope is active by tailing the log buffer:

```bash
./bin/fsa telescope:tail
```

Expected output on a running app shows the most recent log records from the ring buffer.
If you see `Error: no running app found`, the artisan state file is missing: run
`./bin/fsa start` first, then retry `telescope:tail`.

To confirm all 6 CLI commands are registered, list the artisan command catalog:

```bash
./bin/fsa list
```

The output includes the `telescope:` namespace with `telescope:install`, `telescope:tail`,
`telescope:requests`, `telescope:queries`, `telescope:caches`, and `telescope:clear`. If
the fast-cli is missing for any reason, the same commands run via `dart run fluttersdk_telescope list`
or `dart run fluttersdk_artisan list`.
