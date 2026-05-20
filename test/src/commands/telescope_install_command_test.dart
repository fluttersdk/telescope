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

void main() {
  group('TelescopeInstallCommand', () {
    tearDown(() {
      // Restore module-level hooks between tests; they are static fields, so
      // a test that mutates them leaks into the next without this reset.
      TelescopeInstallCommand.processRunner =
          TelescopeInstallCommand.processRunner; // no-op; left for clarity
      TelescopeInstallCommand.wrapperExistsCheck =
          () => File('bin/artisan.dart').existsSync();
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
  });
}
