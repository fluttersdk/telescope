import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/records/dump_record.dart';

void main() {
  group('DumpRecord', () {
    final time = DateTime(2026, 5, 19, 12, 0, 0);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    test('constructor sets all required fields', () {
      final record = DumpRecord(
        message: 'debug output here',
        time: time,
      );

      expect(record.message, equals('debug output here'));
      expect(record.time, equals(time));
      expect(record.wrapWidth, isNull);
    });

    test('constructor sets optional wrapWidth when provided', () {
      final record = DumpRecord(
        message: 'debug output here',
        time: time,
        wrapWidth: 80,
      );

      expect(record.wrapWidth, equals(80));
    });

    // -------------------------------------------------------------------------
    // toJson
    // -------------------------------------------------------------------------

    test('toJson returns expected map without optional fields', () {
      final record = DumpRecord(
        message: 'debug output here',
        time: time,
      );

      expect(
          record.toJson(),
          equals({
            'message': 'debug output here',
            'time': time.toIso8601String(),
          }));
    });

    test('toJson includes wrapWidth when set', () {
      final record = DumpRecord(
        message: 'debug output here',
        time: time,
        wrapWidth: 120,
      );

      final json = record.toJson();

      expect(json['wrapWidth'], equals(120));
    });

    test('toJson omits wrapWidth when null', () {
      final record = DumpRecord(
        message: 'debug output here',
        time: time,
      );

      expect(record.toJson().containsKey('wrapWidth'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Identity equality (matches existing records ; no Equatable)
    // -------------------------------------------------------------------------

    test('two records with same fields are not identical (default identity eq)',
        () {
      final a = DumpRecord(
        message: 'debug output here',
        time: time,
      );
      final b = DumpRecord(
        message: 'debug output here',
        time: time,
      );

      expect(identical(a, b), isFalse);
    });
  });
}
