import 'package:fluttersdk_artisan/artisan.dart';

/// `artisan telescope:caches` ; print recent Magic Cache operation records
/// from the running Flutter app (captured by MagicCacheWatcher subscribed
/// to CacheHit / CacheMiss / CachePut / CacheForget / CacheFlush events).
class TelescopeCachesCommand extends ArtisanCommand {
  @override
  String get name => 'telescope:caches';

  @override
  String get description =>
      'Print recent Magic Cache operation records (hit/miss/put/forget/flush) from the running app.';

  @override
  CommandBoot get boot => CommandBoot.connected;

  @override
  String get signature => 'telescope:caches '
      '{--limit=50 : Maximum number of records to print (newest first).}';

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final limit = int.tryParse(ctx.input.option('limit')?.toString() ?? '50');
    final response = await ctx.callExtension<Map<String, dynamic>>(
      'ext.telescope.caches',
      <String, dynamic>{if (limit != null) 'limit': limit.toString()},
    );
    final records = (response['caches'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    if (records.isEmpty) {
      ctx.output.warning('No cache records (register MagicCacheWatcher).');
      return 0;
    }
    for (final r in records) {
      final ttl = r['ttlMs'] != null ? ' ttl=${r['ttlMs']}ms' : '';
      ctx.output.writeln(
        '${r['time']} [${r['operation']}] ${r['key']}$ttl',
      );
    }
    return 0;
  }
}
