import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/commands/telescope_install_command.dart';

/// Recording subprocess runner ; captures every `(executable, args)` call so
/// tests can assert ordering and per-call exit codes without spawning the
/// real Dart toolchain.
class _RecordingRunner {
  _RecordingRunner({this.exits = const <int>[]});

  /// Per-call exit codes consumed in FIFO order. Missing entries default to 0.
  final List<int> exits;
  int _i = 0;

  final List<List<String>> calls = <List<String>>[];

  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    calls.add(<String>[executable, ...arguments]);
    final code = _i < exits.length ? exits[_i++] : 0;
    return ProcessResult(0, code, '', code == 0 ? '' : 'mock-stderr');
  }
}

/// Seed [tempDir] with a stub `lib/main.dart` carrying [mainDartContents] +
/// a `pubspec.yaml` that lists [pubspecDeps] entries under `dependencies:`.
///
/// Returns the absolute path to the seeded main.dart. Callers run the
/// command with `Directory.current` switched to [tempDir] so the source's
/// relative `File('lib/main.dart')` + `File('pubspec.yaml')` lookups
/// (telescope_install_command.dart L107 + L209) resolve against the seed.
String _seedProject(
  Directory tempDir, {
  required String mainDartContents,
  Map<String, String> pubspecDeps = const {},
}) {
  final mainDartPath = '${tempDir.path}/lib/main.dart';
  Directory('${tempDir.path}/lib').createSync(recursive: true);
  File(mainDartPath).writeAsStringSync(mainDartContents);
  final depsBlock =
      pubspecDeps.entries.map((e) => '  ${e.key}: ${e.value}').join('\n');
  final pubspec = <String>[
    'name: stub_app',
    'environment:',
    '  sdk: ">=3.4.0 <4.0.0"',
    'dependencies:',
    '  flutter:',
    '    sdk: flutter',
    if (depsBlock.isNotEmpty) depsBlock,
    '',
  ].join('\n');
  File('${tempDir.path}/pubspec.yaml').writeAsStringSync(pubspec);
  return mainDartPath;
}

// Capture the production defaults at library load so tearDown can restore
// them. Static fields would otherwise leak each test's override into the
// next via the singleton static surface.
final _originalProcessRunner = TelescopeInstallCommand.processRunner;
final _originalWrapperExistsCheck = TelescopeInstallCommand.wrapperExistsCheck;

void main() {
  group('TelescopeInstallCommand', () {
    tearDown(() {
      TelescopeInstallCommand.processRunner = _originalProcessRunner;
      TelescopeInstallCommand.wrapperExistsCheck = _originalWrapperExistsCheck;
    });

    // -------------------------------------------------------------------------
    // Metadata
    // -------------------------------------------------------------------------

    test('name is telescope:install', () {
      expect(TelescopeInstallCommand().name, equals('telescope:install'));
    });

    test('boot is CommandBoot.none (does not require a running app)', () {
      expect(TelescopeInstallCommand().boot, equals(CommandBoot.none));
    });

    test('description is non-empty', () {
      expect(TelescopeInstallCommand().description, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // Wrapper-presence branch: skip consumer:scaffold when wrapper exists
    // -------------------------------------------------------------------------

    test(
        'skips consumer:scaffold when bin/artisan.dart already exists; '
        'plugin:install still runs', () async {
      final runner = _RecordingRunner();
      TelescopeInstallCommand.processRunner = runner.run;
      TelescopeInstallCommand.wrapperExistsCheck = () => true;

      final exit = await TelescopeInstallCommand().handle(
        ArtisanContext.bare(MapInput(const {}), BufferedOutput()),
      );

      expect(exit, equals(0));
      expect(runner.calls, hasLength(1),
          reason: 'only plugin:install should run when wrapper present');
      expect(
          runner.calls.single,
          equals([
            'dart',
            'run',
            'fluttersdk_artisan',
            'plugin:install',
            'fluttersdk_telescope'
          ]));
    });

    // -------------------------------------------------------------------------
    // Wrapper-missing branch: run consumer:scaffold then plugin:install
    // -------------------------------------------------------------------------

    test(
        'runs consumer:scaffold then plugin:install when bin/artisan.dart '
        'is missing (correct ordering)', () async {
      final runner = _RecordingRunner();
      TelescopeInstallCommand.processRunner = runner.run;
      TelescopeInstallCommand.wrapperExistsCheck = () => false;

      final exit = await TelescopeInstallCommand().handle(
        ArtisanContext.bare(MapInput(const {}), BufferedOutput()),
      );

      expect(exit, equals(0));
      expect(runner.calls, hasLength(2));
      expect(runner.calls[0],
          equals(['dart', 'run', 'fluttersdk_artisan', 'consumer:scaffold']),
          reason: 'consumer:scaffold must run first');
      expect(
          runner.calls[1],
          equals([
            'dart',
            'run',
            'fluttersdk_artisan',
            'plugin:install',
            'fluttersdk_telescope'
          ]),
          reason: 'plugin:install must run after scaffold');
    });

    // -------------------------------------------------------------------------
    // Failure propagation
    // -------------------------------------------------------------------------

    test(
        'returns scaffold exit code (and skips plugin:install) when '
        'consumer:scaffold fails', () async {
      final runner = _RecordingRunner(exits: <int>[2]);
      TelescopeInstallCommand.processRunner = runner.run;
      TelescopeInstallCommand.wrapperExistsCheck = () => false;

      final exit = await TelescopeInstallCommand().handle(
        ArtisanContext.bare(MapInput(const {}), BufferedOutput()),
      );

      expect(exit, equals(2));
      expect(runner.calls, hasLength(1),
          reason:
              'plugin:install must not run after scaffold failure (fail-fast)');
      expect(runner.calls.single.contains('consumer:scaffold'), isTrue);
    });

    test(
        'returns plugin:install exit code when scaffold passes but '
        'plugin:install fails', () async {
      // First call (scaffold) succeeds; second call (plugin:install) fails.
      final runner = _RecordingRunner(exits: <int>[0, 3]);
      TelescopeInstallCommand.processRunner = runner.run;
      TelescopeInstallCommand.wrapperExistsCheck = () => false;

      final exit = await TelescopeInstallCommand().handle(
        ArtisanContext.bare(MapInput(const {}), BufferedOutput()),
      );

      expect(exit, equals(3));
      expect(runner.calls, hasLength(2));
    });

    // -------------------------------------------------------------------------
    // Magic-stack branch: pubspec lists `magic:` + main.dart has
    // `await Magic.init(` ; injected magic import must reference the new
    // opt-in sub-barrel (`package:magic/telescope_integration.dart`), NOT the
    // legacy main barrel (`package:magic/magic.dart`).
    // -------------------------------------------------------------------------

    test(
      'magic-stack app: injects import for the telescope_integration sub-barrel '
      '(not the legacy magic.dart main barrel) plus the integration install '
      'call after Magic.init',
      () async {
        final tempDir =
            Directory.systemTemp.createTempSync('telescope_install_magic_');
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final mainDartPath = _seedProject(
          tempDir,
          pubspecDeps: const {'magic': 'any'},
          mainDartContents: '''
import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Magic.init(configFactories: [() => {}]);
  runApp(const MagicApplication());
}
''',
        );

        // Stub subprocesses (consumer:scaffold + plugin:install) so the
        // command flows straight into step 3 (lib/main.dart wiring).
        final runner = _RecordingRunner();
        TelescopeInstallCommand.processRunner = runner.run;
        // Skip consumer:scaffold; only plugin:install will record.
        TelescopeInstallCommand.wrapperExistsCheck = () => true;

        // Switch cwd to the seeded temp dir so the source's relative
        // `File('lib/main.dart')` (L107) + `File('pubspec.yaml')` (L209)
        // lookups resolve against the fixture instead of the host project.
        final previousCwd = Directory.current;
        Directory.current = tempDir;
        addTearDown(() => Directory.current = previousCwd);

        final exit = await TelescopeInstallCommand().handle(
          ArtisanContext.bare(MapInput(const {}), BufferedOutput()),
        );
        expect(exit, equals(0));

        final result = File(mainDartPath).readAsStringSync();

        // The magic-detect branch (L187 ; _hasMagicDep + Magic.init anchor)
        // must inject the opt-in sub-barrel; never the legacy main barrel.
        expect(
          result.contains("import 'package:magic/telescope_integration.dart';"),
          isTrue,
          reason:
              'magic-stack inject must reference the new telescope_integration '
              'sub-barrel, not the legacy magic.dart main barrel',
        );

        // Parity check: the integration install call still lands after
        // Magic.init() (snippet body at source L196 is unchanged).
        expect(
          result.contains('MagicTelescopeIntegration.install();'),
          isTrue,
          reason: 'snippet body at telescope_install_command.dart L196 is '
              'unchanged; only the import literal at L190 moves',
        );

        // Sanity: plugin:install ran (wrapper present, scaffold skipped).
        expect(runner.calls, hasLength(1));
        expect(runner.calls.single.contains('plugin:install'), isTrue);
      },
    );
  });
}
