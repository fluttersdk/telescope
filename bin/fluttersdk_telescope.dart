import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';

// Direct import (not the package barrel) so this entrypoint stays Flutter-free.
// The barrel re-exports TelescopePlugin + watchers, which transitively pull in
// `dart:ui` (PlatformDispatcher, debugPrint). `dart run fluttersdk_telescope`
// runs on the plain Dart VM; touching `dart:ui` from this binary would break
// CLI invocation outside `flutter run`.
import 'package:fluttersdk_telescope/src/cli_args.dart';
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
/// When forwarding `mcp:install`, [injectInvocationForMcpInstall] appends
/// `--invocation=fluttersdk_telescope` so the substrate writes the correct
/// `dart run fluttersdk_telescope mcp:serve` entry into `.mcp.json`.
///
/// When forwarding `mcp:serve`, [collectMcpTools] is forced `true` so that
/// all 9 `telescope_*` MCP tools surface alongside the substrate `artisan_*` tools.
///
/// Run from any consumer directory that has `fluttersdk_telescope` in its
/// pubspec as a dependency.
Future<void> main(List<String> args) async {
  final injected = injectInvocationForMcpInstall(args, 'fluttersdk_telescope');
  final firstNonFlag = injected.firstWhere(
    (a) => !a.startsWith('-'),
    orElse: () => '',
  );
  final isMcpServe = firstNonFlag == 'mcp:serve';

  exit(
    await runArtisan(
      injected,
      baseProviders: [TelescopeArtisanProvider()],
      collectMcpTools: isMcpServe,
      delegateToConsumer: false,
    ),
  );
}
