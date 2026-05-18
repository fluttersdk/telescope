import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/commands/telescope_clear_command.dart';

/// Stubs [ArtisanContext.callExtension] so tests never hit a real VM Service.
class _StubContext extends ArtisanContext {
  _StubContext({
    required ArtisanInput input,
    required ArtisanOutput output,
  })  : _response = const {},
        super.bare(input, output);

  final Map<String, dynamic> _response;

  String? lastMethod;
  Map<String, dynamic>? lastParams;

  @override
  Future<T> callExtension<T>(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    lastMethod = method;
    lastParams = params;
    return _response as T;
  }
}

void main() {
  group('TelescopeClearCommand', () {
    // -------------------------------------------------------------------------
    // Metadata
    // -------------------------------------------------------------------------

    test('name is telescope:clear', () {
      expect(TelescopeClearCommand().name, equals('telescope:clear'));
    });

    test('boot is CommandBoot.connected', () {
      expect(TelescopeClearCommand().boot, equals(CommandBoot.connected));
    });

    test('description is non-empty', () {
      expect(TelescopeClearCommand().description, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // ArgParser flags (none expected)
    // -------------------------------------------------------------------------

    test('configure registers no options', () {
      final parser = ArgParser();

      // TelescopeClearCommand does not override configure(); invoking it is a
      // no-op but must not throw.
      TelescopeClearCommand().configure(parser);

      expect(parser.options, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Extension method forwarding
    // -------------------------------------------------------------------------

    test('handle calls ext.telescope.clear', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
      );

      await TelescopeClearCommand().handle(ctx);

      expect(ctx.lastMethod, equals('ext.telescope.clear'));
    });

    test('handle passes no params to callExtension', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
      );

      await TelescopeClearCommand().handle(ctx);

      expect(ctx.lastParams, isNull);
    });

    // -------------------------------------------------------------------------
    // Output formatting
    // -------------------------------------------------------------------------

    test('handle writes a "cleared" confirmation line', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
      );

      final code = await TelescopeClearCommand().handle(ctx);

      expect(code, equals(0));
      expect(output.content.toLowerCase(), contains('cleared'));
    });

    test('handle returns 0', () async {
      final output = BufferedOutput();
      final ctx = _StubContext(
        input: MapInput(const {}),
        output: output,
      );

      final code = await TelescopeClearCommand().handle(ctx);

      expect(code, equals(0));
    });
  });
}
