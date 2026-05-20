import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/commands/telescope_caches_command.dart';

class _StubContext extends ArtisanContext {
  _StubContext({
    required ArtisanInput input,
    required ArtisanOutput output,
    required Map<String, dynamic> response,
  })  : _response = response,
        super.bare(input, output);

  final Map<String, dynamic> _response;
  String? lastMethod;
  Map<String, dynamic>? lastParams;

  @override
  Future<T> callExtension<T>(String method,
      [Map<String, dynamic>? params]) async {
    lastMethod = method;
    lastParams = params;
    return _response as T;
  }
}

void main() {
  group('TelescopeCachesCommand', () {
    test('name is telescope:caches', () {
      expect(TelescopeCachesCommand().name, equals('telescope:caches'));
    });

    test('boot is CommandBoot.connected', () {
      expect(TelescopeCachesCommand().boot, equals(CommandBoot.connected));
    });

    test('description is non-empty', () {
      expect(TelescopeCachesCommand().description, isNotEmpty);
    });

    test('signature declares --limit option with default 50', () {
      expect(TelescopeCachesCommand().signature, contains('--limit=50'));
    });

    test('handle calls ext.telescope.caches', () async {
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: BufferedOutput(),
        response: const {'caches': <dynamic>[]},
      );

      await TelescopeCachesCommand().handle(ctx);

      expect(ctx.lastMethod, equals('ext.telescope.caches'));
    });

    test('handle forwards limit param when provided', () async {
      final ctx = _StubContext(
        input: MapInput(const {'limit': '20'}),
        output: BufferedOutput(),
        response: const {'caches': <dynamic>[]},
      );

      await TelescopeCachesCommand().handle(ctx);

      expect(ctx.lastParams, containsPair('limit', '20'));
    });

    test('handle emits warning when caches list is empty', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {'caches': <dynamic>[]},
      );

      final code = await TelescopeCachesCommand().handle(ctx);

      expect(code, equals(0));
      expect(output.content, contains('No cache records'));
    });

    test('handle formats time, operation, key, ttl per entry', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {
          'caches': [
            {
              'time': '2026-05-19T03:00:00.000Z',
              'operation': 'put',
              'key': 'demo-key',
              'ttlMs': 300000,
            },
            {
              'time': '2026-05-19T03:00:01.000Z',
              'operation': 'hit',
              'key': 'demo-key',
            },
          ],
        },
      );

      final code = await TelescopeCachesCommand().handle(ctx);

      expect(code, equals(0));
      expect(output.content, contains('[put] demo-key'));
      expect(output.content, contains('ttl=300000ms'));
      expect(output.content, contains('[hit] demo-key'));
    });

    test('handle returns 0 on success', () async {
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: BufferedOutput(),
        response: const {'caches': <dynamic>[]},
      );

      expect(await TelescopeCachesCommand().handle(ctx), equals(0));
    });
  });
}
