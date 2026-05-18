import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/records/gate_record.dart';

void main() {
  group('GateRecord', () {
    final time = DateTime(2026, 5, 19, 12, 0, 0);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    test('constructor sets all required fields', () {
      final record = GateRecord(
        ability: 'monitors.destroy',
        result: true,
        arguments: ['monitor-id-1'],
        time: time,
      );

      expect(record.ability, equals('monitors.destroy'));
      expect(record.result, isTrue);
      expect(record.arguments, equals(['monitor-id-1']));
      expect(record.time, equals(time));
      expect(record.userId, isNull);
    });

    test('constructor sets optional userId when provided', () {
      final record = GateRecord(
        ability: 'monitors.update',
        result: false,
        arguments: [],
        time: time,
        userId: 'user-42',
      );

      expect(record.userId, equals('user-42'));
    });

    test('result false means denied', () {
      final record = GateRecord(
        ability: 'monitors.destroy',
        result: false,
        arguments: [],
        time: time,
      );

      expect(record.result, isFalse);
    });

    // -------------------------------------------------------------------------
    // toJson
    // -------------------------------------------------------------------------

    test('toJson returns expected map without optional fields', () {
      final record = GateRecord(
        ability: 'monitors.destroy',
        result: true,
        arguments: ['monitor-id-1'],
        time: time,
      );

      expect(
          record.toJson(),
          equals({
            'ability': 'monitors.destroy',
            'result': true,
            'arguments': ['monitor-id-1'],
            'time': time.toIso8601String(),
          }));
    });

    test('toJson includes userId when set', () {
      final record = GateRecord(
        ability: 'monitors.destroy',
        result: true,
        arguments: [],
        time: time,
        userId: 'user-42',
      );

      final json = record.toJson();

      expect(json['userId'], equals('user-42'));
    });

    test('toJson omits userId when null', () {
      final record = GateRecord(
        ability: 'monitors.destroy',
        result: true,
        arguments: [],
        time: time,
      );

      expect(record.toJson().containsKey('userId'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Identity equality (matches existing records — no Equatable)
    // -------------------------------------------------------------------------

    test('two records with same fields are not identical (default identity eq)',
        () {
      final a = GateRecord(
        ability: 'monitors.destroy',
        result: true,
        arguments: [],
        time: time,
      );
      final b = GateRecord(
        ability: 'monitors.destroy',
        result: true,
        arguments: [],
        time: time,
      );

      expect(identical(a, b), isFalse);
    });
  });
}
