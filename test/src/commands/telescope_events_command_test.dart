import 'dart:convert';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/commands/telescope_events_command.dart';

/// Stubs [ArtisanContext.callExtension] so tests never hit a real VM Service.
///
/// Answers each call with the next of [responses], repeating the last one, and
/// keeps a copy of every call's params in [calls].
class _StubContext extends ArtisanContext {
  _StubContext({
    required ArtisanInput input,
    required ArtisanOutput output,
    Map<String, dynamic>? response,
    List<Map<String, dynamic>>? responses,
    this.failOnCall,
  })  : _responses = responses ?? <Map<String, dynamic>>[response!],
        super.bare(input, output);

  final List<Map<String, dynamic>> _responses;

  /// The 1-based call that throws, as a lost VM Service connection does.
  final int? failOnCall;
  String? lastMethod;
  Map<String, dynamic>? lastParams;
  final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];

  @override
  Future<T> callExtension<T>(String method,
      [Map<String, dynamic>? params]) async {
    lastMethod = method;
    lastParams = params;
    calls.add(Map<String, dynamic>.of(params ?? <String, dynamic>{}));
    if (calls.length == failOnCall) throw StateError('The app is gone.');
    final index =
        calls.length <= _responses.length ? calls.length : _responses.length;
    return _responses[index - 1] as T;
  }
}

void main() {
  group('TelescopeEventsCommand', () {
    test('name is telescope:events', () {
      expect(TelescopeEventsCommand().name, equals('telescope:events'));
    });

    test('boot is CommandBoot.connected', () {
      expect(TelescopeEventsCommand().boot, equals(CommandBoot.connected));
    });

    test('description is non-empty', () {
      expect(TelescopeEventsCommand().description, isNotEmpty);
    });

    test('signature declares --limit option with default 50', () {
      expect(TelescopeEventsCommand().signature, contains('--limit=50'));
    });

    test('handle calls ext.telescope.events and forwards limit', () async {
      final ctx = _StubContext(
        input: MapInput(const {'limit': '20'}),
        output: BufferedOutput(),
        response: const {'events': <dynamic>[]},
      );

      await TelescopeEventsCommand().handle(ctx);

      expect(ctx.lastMethod, equals('ext.telescope.events'));
      expect(ctx.lastParams, containsPair('limit', '20'));
    });

    test('handle emits warning when the buffer is empty', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {'events': <dynamic>[]},
      );

      final code = await TelescopeEventsCommand().handle(ctx);

      expect(code, equals(0));
      expect(output.content, contains('No event records'));
    });

    test('handle formats event type, payload, listener count per entry',
        () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {
          'events': [
            {
              'time': '2026-09-28T10:00:00.000Z',
              'eventType': 'MonitorCreated',
              'payload': {'id': 7},
              'listenerCount': 2,
            },
          ],
        },
      );

      final code = await TelescopeEventsCommand().handle(ctx);

      expect(code, equals(0));
      expect(output.content, contains('MonitorCreated'));
      expect(output.content, contains('{id: 7}'));
      expect(output.content, contains('listeners=2'));
    });

    test('handle omits listeners when the count was not recorded', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
        response: const {
          'events': [
            {
              'time': '2026-09-28T10:00:00.000Z',
              'eventType': 'AuthLogin',
              'payload': <String, dynamic>{},
            },
          ],
        },
      );

      await TelescopeEventsCommand().handle(ctx);

      expect(output.content, contains('AuthLogin {}'));
      expect(output.content, isNot(contains('listeners=')));
    });

    test('signature declares --since, --type, --json and --follow', () {
      final signature = TelescopeEventsCommand().signature;

      expect(signature, contains('{--since='));
      expect(signature, contains('{--type='));
      expect(signature, contains('{--json'));
      expect(signature, contains('{--follow'));
    });

    test('handle forwards since and type when provided', () async {
      final ctx = _StubContext(
        input: MapInput(const {'since': '100', 'type': 'player.'}),
        output: BufferedOutput(),
        response: const {'events': <dynamic>[]},
      );

      await TelescopeEventsCommand().handle(ctx);

      expect(ctx.lastParams, containsPair('since', '100'));
      expect(ctx.lastParams, containsPair('type', 'player.'));
    });

    test('handle omits since and type when not provided', () async {
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: BufferedOutput(),
        response: const {'events': <dynamic>[]},
      );

      await TelescopeEventsCommand().handle(ctx);

      expect(ctx.lastParams, isNot(contains('since')));
      expect(ctx.lastParams, isNot(contains('type')));
    });

    test('--json prints one decodable JSON object per line with the payload',
        () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {'json': true}),
        output: output,
        response: const {
          'events': [
            {
              'time': '2026-09-28T10:00:00.000Z',
              'eventType': 'player.open',
              'payload': {
                'id': 7,
                'nested': {'ok': true}
              },
              'atUs': 100,
            },
            {
              'time': '2026-09-28T10:00:01.000Z',
              'eventType': 'player.stall',
              'payload': <String, dynamic>{},
              'atUs': 200,
            },
          ],
        },
      );

      final code = await TelescopeEventsCommand().handle(ctx);

      final lines = const LineSplitter().convert(output.content);
      expect(code, equals(0));
      expect(lines, hasLength(2));
      final decoded =
          lines.map((l) => jsonDecode(l) as Map<String, dynamic>).toList();
      expect(
          decoded.first['payload'],
          equals({
            'id': 7,
            'nested': {'ok': true}
          }));
      expect(decoded.last['eventType'], equals('player.stall'));
    });

    test('--json prints nothing when there are no records', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {'json': true}),
        output: output,
        response: const {'events': <dynamic>[]},
      );

      await TelescopeEventsCommand().handle(ctx);

      expect(output.content, isEmpty);
    });

    group('--follow', () {
      test('polls again from the cursor the first poll returned', () async {
        final delays = <Duration>[];
        final output = BufferedOutput();
        final ctx = _StubContext(
          input: MapInput(const {'follow': true, 'limit': '50'}),
          output: output,
          responses: const [
            {
              'events': [
                {'time': 't1', 'eventType': 'player.open', 'payload': {}},
              ],
              'cursor': 300,
            },
            {
              'events': [
                {'time': 't2', 'eventType': 'player.stall', 'payload': {}},
              ],
              'cursor': 400,
            },
          ],
        );

        final code = await TelescopeEventsCommand(
          delay: (Duration d) async => delays.add(d),
          shouldStop: (int polls) => polls >= 2,
        ).handle(ctx);

        expect(code, equals(0));
        expect(ctx.calls, hasLength(2));
        expect(ctx.calls.first, containsPair('limit', '50'));
        expect(ctx.calls.first, isNot(contains('since')));
        expect(ctx.calls.last, containsPair('since', '300'));
        expect(ctx.calls.last, isNot(contains('limit')));
        expect(delays, equals(const [Duration(seconds: 1)]));
        expect(output.content, contains('player.open'));
        expect(output.content, contains('player.stall'));
      });

      test('keeps the given since while no cursor has come back', () async {
        final ctx = _StubContext(
          input: MapInput(const {'follow': true, 'since': '100'}),
          output: BufferedOutput(),
          response: const {'events': <dynamic>[], 'cursor': 100},
        );

        await TelescopeEventsCommand(
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
          response: const {'events': <dynamic>[]},
        );

        await TelescopeEventsCommand(
          delay: (Duration d) async {},
          shouldStop: (int polls) => polls >= 2,
        ).handle(ctx);

        expect(output.content, isEmpty);
      });

      test('on the real clock polls again after a second until a read fails',
          () async {
        final ctx = _StubContext(
          input: MapInput(const {'follow': true}),
          output: BufferedOutput(),
          responses: const [
            {
              'events': <dynamic>[],
              'cursor': 300,
            },
          ],
          failOnCall: 2,
        );

        await expectLater(
          TelescopeEventsCommand().handle(ctx),
          throwsStateError,
        );

        expect(ctx.calls, hasLength(2));
        expect(ctx.calls.last, containsPair('since', '300'));
      });

      test('without --follow polls exactly once', () async {
        final ctx = _StubContext(
          input: MapInput(const {}),
          output: BufferedOutput(),
          response: const {'events': <dynamic>[]},
        );

        await TelescopeEventsCommand(
          delay: (Duration d) async {},
          shouldStop: (int polls) => false,
        ).handle(ctx);

        expect(ctx.calls, hasLength(1));
      });
    });
  });
}
