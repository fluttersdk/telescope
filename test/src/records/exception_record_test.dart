import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/records/exception_record.dart';

void main() {
  group('ExceptionRecord', () {
    final time = DateTime(2026, 5, 19, 12, 0, 0);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    test('constructor sets all required fields', () {
      final record = ExceptionRecord(
        exceptionType: 'StateError',
        message: 'Bad state: no element',
        time: time,
      );

      expect(record.exceptionType, equals('StateError'));
      expect(record.message, equals('Bad state: no element'));
      expect(record.time, equals(time));
      expect(record.stackTrace, isNull);
      expect(record.isolate, isNull);
    });

    test('constructor sets optional stackTrace and isolate when provided', () {
      final record = ExceptionRecord(
        exceptionType: 'FormatException',
        message: 'Invalid JSON',
        time: time,
        stackTrace: '#0 main (main.dart:1)',
        isolate: 'main',
      );

      expect(record.stackTrace, equals('#0 main (main.dart:1)'));
      expect(record.isolate, equals('main'));
    });

    // -------------------------------------------------------------------------
    // toJson
    // -------------------------------------------------------------------------

    test('toJson returns expected map without optional fields', () {
      final record = ExceptionRecord(
        exceptionType: 'StateError',
        message: 'Bad state: no element',
        time: time,
      );

      expect(
        record.toJson(),
        equals({
          'exceptionType': 'StateError',
          'message': 'Bad state: no element',
          'time': time.toIso8601String(),
        }),
      );
    });

    test('toJson includes stackTrace and isolate when set', () {
      final record = ExceptionRecord(
        exceptionType: 'FormatException',
        message: 'Invalid JSON',
        time: time,
        stackTrace: '#0 main (main.dart:1)',
        isolate: 'main',
      );

      final json = record.toJson();

      expect(json['stackTrace'], equals('#0 main (main.dart:1)'));
      expect(json['isolate'], equals('main'));
    });

    test('toJson omits stackTrace and isolate when null', () {
      final record = ExceptionRecord(
        exceptionType: 'StateError',
        message: 'Bad state: no element',
        time: time,
      );

      final json = record.toJson();

      expect(json.containsKey('stackTrace'), isFalse);
      expect(json.containsKey('isolate'), isFalse);
    });

    test('JSON round-trip survives jsonEncode and jsonDecode', () {
      final record = ExceptionRecord(
        exceptionType: 'StateError',
        message: 'Bad state: no element',
        time: time,
        stackTrace: '#0 main (main.dart:1)',
        isolate: 'main',
      );

      final decoded =
          jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>;

      expect(decoded['exceptionType'], equals('StateError'));
      expect(decoded['message'], equals('Bad state: no element'));
      expect(decoded['time'], equals(time.toIso8601String()));
      expect(decoded['stackTrace'], equals('#0 main (main.dart:1)'));
      expect(decoded['isolate'], equals('main'));
    });

    // -------------------------------------------------------------------------
    // Identity equality (matches existing records ; no Equatable)
    // -------------------------------------------------------------------------

    test('two records with same fields are not identical (default identity eq)',
        () {
      final a = ExceptionRecord(
        exceptionType: 'StateError',
        message: 'Bad state: no element',
        time: time,
      );
      final b = ExceptionRecord(
        exceptionType: 'StateError',
        message: 'Bad state: no element',
        time: time,
      );

      expect(identical(a, b), isFalse);
    });
  });
}
