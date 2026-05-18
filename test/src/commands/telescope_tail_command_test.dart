import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/commands/telescope_tail_command.dart';

/// Stubs [ArtisanContext.callExtension] so tests never hit a real VM Service.
///
/// Records the last extension method name + params for assertion, then returns
/// the [_response] payload provided at construction.
class _StubContext extends ArtisanContext {
  _StubContext({
    required ArtisanInput input,
    required ArtisanOutput output,
    required Map<String, dynamic> response,
  })  : _response = response,
        super.bare(input, output);

  final Map<String, dynamic> _response;

  /// The most recent extension method forwarded to [callExtension].
  String? lastMethod;

  /// The most recent params forwarded to [callExtension].
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
  group('TelescopeTailCommand', () {
    // -------------------------------------------------------------------------
    // Metadata
    // -------------------------------------------------------------------------

    test('name is telescope:tail', () {
      expect(TelescopeTailCommand().name, equals('telescope:tail'));
    });

    test('boot is CommandBoot.connected', () {
      expect(TelescopeTailCommand().boot, equals(CommandBoot.connected));
    });

    test('description is non-empty', () {
      expect(TelescopeTailCommand().description, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // ArgParser flags
    // -------------------------------------------------------------------------

    test('configure registers --level option', () {
      final parser = ArgParser();

      TelescopeTailCommand().configure(parser);

      expect(parser.options.containsKey('level'), isTrue);
    });

    test('configure registers --limit option with default 50', () {
      final parser = ArgParser();

      TelescopeTailCommand().configure(parser);

      expect(parser.options.containsKey('limit'), isTrue);
      expect(parser.options['limit']!.defaultsTo, equals('50'));
    });

    // -------------------------------------------------------------------------
    // Extension method forwarding
    // -------------------------------------------------------------------------

    test('handle calls ext.telescope.console', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {'messages': <dynamic>[]},
      );

      await TelescopeTailCommand().handle(ctx);

      expect(ctx.lastMethod, equals('ext.telescope.console'));
    });

    test('handle forwards level param when provided', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {'level': 'warning'}),
        output: output,
        response: const {'messages': <dynamic>[]},
      );

      await TelescopeTailCommand().handle(ctx);

      expect(ctx.lastParams, containsPair('level', 'warning'));
    });

    test('handle forwards limit param when provided', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {'limit': '10'}),
        output: output,
        response: const {'messages': <dynamic>[]},
      );

      await TelescopeTailCommand().handle(ctx);

      expect(ctx.lastParams, containsPair('limit', '10'));
    });

    test('handle omits level from params when not provided', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {'messages': <dynamic>[]},
      );

      await TelescopeTailCommand().handle(ctx);

      expect(ctx.lastParams, isNot(contains('level')));
    });

    // -------------------------------------------------------------------------
    // Output formatting
    // -------------------------------------------------------------------------

    test('handle emits warning when messages list is empty', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {'messages': <dynamic>[]},
      );

      final code = await TelescopeTailCommand().handle(ctx);

      expect(code, equals(0));
      expect(output.content, contains('No log records'));
    });

    test('handle formats timestamp, level, loggerName, message per entry',
        () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: {
          'messages': [
            {
              'time': '2026-05-18T12:00:00.000Z',
              'level': 'INFO',
              'loggerName': 'MyApp',
              'message': 'App started',
            },
          ],
        },
      );

      final code = await TelescopeTailCommand().handle(ctx);

      expect(code, equals(0));
      expect(output.content, contains('2026-05-18T12:00:00.000Z'));
      expect(output.content, contains('[INFO]'));
      expect(output.content, contains('MyApp'));
      expect(output.content, contains('App started'));
    });

    test('handle returns 0 on success', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {'messages': <dynamic>[]},
      );

      final code = await TelescopeTailCommand().handle(ctx);

      expect(code, equals(0));
    });
  });
}
