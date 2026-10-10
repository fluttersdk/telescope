import 'package:flutter/foundation.dart' show FlutterTimeline;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/records/event_record.dart';
import 'package:fluttersdk_telescope/src/telescope_redaction.dart';

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
        atUs: 999,
      );

      expect(
          record.toJson(),
          equals({
            'eventType': 'UserLoggedIn',
            'payload': {'userId': '42'},
            'time': time.toIso8601String(),
            'atUs': 999,
            'redacted': false,
          }));
    });

    test('redacted is true only on the copy a redactor produced', () {
      addTearDown(TelescopeRedaction.resetForTesting);
      final plain = EventRecord(
        eventType: 'UserLoggedIn',
        payload: <String, dynamic>{},
        time: time,
      );
      TelescopeRedaction.redactor = (String s) => s;
      final masked = TelescopeRedaction.redactEventRecord(plain)!;

      expect(plain.redacted, isFalse);
      expect(masked.redacted, isTrue);
      expect(masked.toJson()['redacted'], isTrue);
    });

    test('a caller cannot construct a record flagged redacted', () {
      expect(
        () => Function.apply(
          EventRecord.new,
          const <Object?>[],
          <Symbol, Object?>{
            #eventType: 'UserLoggedIn',
            #payload: <String, dynamic>{},
            #time: time,
            #redacted: true,
          },
        ),
        throwsNoSuchMethodError,
      );
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
    // Clock, interaction link (shared shape across every telescope record)
    // -------------------------------------------------------------------------

    test('atUs defaults to FlutterTimeline.now captured at construction', () {
      final int before = FlutterTimeline.now;
      final record = EventRecord(
        eventType: 'UserLoggedIn',
        payload: {'userId': '42'},
        time: time,
      );
      final int after = FlutterTimeline.now;

      expect(record.atUs, inInclusiveRange(before, after));
    });

    test('atUs accepts an explicit override', () {
      final record = EventRecord(
        eventType: 'UserLoggedIn',
        payload: {'userId': '42'},
        time: time,
        atUs: 555,
      );

      expect(record.atUs, equals(555));
    });

    test('interactionId and linkedBy default to null and toJson omits them',
        () {
      final record = EventRecord(
        eventType: 'UserLoggedIn',
        payload: {'userId': '42'},
        time: time,
      );

      expect(record.interactionId, isNull);
      expect(record.linkedBy, isNull);

      final json = record.toJson();
      expect(json.containsKey('interactionId'), isFalse);
      expect(json.containsKey('linkedBy'), isFalse);
    });

    test('interactionId and linkedBy are set and serialized when provided', () {
      final record = EventRecord(
        eventType: 'UserLoggedIn',
        payload: {'userId': '42'},
        time: time,
        interactionId: 'tap-1',
        linkedBy: 'frame',
      );

      final json = record.toJson();
      expect(json['interactionId'], equals('tap-1'));
      expect(json['linkedBy'], equals('frame'));
    });

    // -------------------------------------------------------------------------
    // Identity equality (matches existing records ; no Equatable)
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
