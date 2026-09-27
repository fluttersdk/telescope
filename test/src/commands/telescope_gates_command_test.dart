import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/commands/telescope_gates_command.dart';

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
  group('TelescopeGatesCommand', () {
    test('name is telescope:gates', () {
      expect(TelescopeGatesCommand().name, equals('telescope:gates'));
    });

    test('boot is CommandBoot.connected', () {
      expect(TelescopeGatesCommand().boot, equals(CommandBoot.connected));
    });

    test('description is non-empty', () {
      expect(TelescopeGatesCommand().description, isNotEmpty);
    });

    test('signature declares --limit option with default 50', () {
      expect(TelescopeGatesCommand().signature, contains('--limit=50'));
    });

    test('handle calls ext.telescope.gates and forwards limit', () async {
      final ctx = _StubContext(
        input: MapInput(const {'limit': '20'}),
        output: BufferedOutput(),
        response: const {'gates': <dynamic>[]},
      );

      await TelescopeGatesCommand().handle(ctx);

      expect(ctx.lastMethod, equals('ext.telescope.gates'));
      expect(ctx.lastParams, containsPair('limit', '20'));
    });

    test('handle emits warning when the buffer is empty', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {'gates': <dynamic>[]},
      );

      final code = await TelescopeGatesCommand().handle(ctx);

      expect(code, equals(0));
      expect(output.content, contains('No gate records'));
    });

    test('handle formats ability, verdict, user, arguments per entry',
        () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {
          'gates': [
            {
              'time': '2026-09-28T10:00:00.000Z',
              'ability': 'monitors.update',
              'result': false,
              'arguments': ['Monitor'],
              'userId': '3',
            },
          ],
        },
      );

      final code = await TelescopeGatesCommand().handle(ctx);

      expect(code, equals(0));
      expect(output.content, contains('monitors.update'));
      expect(output.content, contains('denied'));
      expect(output.content, contains('user=3'));
      expect(output.content, contains('[Monitor]'));
    });

    test('handle prints allowed and omits user when none was authenticated',
        () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {
          'gates': [
            {
              'time': '2026-09-28T10:00:00.000Z',
              'ability': 'monitors.view',
              'result': true,
              'arguments': <dynamic>[],
            },
          ],
        },
      );

      await TelescopeGatesCommand().handle(ctx);

      expect(output.content, contains('monitors.view allowed arguments=[]'));
      expect(output.content, isNot(contains('user=')));
    });
  });
}
