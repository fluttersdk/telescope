import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/commands/telescope_queries_command.dart';

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
  group('TelescopeQueriesCommand', () {
    test('name is telescope:queries', () {
      expect(TelescopeQueriesCommand().name, equals('telescope:queries'));
    });

    test('boot is CommandBoot.connected', () {
      expect(TelescopeQueriesCommand().boot, equals(CommandBoot.connected));
    });

    test('description is non-empty', () {
      expect(TelescopeQueriesCommand().description, isNotEmpty);
    });

    test('signature declares --limit option with default 50', () {
      expect(TelescopeQueriesCommand().signature, contains('--limit=50'));
    });

    test('handle calls ext.telescope.queries', () async {
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: BufferedOutput(),
        response: const {'queries': <dynamic>[]},
      );

      await TelescopeQueriesCommand().handle(ctx);

      expect(ctx.lastMethod, equals('ext.telescope.queries'));
    });

    test('handle forwards limit param when provided', () async {
      final ctx = _StubContext(
        input: MapInput(const {'limit': '20'}),
        output: BufferedOutput(),
        response: const {'queries': <dynamic>[]},
      );

      await TelescopeQueriesCommand().handle(ctx);

      expect(ctx.lastParams, containsPair('limit', '20'));
    });

    test('handle emits warning when queries list is empty', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {'queries': <dynamic>[]},
      );

      final code = await TelescopeQueriesCommand().handle(ctx);

      expect(code, equals(0));
      expect(output.content, contains('No DB query records'));
    });

    test('handle formats sql, connection, bindings, timeMs per entry',
        () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {
          'queries': [
            {
              'time': '2026-05-19T03:00:00.000Z',
              'sql': 'SELECT * FROM monitors WHERE id = ?',
              'bindings': [42],
              'timeMs': 12,
              'connectionName': 'primary',
            },
          ],
        },
      );

      final code = await TelescopeQueriesCommand().handle(ctx);

      expect(code, equals(0));
      expect(output.content, contains('SELECT * FROM monitors'));
      expect(output.content, contains('[primary]'));
      expect(output.content, contains('[42]'));
      expect(output.content, contains('12ms'));
    });

    test('handle returns 0 on success', () async {
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: BufferedOutput(),
        response: const {'queries': <dynamic>[]},
      );

      expect(await TelescopeQueriesCommand().handle(ctx), equals(0));
    });
  });
}
