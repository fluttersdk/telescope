import 'dart:convert';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/telescope_artisan_provider.dart';

void main() {
  group('TelescopeArtisanProvider.mcpTools()', () {
    late List<McpToolDescriptor> tools;

    setUp(() {
      tools = TelescopeArtisanProvider().mcpTools();
    });

    // -------------------------------------------------------------------------
    // Length
    // -------------------------------------------------------------------------

    test('returns exactly 7 descriptors', () {
      expect(tools, hasLength(7));
    });

    // -------------------------------------------------------------------------
    // Names
    // -------------------------------------------------------------------------

    test('contains all 7 expected tool names', () {
      final names = tools.map((t) => t.name).toList();
      expect(
        names,
        containsAll(<String>[
          'telescope_tail',
          'telescope_requests',
          'telescope_clear',
          'telescope_exceptions',
          'telescope_events',
          'telescope_gates',
          'telescope_dumps',
        ]),
      );
    });

    // -------------------------------------------------------------------------
    // Extension methods
    // -------------------------------------------------------------------------

    test('each descriptor maps to the correct ext.telescope.* extension method',
        () {
      final byName = {for (final t in tools) t.name: t.extensionMethod};

      expect(byName['telescope_tail'], equals('ext.telescope.console'));
      expect(byName['telescope_requests'], equals('ext.telescope.requests'));
      expect(byName['telescope_clear'], equals('ext.telescope.clear'));
      expect(
          byName['telescope_exceptions'], equals('ext.telescope.exceptions'));
      expect(byName['telescope_events'], equals('ext.telescope.events'));
      expect(byName['telescope_gates'], equals('ext.telescope.gates'));
      expect(byName['telescope_dumps'], equals('ext.telescope.dumps'));
    });

    test('no two descriptors share an extensionMethod (no overlap, no gap)',
        () {
      final methods = tools.map((t) => t.extensionMethod).toList();
      expect(methods.toSet(), hasLength(tools.length));
    });

    // -------------------------------------------------------------------------
    // Input schemas — JSON round-trip
    // -------------------------------------------------------------------------

    test('every inputSchema survives a JSON encode/decode round-trip', () {
      for (final tool in tools) {
        expect(
          () => jsonDecode(jsonEncode(tool.inputSchema)),
          returnsNormally,
          reason: '${tool.name}.inputSchema failed JSON round-trip',
        );
      }
    });

    // -------------------------------------------------------------------------
    // telescope_exceptions — specific schema shape
    // -------------------------------------------------------------------------

    test('telescope_exceptions declares a limit integer property', () {
      final exceptions = tools.firstWhere(
        (t) => t.name == 'telescope_exceptions',
      );
      final properties =
          exceptions.inputSchema['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('limit'), isTrue);
      final limit = properties['limit'] as Map<String, dynamic>;
      expect(limit['type'], equals('integer'));
    });

    test('telescope_exceptions does not declare required params', () {
      final exceptions = tools.firstWhere(
        (t) => t.name == 'telescope_exceptions',
      );
      expect(exceptions.inputSchema.containsKey('required'), isFalse);
    });

    // -------------------------------------------------------------------------
    // telescope_clear — empty properties
    // -------------------------------------------------------------------------

    test('telescope_clear has an empty properties map', () {
      final clear = tools.firstWhere((t) => t.name == 'telescope_clear');
      final properties =
          clear.inputSchema['properties'] as Map<String, dynamic>;
      expect(properties, isEmpty);
    });

    // -------------------------------------------------------------------------
    // telescope_events — specific schema shape
    // -------------------------------------------------------------------------

    test('telescope_events declares a limit integer property', () {
      final events = tools.firstWhere((t) => t.name == 'telescope_events');
      final properties =
          events.inputSchema['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('limit'), isTrue);
      final limit = properties['limit'] as Map<String, dynamic>;
      expect(limit['type'], equals('integer'));
    });

    test('telescope_events does not declare required params', () {
      final events = tools.firstWhere((t) => t.name == 'telescope_events');
      expect(events.inputSchema.containsKey('required'), isFalse);
    });

    test('telescope_events description contains "Usage:"', () {
      final events = tools.firstWhere((t) => t.name == 'telescope_events');
      expect(events.description, contains('Usage:'));
    });

    // -------------------------------------------------------------------------
    // telescope_gates — specific schema shape
    // -------------------------------------------------------------------------

    test('telescope_gates declares a limit integer property', () {
      final gates = tools.firstWhere((t) => t.name == 'telescope_gates');
      final properties =
          gates.inputSchema['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('limit'), isTrue);
      final limit = properties['limit'] as Map<String, dynamic>;
      expect(limit['type'], equals('integer'));
    });

    test('telescope_gates does not declare required params', () {
      final gates = tools.firstWhere((t) => t.name == 'telescope_gates');
      expect(gates.inputSchema.containsKey('required'), isFalse);
    });

    test('telescope_gates description contains "Usage:"', () {
      final gates = tools.firstWhere((t) => t.name == 'telescope_gates');
      expect(gates.description, contains('Usage:'));
    });

    // -------------------------------------------------------------------------
    // telescope_dumps — specific schema shape
    // -------------------------------------------------------------------------

    test('telescope_dumps declares a limit integer property', () {
      final dumps = tools.firstWhere((t) => t.name == 'telescope_dumps');
      final properties =
          dumps.inputSchema['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('limit'), isTrue);
      final limit = properties['limit'] as Map<String, dynamic>;
      expect(limit['type'], equals('integer'));
    });

    test('telescope_dumps does not declare required params', () {
      final dumps = tools.firstWhere((t) => t.name == 'telescope_dumps');
      expect(dumps.inputSchema.containsKey('required'), isFalse);
    });

    test('telescope_dumps description contains "Usage:"', () {
      final dumps = tools.firstWhere((t) => t.name == 'telescope_dumps');
      expect(dumps.description, contains('Usage:'));
    });
  });
}
