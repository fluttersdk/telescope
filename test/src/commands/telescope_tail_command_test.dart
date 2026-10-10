import 'dart:convert';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/commands/telescope_tail_command.dart';

/// Stubs [ArtisanContext.callExtension] so tests never hit a real VM Service.
///
/// Answers each call with the next of [responses], repeating the last one, and
/// keeps a copy of every call's params in [calls]. [lastMethod] and
/// [lastParams] hold the most recent call.
class _StubContext extends ArtisanContext {
  _StubContext({
    required ArtisanInput input,
    required ArtisanOutput output,
    Map<String, dynamic>? response,
    List<Map<String, dynamic>>? responses,
  })  : _responses = responses ?? <Map<String, dynamic>>[response!],
        super.bare(input, output);

  final List<Map<String, dynamic>> _responses;

  /// The most recent extension method forwarded to [callExtension].
  String? lastMethod;

  /// The most recent params forwarded to [callExtension].
  Map<String, dynamic>? lastParams;

  /// A copy of the params of every [callExtension] call, in order.
  final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];

  @override
  Future<T> callExtension<T>(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    lastMethod = method;
    lastParams = params;
    calls.add(Map<String, dynamic>.of(params ?? <String, dynamic>{}));
    final index =
        calls.length <= _responses.length ? calls.length : _responses.length;
    return _responses[index - 1] as T;
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

    test('configure registers --since, --logger, --json and --follow', () {
      final parser = ArgParser();

      TelescopeTailCommand().configure(parser);

      expect(parser.options.containsKey('since'), isTrue);
      expect(parser.options.containsKey('logger'), isTrue);
      expect(parser.options['json']!.isFlag, isTrue);
      expect(parser.options['follow']!.isFlag, isTrue);
    });

    test('handle forwards since and logger when provided', () async {
      final ctx = _StubContext(
        input: MapInput(const {'since': '100', 'logger': 'mpv'}),
        output: BufferedOutput(),
        response: const {'messages': <dynamic>[]},
      );

      await TelescopeTailCommand().handle(ctx);

      expect(ctx.lastParams, containsPair('since', '100'));
      expect(ctx.lastParams, containsPair('logger', 'mpv'));
    });

    test('handle omits since and logger when not provided', () async {
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: BufferedOutput(),
        response: const {'messages': <dynamic>[]},
      );

      await TelescopeTailCommand().handle(ctx);

      expect(ctx.lastParams, isNot(contains('since')));
      expect(ctx.lastParams, isNot(contains('logger')));
    });

    test('--json prints one decodable JSON object per line', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {'json': true}),
        output: output,
        response: const {
          'messages': [
            {
              'time': '2026-05-18T12:00:00.000Z',
              'level': 'INFO',
              'loggerName': 'mpv',
              'message': 'first',
              'atUs': 100,
            },
            {
              'time': '2026-05-18T12:00:01.000Z',
              'level': 'WARNING',
              'loggerName': 'mpv',
              'message': 'second "quoted"',
              'atUs': 200,
            },
          ],
        },
      );

      final code = await TelescopeTailCommand().handle(ctx);

      final lines = const LineSplitter().convert(output.content);
      expect(code, equals(0));
      expect(lines, hasLength(2));
      final decoded =
          lines.map((l) => jsonDecode(l) as Map<String, dynamic>).toList();
      expect(decoded.first['message'], equals('first'));
      expect(decoded.last['message'], equals('second "quoted"'));
    });

    test('--json prints nothing when there are no records', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {'json': true}),
        output: output,
        response: const {'messages': <dynamic>[]},
      );

      await TelescopeTailCommand().handle(ctx);

      expect(output.content, isEmpty);
    });

    group('--follow', () {
      test('polls again from the cursor the first poll returned', () async {
        final delays = <Duration>[];
        final output = BufferedOutput();
        final ctx = _StubContext(
          input: MapInput(const {
            'follow': true,
            'limit': '50',
            'logger': 'mpv',
          }),
          output: output,
          responses: const [
            {
              'messages': [
                {
                  'time': 't1',
                  'level': 'INFO',
                  'loggerName': 'mpv',
                  'message': 'first',
                },
              ],
              'cursor': 300,
            },
            {
              'messages': [
                {
                  'time': 't2',
                  'level': 'INFO',
                  'loggerName': 'mpv',
                  'message': 'second',
                },
              ],
              'cursor': 400,
            },
          ],
        );

        final code = await TelescopeTailCommand(
          delay: (Duration d) async => delays.add(d),
          shouldStop: (int polls) => polls >= 2,
        ).handle(ctx);

        expect(code, equals(0));
        expect(ctx.calls, hasLength(2));
        expect(ctx.calls.first, containsPair('limit', '50'));
        expect(ctx.calls.first, isNot(contains('since')));
        expect(ctx.calls.last, containsPair('since', '300'));
        expect(ctx.calls.last, containsPair('logger', 'mpv'));
        expect(ctx.calls.last, isNot(contains('limit')));
        expect(delays, equals(const [Duration(seconds: 1)]));
        expect(output.content, contains('first'));
        expect(output.content, contains('second'));
      });

      test('keeps the given since while no cursor has come back', () async {
        final ctx = _StubContext(
          input: MapInput(const {'follow': true, 'since': '100'}),
          output: BufferedOutput(),
          response: const {'messages': <dynamic>[], 'cursor': 100},
        );

        await TelescopeTailCommand(
          delay: (Duration d) async {},
          shouldStop: (int polls) => polls >= 3,
        ).handle(ctx);

        expect(ctx.calls.map((c) => c['since']), everyElement(equals('100')));
      });

      test('does not warn about an empty poll', () async {
        final output = BufferedOutput();
        final ctx = _StubContext(
          input: MapInput(const {'follow': true}),
          output: output,
          response: const {'messages': <dynamic>[]},
        );

        await TelescopeTailCommand(
          delay: (Duration d) async {},
          shouldStop: (int polls) => polls >= 2,
        ).handle(ctx);

        expect(output.content, isEmpty);
      });

      test('without --follow polls exactly once', () async {
        final ctx = _StubContext(
          input: MapInput(const {}),
          output: BufferedOutput(),
          response: const {'messages': <dynamic>[]},
        );

        await TelescopeTailCommand(
          delay: (Duration d) async {},
          shouldStop: (int polls) => false,
        ).handle(ctx);

        expect(ctx.calls, hasLength(1));
      });
    });
  });
}
