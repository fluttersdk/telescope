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

    test('returns exactly 4 descriptors', () {
      expect(tools, hasLength(4));
    });

    // -------------------------------------------------------------------------
    // Names
    // -------------------------------------------------------------------------

    test('contains all 4 expected tool names', () {
      final names = tools.map((t) => t.name).toList();
      expect(
        names,
        containsAll(<String>[
          'telescope_tail',
          'telescope_requests',
          'telescope_clear',
          'telescope_exceptions',
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
  });
}
