import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterTimeline;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/records/http_request_record.dart';
import 'package:fluttersdk_telescope/src/telescope_redaction.dart';

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
        atUs: 999,
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
          'atUs': 999,
          'redacted': false,
        }),
      );
    });

    test('redacted is true only on the copy a redactor produced', () {
      addTearDown(TelescopeRedaction.resetForTesting);
      final plain = HttpRequestRecord(
        url: 'https://api.uptizm.com/monitors',
        method: 'GET',
        statusCode: 200,
        durationMs: 1,
        isError: false,
        timestamp: timestamp,
      );
      TelescopeRedaction.redactor = (String s) => s;
      final masked = TelescopeRedaction.redactHttpRecord(plain)!;

      expect(plain.redacted, isFalse);
      expect(masked.redacted, isTrue);
      expect(masked.toJson()['redacted'], isTrue);
      // A copy carries a caller's new body, which no redactor saw.
      expect(masked.copyWith(requestBody: 'b').redacted, isFalse);
    });

    test('a caller cannot construct a record flagged redacted', () {
      expect(
        () => Function.apply(
          HttpRequestRecord.new,
          const <Object?>[],
          <Symbol, Object?>{
            #url: 'https://api.uptizm.com/monitors',
            #method: 'GET',
            #statusCode: 200,
            #durationMs: 1,
            #isError: false,
            #timestamp: timestamp,
            #redacted: true,
          },
        ),
        throwsNoSuchMethodError,
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
      expect(json.containsKey('requestId'), isFalse);
      expect(json.containsKey('startUs'), isFalse);
      expect(json.containsKey('endUs'), isFalse);
      expect(json.containsKey('interactionId'), isFalse);
      expect(json.containsKey('linkedBy'), isFalse);
    });

    // -------------------------------------------------------------------------
    // Clock, request pairing, interaction link
    // -------------------------------------------------------------------------

    test('requestId, startUs and endUs default to null', () {
      final record = HttpRequestRecord(
        url: 'https://api.uptizm.com/monitors',
        method: 'GET',
        statusCode: 200,
        durationMs: 123,
        isError: false,
        timestamp: timestamp,
      );

      expect(record.requestId, isNull);
      expect(record.startUs, isNull);
      expect(record.endUs, isNull);
    });

    test('requestId, startUs and endUs are set and serialized when provided',
        () {
      final record = HttpRequestRecord(
        url: 'https://api.uptizm.com/monitors',
        method: 'GET',
        statusCode: 200,
        durationMs: 123,
        isError: false,
        timestamp: timestamp,
        requestId: 'req-42',
        startUs: 10,
        endUs: 20,
      );

      expect(record.requestId, equals('req-42'));
      expect(record.startUs, equals(10));
      expect(record.endUs, equals(20));

      final json = record.toJson();
      expect(json['requestId'], equals('req-42'));
      expect(json['startUs'], equals(10));
      expect(json['endUs'], equals(20));
    });

    test('atUs defaults to FlutterTimeline.now captured at construction', () {
      final int before = FlutterTimeline.now;
      final record = HttpRequestRecord(
        url: 'https://api.uptizm.com/monitors',
        method: 'GET',
        statusCode: 200,
        durationMs: 123,
        isError: false,
        timestamp: timestamp,
      );
      final int after = FlutterTimeline.now;

      expect(record.atUs, inInclusiveRange(before, after));
    });

    test('atUs accepts an explicit override', () {
      final record = HttpRequestRecord(
        url: 'https://api.uptizm.com/monitors',
        method: 'GET',
        statusCode: 200,
        durationMs: 123,
        isError: false,
        timestamp: timestamp,
        atUs: 555,
      );

      expect(record.atUs, equals(555));
    });

    test('interactionId and linkedBy are set and serialized when provided', () {
      final record = HttpRequestRecord(
        url: 'https://api.uptizm.com/monitors',
        method: 'GET',
        statusCode: 200,
        durationMs: 123,
        isError: false,
        timestamp: timestamp,
        interactionId: 'tap-1',
        linkedBy: 'zone',
      );

      expect(record.interactionId, equals('tap-1'));
      expect(record.linkedBy, equals('zone'));

      final json = record.toJson();
      expect(json['interactionId'], equals('tap-1'));
      expect(json['linkedBy'], equals('zone'));
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

    // -------------------------------------------------------------------------
    // copyWith
    // -------------------------------------------------------------------------

    group('.copyWith()', () {
      test('replaces the headers and bodies and keeps every other field', () {
        final original = HttpRequestRecord(
          url: 'https://api.uptizm.com/login',
          method: 'POST',
          statusCode: 200,
          durationMs: 123,
          isError: true,
          timestamp: timestamp,
          requestHeaders: {'Authorization': 'Bearer abc'},
          requestBody: 'request',
          responseBody: 'response',
          attributedHeuristically: true,
          requestId: 'r1',
          startUs: 10,
          endUs: 20,
          atUs: 30,
          interactionId: 'i1',
          linkedBy: 'zone',
        );

        final copy = original.copyWith(
          requestHeaders: {'Authorization': '********'},
          requestBody: 'masked request',
          responseBody: 'masked response',
        );

        expect(
          copy.toJson(),
          equals(
            original.toJson()
              ..['requestHeaders'] = {'Authorization': '********'}
              ..['requestBody'] = 'masked request'
              ..['responseBody'] = 'masked response',
          ),
        );
      });

      test('keeps the current values when called with no arguments', () {
        final original = HttpRequestRecord(
          url: 'https://api.uptizm.com/login',
          method: 'POST',
          statusCode: 200,
          durationMs: 123,
          isError: false,
          timestamp: timestamp,
          requestHeaders: {'Accept': 'application/json'},
          requestBody: 'request',
          responseBody: 'response',
          atUs: 30,
        );

        expect(original.copyWith().toJson(), equals(original.toJson()));
      });
    });
  });
}
