import 'package:fluttersdk_artisan/artisan.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluttersdk_telescope/src/commands/telescope_files_command.dart';

/// Stubs [ArtisanContext.callExtension] so tests never hit a real VM Service.
class _StubContext extends ArtisanContext {
  _StubContext({
    required ArtisanInput input,
    required ArtisanOutput output,
    required Map<String, dynamic> response,
  })  : _response = response,
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
  group('TelescopeFilesCommand', () {
    test('name is telescope:files', () {
      expect(TelescopeFilesCommand().name, equals('telescope:files'));
    });

    test('boot is CommandBoot.connected', () {
      expect(TelescopeFilesCommand().boot, equals(CommandBoot.connected));
    });

    test('description is non-empty', () {
      expect(TelescopeFilesCommand().description, isNotEmpty);
    });

    test('signature declares --name and --offset', () {
      final signature = TelescopeFilesCommand().signature;

      expect(signature, contains('{--name='));
      expect(signature, contains('{--offset='));
    });

    group('without --name', () {
      test('lists the files from ext.telescope.files', () async {
        final output = BufferedOutput();
        final ctx = _StubContext(
          input: MapInput(const {}),
          output: output,
          response: const {
            'files': [
              {'name': 'timeline-20260101T000000Z-2.jsonl', 'bytes': 120},
              {'name': 'timeline-20260101T000000Z-1.jsonl', 'bytes': 4096},
            ],
          },
        );

        final code = await TelescopeFilesCommand().handle(ctx);

        expect(code, equals(0));
        expect(ctx.lastMethod, equals('ext.telescope.files'));
        expect(output.content, contains('timeline-20260101T000000Z-2.jsonl'));
        expect(output.content, contains('120'));
        expect(output.content, contains('timeline-20260101T000000Z-1.jsonl'));
        expect(output.content, contains('4096'));
      });

      test('warns when the sink holds no files', () async {
        final output = BufferedOutput();
        final ctx = _StubContext(
          input: MapInput(const {}),
          output: output,
          response: const {'files': <dynamic>[]},
        );

        final code = await TelescopeFilesCommand().handle(ctx);

        expect(code, equals(0));
        expect(output.content, contains('No timeline files'));
      });

      test('prints the error and fails when no sink runs', () async {
        final output = BufferedOutput();
        final ctx = _StubContext(
          input: MapInput(const {}),
          output: output,
          response: const {'error': 'No timeline file sink is running.'},
        );

        final code = await TelescopeFilesCommand().handle(ctx);

        expect(code, equals(1));
        expect(output.content, contains('No timeline file sink is running.'));
        expect(output.content, isNot(contains('Exception')));
        expect(output.content, isNot(contains('#0')));
      });
    });

    group('with --name', () {
      test('calls ext.telescope.file and prints the lines', () async {
        final output = BufferedOutput();
        final ctx = _StubContext(
          input: MapInput(const {
            'name': 'timeline-20260101T000000Z-1.jsonl',
            'offset': '12',
          }),
          output: output,
          response: const {
            'lines': ['{"kind":"event"}', '{"kind":"log"}'],
            'next': 40,
          },
        );

        final code = await TelescopeFilesCommand().handle(ctx);

        expect(code, equals(0));
        expect(ctx.lastMethod, equals('ext.telescope.file'));
        expect(
          ctx.lastParams,
          containsPair('name', 'timeline-20260101T000000Z-1.jsonl'),
        );
        expect(ctx.lastParams, containsPair('offset', '12'));
        expect(output.content, contains('{"kind":"event"}\n{"kind":"log"}\n'));
      });

      test('omits offset when not provided', () async {
        final ctx = _StubContext(
          input: MapInput(const {'name': 'timeline-20260101T000000Z-1.jsonl'}),
          output: BufferedOutput(),
          response: const {'lines': <dynamic>[], 'next': 0},
        );

        await TelescopeFilesCommand().handle(ctx);

        expect(ctx.lastParams, isNot(contains('offset')));
      });

      test('prints the refusal and fails for a name the sink rejects',
          () async {
        final output = BufferedOutput();
        final ctx = _StubContext(
          input: MapInput(const {'name': '../etc/passwd'}),
          output: output,
          response: const {'error': 'Unknown timeline file.'},
        );

        final code = await TelescopeFilesCommand().handle(ctx);

        expect(code, equals(1));
        expect(output.content, contains('Unknown timeline file.'));
      });
    });
  });
}
