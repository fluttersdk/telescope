import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/commands/telescope_events_command.dart';

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
  group('TelescopeEventsCommand', () {
    test('name is telescope:events', () {
      expect(TelescopeEventsCommand().name, equals('telescope:events'));
    });

    test('boot is CommandBoot.connected', () {
      expect(TelescopeEventsCommand().boot, equals(CommandBoot.connected));
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
  });
}
