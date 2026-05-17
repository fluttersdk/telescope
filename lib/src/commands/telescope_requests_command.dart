import 'package:fluttersdk_artisan/artisan.dart';

/// `artisan telescope:requests` — print recent HTTP request records.
class TelescopeRequestsCommand extends ArtisanCommand {
  @override
  String get name => 'telescope:requests';

  @override
  String get description =>
      'Print recent HTTP request records from the running app.';

  @override
  CommandBoot get boot => CommandBoot.connected;

  @override
  void configure(ArgParser parser) {
    parser.addOption('limit', defaultsTo: '50');
  }

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final params = <String, dynamic>{};
    final limit = ctx.input.option('limit');
    if (limit != null) params['limit'] = limit;
    final result = await ctx.callExtension<Map<String, dynamic>>(
      'ext.telescope.requests',
      params,
    );
    final records = (result['records'] as List?) ?? [];
    if (records.isEmpty) {
      ctx.output.warning('No HTTP records (register a TelescopeHttpAdapter).');
      return 0;
    }
    for (final m in records) {
      final r = m as Map<String, dynamic>;
      ctx.output.writeln(
        '${r['timestamp']} ${r['method']} ${r['url']} → ${r['statusCode']} (${r['durationMs']}ms)',
      );
    }
    return 0;
  }
}
