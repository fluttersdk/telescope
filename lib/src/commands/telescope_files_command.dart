import 'package:fluttersdk_artisan/artisan.dart';

/// `artisan telescope:files` ; list the running app's timeline files, or print
/// the lines of one.
///
/// Reads through `ext.telescope.files` and `ext.telescope.file`, so a name is
/// only ever one the app's file sink listed; the command touches no path. The
/// offset to continue from is printed at `-v`, after the lines.
class TelescopeFilesCommand extends ArtisanCommand {
  @override
  String get name => 'telescope:files';

  @override
  String get description =>
      'List the timeline files of the running app, or print the lines of one.';

  @override
  CommandBoot get boot => CommandBoot.connected;

  @override
  String get signature => 'telescope:files '
      '{--name= : Print the lines of this file (as listed) instead of the list.} '
      '{--offset=0 : Byte offset to start reading from; 0 or a previous next.}';

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final name = ctx.input.option('name');
    return name == null ? _list(ctx) : _print(ctx, name.toString());
  }

  Future<int> _list(ArtisanContext ctx) async {
    final response = await ctx.callExtension<Map<String, dynamic>>(
      'ext.telescope.files',
    );
    if (_failed(ctx, response)) return 1;

    final files = (response['files'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    if (files.isEmpty) {
      ctx.output.warning('No timeline files.');
      return 0;
    }
    for (final f in files) {
      ctx.output.writeln('${f['name']} ${f['bytes']}');
    }
    return 0;
  }

  Future<int> _print(ArtisanContext ctx, String name) async {
    final params = <String, dynamic>{'name': name};
    final offset = ctx.input.option('offset');
    if (offset != null) params['offset'] = offset.toString();

    final response = await ctx.callExtension<Map<String, dynamic>>(
      'ext.telescope.file',
      params,
    );
    if (_failed(ctx, response)) return 1;

    for (final line in (response['lines'] as List<dynamic>? ?? <dynamic>[])) {
      ctx.output.writeln(line.toString());
    }
    ctx.output.comment('next offset: ${response['next']}');
    return 0;
  }

  /// Prints the extension's fixed `error` message, which is all a refusal
  /// carries, and reports whether there was one.
  bool _failed(ArtisanContext ctx, Map<String, dynamic> response) {
    final error = response['error'];
    if (error == null) return false;

    ctx.output.error(error.toString());
    return true;
  }
}
