import 'package:fluttersdk_artisan/artisan.dart';

/// `artisan telescope:events` ; print recent in-app event records from the
/// running Flutter app (captured by MagicEventWatcher on `Event.dispatch()`).
class TelescopeEventsCommand extends ArtisanCommand {
  @override
  String get name => 'telescope:events';

  @override
  String get description =>
      'Print recent in-app event records (type + payload + listeners) from the running app.';

  @override
  CommandBoot get boot => CommandBoot.connected;

  @override
  String get signature => 'telescope:events '
      '{--limit=50 : Maximum number of records to print.}';

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final limit = int.tryParse(ctx.input.option('limit')?.toString() ?? '50');
    final response = await ctx.callExtension<Map<String, dynamic>>(
      'ext.telescope.events',
      <String, dynamic>{if (limit != null) 'limit': limit.toString()},
    );
    final records = (response['events'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    if (records.isEmpty) {
      ctx.output.warning('No event records (register MagicEventWatcher).');
      return 0;
    }
    for (final r in records) {
      final listeners =
          r['listenerCount'] == null ? '' : ' listeners=${r['listenerCount']}';
      ctx.output.writeln(
        '${r['time']} ${r['eventType']} ${r['payload']}$listeners',
      );
    }
    return 0;
  }
}
