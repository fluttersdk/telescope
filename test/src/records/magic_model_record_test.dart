import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterTimeline;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/records/magic_model_record.dart';

void main() {
  group('MagicModelRecord', () {
    final time = DateTime(2026, 5, 19, 12, 0, 0);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    test('constructor sets all required fields', () {
      final record = MagicModelRecord(
        modelClass: 'Monitor',
        event: 'created',
        modelKey: 'abc-123',
        time: time,
      );

      expect(record.modelClass, equals('Monitor'));
      expect(record.event, equals('created'));
      expect(record.modelKey, equals('abc-123'));
      expect(record.time, equals(time));
      expect(record.attributes, isNull);
    });

    test('constructor sets optional attributes when provided', () {
      final record = MagicModelRecord(
        modelClass: 'Monitor',
        event: 'saved',
        modelKey: 'abc-123',
        time: time,
        attributes: {'url': 'https://example.com', 'interval': 60},
      );

      expect(
        record.attributes,
        equals({'url': 'https://example.com', 'interval': 60}),
      );
    });

    test('event field accepts saved and deleted values', () {
      final saved = MagicModelRecord(
        modelClass: 'Monitor',
        event: 'saved',
        modelKey: 'abc-123',
        time: time,
      );
      final deleted = MagicModelRecord(
        modelClass: 'Monitor',
        event: 'deleted',
        modelKey: 'abc-123',
        time: time,
      );

      expect(saved.event, equals('saved'));
      expect(deleted.event, equals('deleted'));
    });

    // -------------------------------------------------------------------------
    // toJson
    // -------------------------------------------------------------------------

    test('toJson returns expected map without optional fields', () {
      final record = MagicModelRecord(
        modelClass: 'Monitor',
        event: 'created',
        modelKey: 'abc-123',
        time: time,
        atUs: 999,
      );

      expect(
        record.toJson(),
        equals({
          'modelClass': 'Monitor',
          'event': 'created',
          'modelKey': 'abc-123',
          'time': time.toIso8601String(),
          'atUs': 999,
        }),
      );
    });

    test('toJson includes attributes when set', () {
      final record = MagicModelRecord(
        modelClass: 'Monitor',
        event: 'saved',
        modelKey: 'abc-123',
        time: time,
        attributes: {'url': 'https://example.com'},
      );

      final json = record.toJson();

      expect(json['attributes'], equals({'url': 'https://example.com'}));
    });

    test('toJson omits attributes when null', () {
      final record = MagicModelRecord(
        modelClass: 'Monitor',
        event: 'deleted',
        modelKey: 'abc-123',
        time: time,
      );

      expect(record.toJson().containsKey('attributes'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Clock, interaction link (shared shape across every telescope record)
    // -------------------------------------------------------------------------

    test('atUs defaults to FlutterTimeline.now captured at construction', () {
      final int before = FlutterTimeline.now;
      final record = MagicModelRecord(
        modelClass: 'Monitor',
        event: 'created',
        modelKey: 'abc-123',
        time: time,
      );
      final int after = FlutterTimeline.now;

      expect(record.atUs, inInclusiveRange(before, after));
    });

    test('atUs accepts an explicit override', () {
      final record = MagicModelRecord(
        modelClass: 'Monitor',
        event: 'created',
        modelKey: 'abc-123',
        time: time,
        atUs: 555,
      );

      expect(record.atUs, equals(555));
    });

    test('interactionId and linkedBy default to null and toJson omits them',
        () {
      final record = MagicModelRecord(
        modelClass: 'Monitor',
        event: 'created',
        modelKey: 'abc-123',
        time: time,
      );

      expect(record.interactionId, isNull);
      expect(record.linkedBy, isNull);

      final json = record.toJson();
      expect(json.containsKey('interactionId'), isFalse);
      expect(json.containsKey('linkedBy'), isFalse);
    });

    test('interactionId and linkedBy are set and serialized when provided', () {
      final record = MagicModelRecord(
        modelClass: 'Monitor',
        event: 'created',
        modelKey: 'abc-123',
        time: time,
        interactionId: 'tap-1',
        linkedBy: 'window',
      );

      final json = record.toJson();
      expect(json['interactionId'], equals('tap-1'));
      expect(json['linkedBy'], equals('window'));
    });

    test('JSON round-trip survives jsonEncode and jsonDecode', () {
      final record = MagicModelRecord(
        modelClass: 'Monitor',
        event: 'created',
        modelKey: 'abc-123',
        time: time,
        attributes: {'url': 'https://example.com'},
      );

      final decoded =
          jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>;

      expect(decoded['modelClass'], equals('Monitor'));
      expect(decoded['event'], equals('created'));
      expect(decoded['modelKey'], equals('abc-123'));
      expect(decoded['time'], equals(time.toIso8601String()));
      expect(decoded['attributes'], equals({'url': 'https://example.com'}));
    });

    // -------------------------------------------------------------------------
    // Identity equality (matches existing records ; no Equatable)
    // -------------------------------------------------------------------------

    test('two records with same fields are not identical (default identity eq)',
        () {
      final a = MagicModelRecord(
        modelClass: 'Monitor',
        event: 'created',
        modelKey: 'abc-123',
        time: time,
      );
      final b = MagicModelRecord(
        modelClass: 'Monitor',
        event: 'created',
        modelKey: 'abc-123',
        time: time,
      );

      expect(identical(a, b), isFalse);
    });
  });
}
