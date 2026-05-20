import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/records/query_record.dart';

void main() {
  group('QueryRecord', () {
    final fixedTime = DateTime.utc(2026, 5, 19, 3, 0, 0);

    test('constructor sets every field including default connection', () {
      final record = QueryRecord(
        sql: 'SELECT * FROM users WHERE id = ?',
        bindings: const <Object?>[42],
        timeMs: 12,
        time: fixedTime,
      );

      expect(record.sql, equals('SELECT * FROM users WHERE id = ?'));
      expect(record.bindings, equals(<Object?>[42]));
      expect(record.timeMs, equals(12));
      expect(record.time, equals(fixedTime));
      expect(record.connectionName, equals('default'));
    });

    test('connectionName override accepted', () {
      final record = QueryRecord(
        sql: 'SELECT 1',
        bindings: const <Object?>[],
        timeMs: 1,
        time: fixedTime,
        connectionName: 'reporting',
      );

      expect(record.connectionName, equals('reporting'));
    });

    test('toJson returns the canonical wire shape', () {
      final record = QueryRecord(
        sql: 'INSERT INTO users (name) VALUES (?)',
        bindings: const <Object?>['Alice'],
        timeMs: 8,
        time: fixedTime,
      );

      expect(record.toJson(), <String, dynamic>{
        'sql': 'INSERT INTO users (name) VALUES (?)',
        'bindings': <Object?>['Alice'],
        'timeMs': 8,
        'connectionName': 'default',
        'time': '2026-05-19T03:00:00.000Z',
      });
    });

    test('JSON round-trip survives jsonEncode/jsonDecode', () {
      final record = QueryRecord(
        sql: 'UPDATE users SET name = ? WHERE id = ?',
        bindings: const <Object?>['Bob', 99],
        timeMs: 15,
        time: fixedTime,
        connectionName: 'primary',
      );

      final encoded = jsonEncode(record.toJson());
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['sql'], equals(record.sql));
      expect(decoded['bindings'], equals(<dynamic>['Bob', 99]));
      expect(decoded['timeMs'], equals(15));
      expect(decoded['connectionName'], equals('primary'));
      expect(decoded['time'], equals('2026-05-19T03:00:00.000Z'));
    });

    test('two records with same fields are not identical (default identity eq)',
        () {
      final a = QueryRecord(
        sql: 'SELECT 1',
        bindings: const <Object?>[],
        timeMs: 1,
        time: fixedTime,
      );
      final b = QueryRecord(
        sql: 'SELECT 1',
        bindings: const <Object?>[],
        timeMs: 1,
        time: fixedTime,
      );

      expect(identical(a, b), isFalse);
    });
  });
}
