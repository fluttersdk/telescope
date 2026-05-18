import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/records/log_record_entry.dart';

void main() {
  group('LogRecordEntry', () {
    final time = DateTime(2026, 5, 19, 12, 0, 0);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    test('constructor sets all required fields', () {
      final record = LogRecordEntry(
        level: 'INFO',
        levelValue: 800,
        message: 'Monitor checked successfully',
        loggerName: 'telescope',
        time: time,
      );

      expect(record.level, equals('INFO'));
      expect(record.levelValue, equals(800));
      expect(record.message, equals('Monitor checked successfully'));
      expect(record.loggerName, equals('telescope'));
      expect(record.time, equals(time));
      expect(record.error, isNull);
      expect(record.stackTrace, isNull);
    });

    test('constructor sets optional error and stackTrace when provided', () {
      final record = LogRecordEntry(
        level: 'SEVERE',
        levelValue: 1000,
        message: 'Unexpected failure',
        loggerName: 'telescope',
        time: time,
        error: 'StateError: Bad state',
        stackTrace: '#0 main (main.dart:1)',
      );

      expect(record.error, equals('StateError: Bad state'));
      expect(record.stackTrace, equals('#0 main (main.dart:1)'));
    });

    // -------------------------------------------------------------------------
    // toJson
    // -------------------------------------------------------------------------

    test('toJson returns expected map without optional fields', () {
      final record = LogRecordEntry(
        level: 'INFO',
        levelValue: 800,
        message: 'Monitor checked successfully',
        loggerName: 'telescope',
        time: time,
      );

      expect(
        record.toJson(),
        equals({
          'level': 'INFO',
          'levelValue': 800,
          'message': 'Monitor checked successfully',
          'loggerName': 'telescope',
          'time': time.toIso8601String(),
        }),
      );
    });

    test('toJson includes error and stackTrace when set', () {
      final record = LogRecordEntry(
        level: 'SEVERE',
        levelValue: 1000,
        message: 'Unexpected failure',
        loggerName: 'telescope',
        time: time,
        error: 'StateError: Bad state',
        stackTrace: '#0 main (main.dart:1)',
      );

      final json = record.toJson();

      expect(json['error'], equals('StateError: Bad state'));
      expect(json['stackTrace'], equals('#0 main (main.dart:1)'));
    });

    test('toJson omits error and stackTrace when null', () {
      final record = LogRecordEntry(
        level: 'WARNING',
        levelValue: 900,
        message: 'Slow response detected',
        loggerName: 'telescope',
        time: time,
      );

      final json = record.toJson();

      expect(json.containsKey('error'), isFalse);
      expect(json.containsKey('stackTrace'), isFalse);
    });

    test('JSON round-trip survives jsonEncode and jsonDecode', () {
      final record = LogRecordEntry(
        level: 'INFO',
        levelValue: 800,
        message: 'Monitor checked successfully',
        loggerName: 'telescope',
        time: time,
        error: 'some error',
      );

      final decoded =
          jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>;

      expect(decoded['level'], equals('INFO'));
      expect(decoded['levelValue'], equals(800));
      expect(decoded['message'], equals('Monitor checked successfully'));
      expect(decoded['loggerName'], equals('telescope'));
      expect(decoded['time'], equals(time.toIso8601String()));
      expect(decoded['error'], equals('some error'));
    });

    // -------------------------------------------------------------------------
    // Identity equality (matches existing records ; no Equatable)
    // -------------------------------------------------------------------------

    test('two records with same fields are not identical (default identity eq)',
        () {
      final a = LogRecordEntry(
        level: 'INFO',
        levelValue: 800,
        message: 'Monitor checked successfully',
        loggerName: 'telescope',
        time: time,
      );
      final b = LogRecordEntry(
        level: 'INFO',
        levelValue: 800,
        message: 'Monitor checked successfully',
        loggerName: 'telescope',
        time: time,
      );

      expect(identical(a, b), isFalse);
    });
  });
}
