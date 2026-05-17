import 'package:fluttersdk_artisan/artisan.dart';

/// `artisan telescope:clear` — clear all telescope buffers.
class TelescopeClearCommand extends ArtisanCommand {
  @override
  String get name => 'telescope:clear';

  @override
  String get description =>
      'Clear all telescope ring buffers (http, logs, exceptions).';

  @override
  CommandBoot get boot => CommandBoot.connected;

  @override
  Future<int> handle(ArtisanContext ctx) async {
    await ctx.callExtension<Map<String, dynamic>>('ext.telescope.clear');
    ctx.output.success('Cleared telescope buffers.');
    return 0;
  }
}
