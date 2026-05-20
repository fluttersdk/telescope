import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';

// Direct import (not the package barrel) so this entrypoint stays Flutter-free.
// The barrel re-exports TelescopePlugin + watchers, which transitively pull in
// `dart:ui` (PlatformDispatcher, debugPrint). `dart run fluttersdk_telescope`
// runs on the plain Dart VM; touching `dart:ui` from this binary would break
// CLI invocation outside `flutter run`.
import 'package:fluttersdk_telescope/src/telescope_artisan_provider.dart';

/// `dart run fluttersdk_telescope <cmd>` ; telescope-flavoured artisan wrapper.
///
/// Proxies the full artisan command surface (start / stop / status / doctor /
/// logs / restart / reload / hot-restart / tinker / make:* / mcp:* /
/// plugin:* / install / etc.) AND registers
/// [TelescopeArtisanProvider] so the 6 telescope CLI commands
/// (`telescope:install`, `telescope:tail`, `telescope:requests`,
/// `telescope:queries`, `telescope:caches`, `telescope:clear`) plus the 9
/// `telescope_*` MCP tools surface in the same `list` output.
///
/// Run from any consumer directory that has `fluttersdk_telescope` in its
/// pubspec as a dependency.
Future<void> main(List<String> args) async {
  exit(
    await runArtisan(
      args,
      baseProviders: [TelescopeArtisanProvider()],
      delegateToConsumer: false,
    ),
  );
}
