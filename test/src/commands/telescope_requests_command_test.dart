import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/commands/telescope_requests_command.dart';

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
  Future<T> callExtension<T>(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    lastMethod = method;
    lastParams = params;
    return _response as T;
  }
}

void main() {
  group('TelescopeRequestsCommand', () {
    // -------------------------------------------------------------------------
    // Metadata
    // -------------------------------------------------------------------------

    test('name is telescope:requests', () {
      expect(TelescopeRequestsCommand().name, equals('telescope:requests'));
    });

    test('boot is CommandBoot.connected', () {
      expect(TelescopeRequestsCommand().boot, equals(CommandBoot.connected));
    });

    test('description is non-empty', () {
      expect(TelescopeRequestsCommand().description, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // ArgParser flags
    // -------------------------------------------------------------------------

    test('configure registers --limit option with default 50', () {
      final parser = ArgParser();

      TelescopeRequestsCommand().configure(parser);

      expect(parser.options.containsKey('limit'), isTrue);
      expect(parser.options['limit']!.defaultsTo, equals('50'));
    });

    test('configure does not register --level option', () {
      final parser = ArgParser();

      TelescopeRequestsCommand().configure(parser);

      expect(parser.options.containsKey('level'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Extension method forwarding
    // -------------------------------------------------------------------------

    test('handle calls ext.telescope.requests', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {'records': <dynamic>[]},
      );

      await TelescopeRequestsCommand().handle(ctx);

      expect(ctx.lastMethod, equals('ext.telescope.requests'));
    });

    test('handle forwards limit param when provided', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {'limit': '20'}),
        output: output,
        response: const {'records': <dynamic>[]},
      );

      await TelescopeRequestsCommand().handle(ctx);

      expect(ctx.lastParams, containsPair('limit', '20'));
    });

    // -------------------------------------------------------------------------
    // Output formatting
    // -------------------------------------------------------------------------

    test('handle emits warning when records list is empty', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {'records': <dynamic>[]},
      );

      final code = await TelescopeRequestsCommand().handle(ctx);

      expect(code, equals(0));
      expect(output.content, contains('No HTTP records'));
    });

    test('handle formats method, url, statusCode, durationMs per entry',
        () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: {
          'records': [
            {
              'timestamp': '2026-05-18T12:00:00.000Z',
              'method': 'GET',
              'url': 'https://api.example.com/monitors',
              'statusCode': 200,
              'durationMs': 142,
            },
          ],
        },
      );

      final code = await TelescopeRequestsCommand().handle(ctx);

      expect(code, equals(0));
      expect(output.content, contains('GET'));
      expect(output.content, contains('https://api.example.com/monitors'));
      expect(output.content, contains('200'));
      expect(output.content, contains('142'));
    });

    test('handle returns 0 on success', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {'records': <dynamic>[]},
      );

      final code = await TelescopeRequestsCommand().handle(ctx);

      expect(code, equals(0));
    });
  });
}
