import 'package:fluttersdk_artisan/artisan.dart';

/// `artisan telescope:gates` ; print recent Gate authorization checks from the
/// running Flutter app (captured by MagicGateWatcher on `Gate.allows` /
/// `Gate.denies`).
class TelescopeGatesCommand extends ArtisanCommand {
  @override
  String get name => 'telescope:gates';

  @override
  String get description =>
      'Print recent Gate checks (ability + allowed/denied + user) from the running app.';

  @override
  CommandBoot get boot => CommandBoot.connected;

  @override
  String get signature => 'telescope:gates '
      '{--limit=50 : Maximum number of records to print.}';

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final limit = int.tryParse(ctx.input.option('limit')?.toString() ?? '50');
    final response = await ctx.callExtension<Map<String, dynamic>>(
      'ext.telescope.gates',
      <String, dynamic>{if (limit != null) 'limit': limit.toString()},
    );
    final records = (response['gates'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    if (records.isEmpty) {
      ctx.output.warning('No gate records (register MagicGateWatcher).');
      return 0;
    }
    for (final r in records) {
      final verdict = r['result'] == true ? 'allowed' : 'denied';
      final user = r['userId'] == null ? '' : ' user=${r['userId']}';
      ctx.output.writeln(
        '${r['time']} ${r['ability']} $verdict$user arguments=${r['arguments']}',
      );
    }
    return 0;
  }
}
