import 'package:fluttersdk_artisan/artisan.dart';

/// `artisan telescope:tail` — print recent log records from the running app.
class TelescopeTailCommand extends ArtisanCommand {
  @override
  String get name => 'telescope:tail';

  @override
  String get description => 'Print recent log records from the running app.';

  @override
  CommandBoot get boot => CommandBoot.connected;

  @override
  void configure(ArgParser parser) {
    parser
      ..addOption('level', help: 'Minimum level (info/warning/severe).')
      ..addOption('limit', defaultsTo: '50');
  }

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final params = <String, dynamic>{};
    final level = ctx.input.option('level');
    if (level != null) params['level'] = level;
    final limit = ctx.input.option('limit');
    if (limit != null) params['limit'] = limit;
    final result = await ctx.callExtension<Map<String, dynamic>>(
      'ext.telescope.console',
      params,
    );
    final messages = (result['messages'] as List?) ?? [];
    if (messages.isEmpty) {
      ctx.output.warning('No log records.');
      return 0;
    }
    for (final m in messages) {
      final r = m as Map<String, dynamic>;
      ctx.output.writeln(
        '${r['time']} [${r['level']}] ${r['loggerName']}: ${r['message']}',
      );
    }
    return 0;
  }
}
