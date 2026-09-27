import 'package:fluttersdk_artisan/artisan.dart';

/// `artisan telescope:dumps` ; print recent `debugPrint` output from the
/// running Flutter app (captured by DumpWatcher's global `debugPrint`
/// override).
class TelescopeDumpsCommand extends ArtisanCommand {
  @override
  String get name => 'telescope:dumps';

  @override
  String get description =>
      'Print recent debugPrint dump records from the running app.';

  @override
  CommandBoot get boot => CommandBoot.connected;

  @override
  String get signature => 'telescope:dumps '
      '{--limit=50 : Maximum number of records to print.}';

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final limit = int.tryParse(ctx.input.option('limit')?.toString() ?? '50');
    final response = await ctx.callExtension<Map<String, dynamic>>(
      'ext.telescope.dumps',
      <String, dynamic>{if (limit != null) 'limit': limit.toString()},
    );
    final records = (response['dumps'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    if (records.isEmpty) {
      ctx.output
          .warning('No dump records (install DumpWatcher in debug mode).');
      return 0;
    }
    for (final r in records) {
      ctx.output.writeln('${r['time']} ${r['message']}');
    }
    return 0;
  }
}
