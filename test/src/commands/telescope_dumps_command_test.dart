import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/commands/telescope_dumps_command.dart';

/// Stubs [ArtisanContext.callExtension] so tests never hit a real VM Service.
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
  group('TelescopeDumpsCommand', () {
    test('name is telescope:dumps', () {
      expect(TelescopeDumpsCommand().name, equals('telescope:dumps'));
    });

    test('boot is CommandBoot.connected', () {
      expect(TelescopeDumpsCommand().boot, equals(CommandBoot.connected));
    });

    test('description is non-empty', () {
      expect(TelescopeDumpsCommand().description, isNotEmpty);
    });

    test('signature declares --limit option with default 50', () {
      expect(TelescopeDumpsCommand().signature, contains('--limit=50'));
    });

    test('handle calls ext.telescope.dumps and forwards limit', () async {
      final ctx = _StubContext(
        input: MapInput(const {'limit': '20'}),
        output: BufferedOutput(),
        response: const {'dumps': <dynamic>[]},
      );

      await TelescopeDumpsCommand().handle(ctx);

      expect(ctx.lastMethod, equals('ext.telescope.dumps'));
      expect(ctx.lastParams, containsPair('limit', '20'));
    });

    test('handle emits warning when the buffer is empty', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {'dumps': <dynamic>[]},
      );

      final code = await TelescopeDumpsCommand().handle(ctx);

      expect(code, equals(0));
      expect(output.content, contains('No dump records'));
    });

    test('handle formats time and message per entry', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {
          'dumps': [
            {
              'time': '2026-09-28T10:00:00.000Z',
              'message': 'poller tick 3',
            },
          ],
        },
      );

      final code = await TelescopeDumpsCommand().handle(ctx);

      expect(code, equals(0));
      expect(output.content, contains('2026-09-28T10:00:00.000Z'));
      expect(output.content, contains('poller tick 3'));
    });
  });
}
