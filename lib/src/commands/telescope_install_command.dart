import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';

/// `artisan telescope:install` ; one-shot bootstrap for the telescope plugin.
///
/// Runs the canonical install sequence in the consumer project:
///
///   1. `dart run fluttersdk_telescope install` (only when
///      `bin/dispatcher.dart` is missing; idempotent skip otherwise). This
///      step produces `bin/dispatcher.dart`, `bin/fsa` (the AOT fast-cli),
///      `lib/app/_plugins.g.dart`, and `lib/app/commands/_index.g.dart`.
///   2. `dart run fluttersdk_telescope plugin:install fluttersdk_telescope`
///      (always; the underlying plugin:install + plugins:refresh are
///      idempotent so re-runs are safe). Routes through the telescope CLI
///      wrapper (`bin/fluttersdk_telescope.dart`) which preloads
///      `TelescopeArtisanProvider` and sets `delegateToConsumer: false`, so
///      no `bin/fsa` AOT scaffold dependency exists at this stage and the
///      consumer can complete the chain on a clean checkout where fsa has
///      not been compiled yet.
///   3. Inject the runtime wiring into `lib/main.dart` via
///      [MainDartEditor]: imports plus the `kDebugMode`-gated
///      [TelescopePlugin.install] + [ExceptionWatcher] + [DumpWatcher]
///      block before `runApp(`. When the consumer's pubspec lists `magic_devtools`
///      as a dependency AND `lib/main.dart` contains an `await Magic.init(`
///      call, also injects `MagicTelescopeIntegration.install()` after it.
///      All steps idempotent; re-runs are no-ops.
///
/// Steps 1 and 2 are invoked as subprocesses so this command does not
/// depend on the consumer wrapper already wiring `TelescopeArtisanProvider`
/// (the bootstrap chicken-and-egg case). Step 3 calls [MainDartEditor]
/// directly because it runs in the same process as the wrapper.
class TelescopeInstallCommand extends ArtisanCommand {
  @override
  String get name => 'telescope:install';

  @override
  String get description =>
      'Bootstrap fluttersdk_telescope in the current project (scaffolds '
      'consumer wrapper if missing, then registers the plugin).';

  @override
  CommandBoot get boot => CommandBoot.none;

  /// Hook for tests to inject a custom subprocess runner without touching
  /// the live Dart toolchain. Defaults to [Process.run].
  static Future<ProcessResult> Function(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) processRunner = _defaultProcessRunner;

  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) =>
      Process.run(executable, arguments,
          workingDirectory: workingDirectory, runInShell: false);

  /// Hook for tests to override the wrapper-presence check (default: real
  /// `bin/dispatcher.dart` File existence in the cwd). The dispatcher is the
  /// canonical artisan v3 wrapper produced by `dart run fluttersdk_artisan
  /// install`; the legacy `bin/artisan.dart` name no longer applies.
  static bool Function() wrapperExistsCheck = _defaultWrapperExistsCheck;

  static bool _defaultWrapperExistsCheck() =>
      File('bin/dispatcher.dart').existsSync();

  @override
  Future<int> handle(ArtisanContext ctx) async {
    // 1. Scaffold the consumer wrapper when missing. Re-runs are skipped so
    //    repeated `telescope:install` invocations on an already-bootstrapped
    //    project stay idempotent.
    if (!wrapperExistsCheck()) {
      ctx.output.info('Consumer wrapper missing; running install...');
      final scaffold = await processRunner(
        'dart',
        ['run', 'fluttersdk_telescope', 'install'],
      );
      stdout.write(scaffold.stdout);
      stderr.write(scaffold.stderr);
      if (scaffold.exitCode != 0) {
        ctx.output.error('install failed (exit ${scaffold.exitCode}).');
        return scaffold.exitCode;
      }
    } else {
      ctx.output.info('Consumer wrapper already present; skipping install.');
    }

    // 2. Register fluttersdk_telescope via plugin:install. Reads the
    //    install.yaml manifest shipped in this package and writes the entry
    //    to .artisan/plugins.json + regenerates lib/app/_plugins.g.dart.
    //    Invoked via `dart run fluttersdk_telescope` (the telescope CLI
    //    wrapper which preloads `TelescopeArtisanProvider` and sets
    //    `delegateToConsumer: false`) so the chain works on a clean
    //    checkout without depending on the AOT-compiled `bin/fsa`.
    ctx.output.info('Registering fluttersdk_telescope via plugin:install...');
    final install = await processRunner(
      'dart',
      ['run', 'fluttersdk_telescope', 'plugin:install', 'fluttersdk_telescope'],
    );
    stdout.write(install.stdout);
    stderr.write(install.stderr);
    if (install.exitCode != 0) {
      ctx.output.error('plugin:install failed (exit ${install.exitCode}).');
      return install.exitCode;
    }

    // 3. Wire the runtime install into lib/main.dart. Fail-soft: when the
    //    file is absent or the `runApp(` anchor is missing, log and continue;
    //    the consumer can wire by hand following the post_install message.
    final mainDart = File('lib/main.dart');
    if (!mainDart.existsSync()) {
      ctx.output.info(
          'lib/main.dart not found; runtime wiring SKIPPED. Wire manually:'
          ' import fluttersdk_telescope + TelescopePlugin.install() + watchers'
          ' before runApp().');
    } else {
      _injectRuntimeWiring(ctx, mainDart.path);
    }

    ctx.output.success('telescope:install complete.');
    return 0;
  }

  /// Step 3 ; idempotent inject of telescope runtime wiring into
  /// `lib/main.dart`. Three sub-steps:
  ///
  ///   3a. Add the two required imports (kDebugMode + telescope barrel).
  ///   3b. Inject `WidgetsFlutterBinding.ensureInitialized()` (skip when
  ///       already present) + the `kDebugMode`-gated telescope block before
  ///       the canonical install anchor: `await Magic.init(` on Magic-stack
  ///       apps (so ExceptionWatcher captures Magic boot errors), otherwise
  ///       `runApp(` for vanilla Flutter apps.
  ///   3c. When pubspec has `magic_devtools:` AND main.dart has `await Magic.init(`,
  ///       inject `MagicTelescopeIntegration.install()` after that call.
  static void _injectRuntimeWiring(ArtisanContext ctx, String mainDartPath) {
    ctx.output.info('Wiring TelescopePlugin into $mainDartPath...');

    // 3a. Imports first. ConfigEditor.addImportToFile (delegated by
    //     MainDartEditor.addImport) is idempotent on duplicates.
    MainDartEditor.addImport(
      mainDartPath,
      "import 'package:flutter/foundation.dart' show kDebugMode;",
    );
    MainDartEditor.addImport(
      mainDartPath,
      "import 'package:fluttersdk_telescope/telescope.dart';",
    );

    // 3b. Read once, choose the correct anchor, transform via two
    //     pure-functional injects (idempotent: each helper checks
    //     `source.contains(snippet)` before inserting), write back when
    //     changed.
    var source = FileHelper.readFile(mainDartPath);
    final before = source;

    // Magic apps run TelescopePlugin.install BEFORE `await Magic.init(` so
    // ExceptionWatcher catches boot errors; vanilla apps inject before
    // `runApp(`. Detect via substring match on the magic boot call.
    final hasMagicInit = source.contains('await Magic.init(');
    final anchor = hasMagicInit ? 'await Magic.init(' : 'runApp(';

    // Magic apps already call WidgetsFlutterBinding.ensureInitialized()
    // before Magic.init, so skip the inject when it is already present
    // (avoids a duplicate call right above the existing one).
    if (!source.contains('WidgetsFlutterBinding.ensureInitialized()')) {
      source = MainDartEditor.injectBeforeAnchor(
        source: source,
        anchor: anchor,
        snippet: '  WidgetsFlutterBinding.ensureInitialized();\n',
      );
    }

    source = MainDartEditor.injectBeforeAnchor(
      source: source,
      anchor: anchor,
      snippet: '  if (kDebugMode) {\n'
          '    TelescopePlugin.install();\n'
          '    TelescopePlugin.registerWatcher(ExceptionWatcher());\n'
          '    TelescopePlugin.registerWatcher(DumpWatcher());\n'
          '  }\n',
    );

    if (source != before) {
      FileHelper.writeFile(mainDartPath, source);
    }

    // 3c. Magic-side coordinated wiring when the consumer pulls in magic_devtools.
    //     Detect via pubspec.yaml; skip silently when magic_devtools is not a dep or
    //     when main.dart has no Magic.init() anchor (vanilla Flutter app).
    if (hasMagicInit && _hasMagicDevtoolsDep()) {
      MainDartEditor.addImport(
        mainDartPath,
        "import 'package:magic_devtools/telescope.dart';",
      );
      try {
        MainDartEditor.injectAfterMagicInit(
          mainDartPath,
          '  if (kDebugMode) {\n'
          '    MagicTelescopeIntegration.install();\n'
          '  }\n',
        );
      } on StateError {
        // No Magic.init() call yet; user has not bootstrapped magic.
        // Telescope's vanilla wiring above is enough on its own.
      }
    }
  }

  /// Returns true when the consumer's pubspec.yaml lists `magic_devtools:`
  /// (the package that ships MagicTelescopeIntegration) under `dependencies:`
  /// or `dev_dependencies:` (2-space indent).
  static bool _hasMagicDevtoolsDep() {
    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) return false;
    return RegExp(r'\n  magic_devtools:').hasMatch(pubspec.readAsStringSync());
  }
}
