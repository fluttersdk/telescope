import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/records/magic_cache_record.dart';

void main() {
  group('MagicCacheRecord', () {
    final time = DateTime(2026, 5, 19, 12, 0, 0);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    test('constructor sets all required fields', () {
      final record = MagicCacheRecord(
        operation: 'hit',
        key: 'monitors.team-1',
        time: time,
      );

      expect(record.operation, equals('hit'));
      expect(record.key, equals('monitors.team-1'));
      expect(record.time, equals(time));
      expect(record.ttl, isNull);
    });

    test('constructor sets optional ttl when provided', () {
      final record = MagicCacheRecord(
        operation: 'put',
        key: 'monitors.team-1',
        time: time,
        ttl: const Duration(minutes: 5),
      );

      expect(record.ttl, equals(const Duration(minutes: 5)));
    });

    test('operation field accepts all cache operation values', () {
      for (final op in ['put', 'get', 'forget', 'hit', 'miss']) {
        final record = MagicCacheRecord(
          operation: op,
          key: 'some.key',
          time: time,
        );
        expect(record.operation, equals(op));
      }
    });

    // -------------------------------------------------------------------------
    // toJson
    // -------------------------------------------------------------------------

    test('toJson returns expected map without optional fields', () {
      final record = MagicCacheRecord(
        operation: 'miss',
        key: 'monitors.team-1',
        time: time,
      );

      expect(
        record.toJson(),
        equals({
          'operation': 'miss',
          'key': 'monitors.team-1',
          'time': time.toIso8601String(),
        }),
      );
    });

    test('toJson includes ttlMs when ttl is set', () {
      final record = MagicCacheRecord(
        operation: 'put',
        key: 'monitors.team-1',
        time: time,
        ttl: const Duration(minutes: 5),
      );

      final json = record.toJson();

      expect(json['ttlMs'], equals(300000));
    });

    test('toJson omits ttlMs when ttl is null', () {
      final record = MagicCacheRecord(
        operation: 'hit',
        key: 'monitors.team-1',
        time: time,
      );

      expect(record.toJson().containsKey('ttlMs'), isFalse);
    });

    test('JSON round-trip survives jsonEncode and jsonDecode', () {
      final record = MagicCacheRecord(
        operation: 'put',
        key: 'monitors.team-1',
        time: time,
        ttl: const Duration(seconds: 30),
      );

      final decoded =
          jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>;

      expect(decoded['operation'], equals('put'));
      expect(decoded['key'], equals('monitors.team-1'));
      expect(decoded['time'], equals(time.toIso8601String()));
      expect(decoded['ttlMs'], equals(30000));
    });

    // -------------------------------------------------------------------------
    // Identity equality (matches existing records ; no Equatable)
    // -------------------------------------------------------------------------

    test('two records with same fields are not identical (default identity eq)',
        () {
      final a = MagicCacheRecord(
        operation: 'hit',
        key: 'monitors.team-1',
        time: time,
      );
      final b = MagicCacheRecord(
        operation: 'hit',
        key: 'monitors.team-1',
        time: time,
      );

      expect(identical(a, b), isFalse);
    });
  });
}
