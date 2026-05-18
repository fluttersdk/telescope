import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/records/http_request_record.dart';

void main() {
  group('HttpRequestRecord', () {
    final timestamp = DateTime(2026, 5, 19, 12, 0, 0);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    test('constructor sets all required fields', () {
      final record = HttpRequestRecord(
        url: 'https://api.uptizm.com/monitors',
        method: 'GET',
        statusCode: 200,
        durationMs: 123,
        isError: false,
        timestamp: timestamp,
      );

      expect(record.url, equals('https://api.uptizm.com/monitors'));
      expect(record.method, equals('GET'));
      expect(record.statusCode, equals(200));
      expect(record.durationMs, equals(123));
      expect(record.isError, isFalse);
      expect(record.timestamp, equals(timestamp));
      expect(record.requestHeaders, isNull);
      expect(record.requestBody, isNull);
      expect(record.responseBody, isNull);
      expect(record.attributedHeuristically, isFalse);
    });

    test('constructor sets optional fields when provided', () {
      final record = HttpRequestRecord(
        url: 'https://api.uptizm.com/monitors',
        method: 'POST',
        statusCode: 422,
        durationMs: 250,
        isError: true,
        timestamp: timestamp,
        requestHeaders: {'Authorization': 'Bearer token'},
        requestBody: '{"name":"web"}',
        responseBody: '{"errors":{}}',
        attributedHeuristically: true,
      );

      expect(record.requestHeaders, equals({'Authorization': 'Bearer token'}));
      expect(record.requestBody, equals('{"name":"web"}'));
      expect(record.responseBody, equals('{"errors":{}}'));
      expect(record.attributedHeuristically, isTrue);
    });

    // -------------------------------------------------------------------------
    // toJson
    // -------------------------------------------------------------------------

    test('toJson returns expected map without optional fields', () {
      final record = HttpRequestRecord(
        url: 'https://api.uptizm.com/monitors',
        method: 'GET',
        statusCode: 200,
        durationMs: 123,
        isError: false,
        timestamp: timestamp,
      );

      expect(
        record.toJson(),
        equals({
          'url': 'https://api.uptizm.com/monitors',
          'method': 'GET',
          'statusCode': 200,
          'durationMs': 123,
          'isError': false,
          'timestamp': timestamp.toIso8601String(),
        }),
      );
    });

    test('toJson includes optional fields when set', () {
      final record = HttpRequestRecord(
        url: 'https://api.uptizm.com/monitors',
        method: 'POST',
        statusCode: 201,
        durationMs: 80,
        isError: false,
        timestamp: timestamp,
        requestHeaders: {'Content-Type': 'application/json'},
        requestBody: '{"url":"https://example.com"}',
        responseBody: '{"data":{}}',
        attributedHeuristically: true,
      );

      final json = record.toJson();

      expect(
          json['requestHeaders'], equals({'Content-Type': 'application/json'}));
      expect(json['requestBody'], equals('{"url":"https://example.com"}'));
      expect(json['responseBody'], equals('{"data":{}}'));
      expect(json['attributedHeuristically'], isTrue);
    });

    test(
        'toJson omits optional fields when null and attributedHeuristically false',
        () {
      final record = HttpRequestRecord(
        url: 'https://api.uptizm.com/monitors',
        method: 'DELETE',
        statusCode: 204,
        durationMs: 45,
        isError: false,
        timestamp: timestamp,
      );

      final json = record.toJson();

      expect(json.containsKey('requestHeaders'), isFalse);
      expect(json.containsKey('requestBody'), isFalse);
      expect(json.containsKey('responseBody'), isFalse);
      expect(json.containsKey('attributedHeuristically'), isFalse);
    });

    test('JSON round-trip survives jsonEncode and jsonDecode', () {
      final record = HttpRequestRecord(
        url: 'https://api.uptizm.com/monitors',
        method: 'GET',
        statusCode: 200,
        durationMs: 99,
        isError: false,
        timestamp: timestamp,
        requestBody: 'body',
      );

      final decoded =
          jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>;

      expect(decoded['url'], equals('https://api.uptizm.com/monitors'));
      expect(decoded['method'], equals('GET'));
      expect(decoded['statusCode'], equals(200));
      expect(decoded['durationMs'], equals(99));
      expect(decoded['isError'], isFalse);
      expect(decoded['timestamp'], equals(timestamp.toIso8601String()));
      expect(decoded['requestBody'], equals('body'));
    });

    // -------------------------------------------------------------------------
    // Identity equality (matches existing records ; no Equatable)
    // -------------------------------------------------------------------------

    test('two records with same fields are not identical (default identity eq)',
        () {
      final a = HttpRequestRecord(
        url: 'https://api.uptizm.com/monitors',
        method: 'GET',
        statusCode: 200,
        durationMs: 123,
        isError: false,
        timestamp: timestamp,
      );
      final b = HttpRequestRecord(
        url: 'https://api.uptizm.com/monitors',
        method: 'GET',
        statusCode: 200,
        durationMs: 123,
        isError: false,
        timestamp: timestamp,
      );

      expect(identical(a, b), isFalse);
    });
  });
}
