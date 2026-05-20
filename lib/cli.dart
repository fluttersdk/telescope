/// CLI-side barrel ; intentionally Flutter-free.
///
/// Imported by the consumer's `lib/app/_plugins.g.dart` codegen (which runs
/// under `dart run` on the pure Dart VM, not under `flutter run`). Re-exports
/// the artisan provider class plus the codegen-convention alias so
/// `dart run artisan list` and `dart run fluttersdk_artisan:mcp` can wire
/// telescope without dragging the Flutter runtime into the consumer wrapper.
///
/// Runtime / widget code keeps using `package:fluttersdk_telescope/telescope.dart`
/// (the full barrel that re-exports `TelescopePlugin` + watchers + adapters +
/// records + the store) and the original [TelescopeArtisanProvider] symbol.
library;

import 'src/telescope_artisan_provider.dart';

export 'src/telescope_artisan_provider.dart' show TelescopeArtisanProvider;

/// Codegen-convention alias for [TelescopeArtisanProvider].
///
/// `fluttersdk_artisan`'s `plugins:refresh` generates plugin imports as
/// `<PascalCasePackageName>ArtisanProvider`; for this package that resolves
/// to `FluttersdkTelescopeArtisanProvider`. The alias keeps the legacy
/// `TelescopeArtisanProvider` symbol stable for hand-written callers
/// (magic, uptizm-app) while letting the codegen-generated
/// `_plugins.g.dart` find a class name matching its convention.
typedef FluttersdkTelescopeArtisanProvider = TelescopeArtisanProvider;
