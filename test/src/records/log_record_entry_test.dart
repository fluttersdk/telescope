import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterTimeline;
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import 'package:fluttersdk_telescope/src/records/log_record_entry.dart';
import 'package:fluttersdk_telescope/src/telescope_redaction.dart';

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
        atUs: 999,
      );

      expect(
        record.toJson(),
        equals({
          'level': 'INFO',
          'levelValue': 800,
          'message': 'Monitor checked successfully',
          'loggerName': 'telescope',
          'time': time.toIso8601String(),
          'atUs': 999,
          'redacted': false,
        }),
      );
    });

    test('atUs defaults to FlutterTimeline.now captured at construction', () {
      final int before = FlutterTimeline.now;
      final record = LogRecordEntry(
        level: 'INFO',
        levelValue: 800,
        message: 'm',
        loggerName: 'telescope',
        time: time,
      );
      final int after = FlutterTimeline.now;

      expect(record.atUs, inInclusiveRange(before, after));
    });

    test('atUs accepts an explicit override', () {
      final record = LogRecordEntry(
        level: 'INFO',
        levelValue: 800,
        message: 'm',
        loggerName: 'telescope',
        time: time,
        atUs: 555,
      );

      expect(record.atUs, equals(555));
    });

    test('fromLogRecord stamps atUs from the monotonic clock', () {
      final int before = FlutterTimeline.now;
      final record = LogRecordEntry.fromLogRecord(
        LogRecord(Level.INFO, 'm', 'telescope'),
      );
      final int after = FlutterTimeline.now;

      expect(record.atUs, inInclusiveRange(before, after));
    });

    test('redacted is true only on the copy a redactor produced', () {
      addTearDown(TelescopeRedaction.resetForTesting);
      final plain = LogRecordEntry(
        level: 'INFO',
        levelValue: 800,
        message: 'm',
        loggerName: 'telescope',
        time: time,
      );
      TelescopeRedaction.redactor = (String s) => s;
      final masked = TelescopeRedaction.redactLogRecord(plain)!;

      expect(plain.redacted, isFalse);
      expect(masked.redacted, isTrue);
      expect(masked.toJson()['redacted'], isTrue);
    });

    test('a caller cannot construct a record flagged redacted', () {
      expect(
        () => Function.apply(
          LogRecordEntry.new,
          const <Object?>[],
          <Symbol, Object?>{
            #level: 'INFO',
            #levelValue: 800,
            #message: 'm',
            #loggerName: 'telescope',
            #time: time,
            #redacted: true,
          },
        ),
        throwsNoSuchMethodError,
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
