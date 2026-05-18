import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/records/event_record.dart';

void main() {
  group('EventRecord', () {
    final time = DateTime(2026, 5, 19, 12, 0, 0);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    test('constructor sets all required fields', () {
      final record = EventRecord(
        eventType: 'UserLoggedIn',
        payload: {'userId': '42'},
        time: time,
      );

      expect(record.eventType, equals('UserLoggedIn'));
      expect(record.payload, equals({'userId': '42'}));
      expect(record.time, equals(time));
      expect(record.listenerCount, isNull);
    });

    test('constructor sets optional listenerCount when provided', () {
      final record = EventRecord(
        eventType: 'MonitorChecked',
        payload: {'monitorId': 'abc'},
        time: time,
        listenerCount: 3,
      );

      expect(record.listenerCount, equals(3));
    });

    // -------------------------------------------------------------------------
    // toJson
    // -------------------------------------------------------------------------

    test('toJson returns expected map without optional fields', () {
      final record = EventRecord(
        eventType: 'UserLoggedIn',
        payload: {'userId': '42'},
        time: time,
      );

      expect(
          record.toJson(),
          equals({
            'eventType': 'UserLoggedIn',
            'payload': {'userId': '42'},
            'time': time.toIso8601String(),
          }));
    });

    test('toJson includes listenerCount when set', () {
      final record = EventRecord(
        eventType: 'MonitorChecked',
        payload: {'monitorId': 'abc'},
        time: time,
        listenerCount: 5,
      );

      final json = record.toJson();

      expect(json['listenerCount'], equals(5));
    });

    test('toJson omits listenerCount when null', () {
      final record = EventRecord(
        eventType: 'UserLoggedIn',
        payload: {},
        time: time,
      );

      expect(record.toJson().containsKey('listenerCount'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Identity equality (matches existing records — no Equatable)
    // -------------------------------------------------------------------------

    test('two records with same fields are not identical (default identity eq)',
        () {
      final a = EventRecord(
        eventType: 'UserLoggedIn',
        payload: {'userId': '42'},
        time: time,
      );
      final b = EventRecord(
        eventType: 'UserLoggedIn',
        payload: {'userId': '42'},
        time: time,
      );

      expect(identical(a, b), isFalse);
    });
  });
}
