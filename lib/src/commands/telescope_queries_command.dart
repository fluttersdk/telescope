import 'package:fluttersdk_artisan/artisan.dart';

/// `artisan telescope:queries` ; print recent DB query records from the
/// running Flutter app (captured by MagicQueryWatcher subscribed to magic's
/// `QueryExecuted` event).
class TelescopeQueriesCommand extends ArtisanCommand {
  @override
  String get name => 'telescope:queries';

  @override
  String get description =>
      'Print recent DB query records (sql + bindings + timeMs) from the running app.';

  @override
  CommandBoot get boot => CommandBoot.connected;

  @override
  String get signature => 'telescope:queries '
      '{--limit=50 : Maximum number of records to print (newest first).}';

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final limit = int.tryParse(ctx.input.option('limit')?.toString() ?? '50');
    final response = await ctx.callExtension<Map<String, dynamic>>(
      'ext.telescope.queries',
      <String, dynamic>{if (limit != null) 'limit': limit.toString()},
    );
    final records = (response['queries'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    if (records.isEmpty) {
      ctx.output.warning('No DB query records (register MagicQueryWatcher).');
      return 0;
    }
    for (final r in records) {
      ctx.output.writeln(
        '${r['time']} [${r['connectionName']}] '
        '${r['sql']} bindings=${r['bindings']} (${r['timeMs']}ms)',
      );
    }
    return 0;
  }
}
