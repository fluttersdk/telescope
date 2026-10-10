import 'dart:convert';

import 'package:fluttersdk_artisan/artisan.dart';

/// `artisan telescope:events` ; print recent in-app event records from the
/// running Flutter app (captured by MagicEventWatcher on `Event.dispatch()`).
///
/// `--since` and `--type` filter on the app side, `--json` prints one JSON
/// object per line, and `--follow` re-reads every second from the cursor the
/// previous read returned until the process is interrupted.
class TelescopeEventsCommand extends ArtisanCommand {
  /// [delay] waits between two `--follow` polls and [shouldStop] ends the loop
  /// once it returns true for the number of polls made so far; both exist so
  /// a test can run the loop without a clock or a Ctrl-C.
  TelescopeEventsCommand({
    Future<void> Function(Duration) delay = _wait,
    bool Function(int polls) shouldStop = _never,
  })  : _delay = delay,
        _shouldStop = shouldStop;

  static const Duration _pollInterval = Duration(seconds: 1);

  final Future<void> Function(Duration) _delay;
  final bool Function(int polls) _shouldStop;

  @override
  String get name => 'telescope:events';

  @override
  String get description =>
      'Print recent in-app event records (type + payload + listeners) from the running app.';

  @override
  CommandBoot get boot => CommandBoot.connected;

  @override
  String get signature => 'telescope:events '
      '{--limit=50 : Maximum number of records to print.} '
      '{--since= : Only records after this atUs (microseconds).} '
      '{--type= : Only event types starting with this prefix.} '
      '{--json : Print one JSON object per line.} '
      '{--follow : Keep polling from the last cursor until interrupted.}';

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final json = ctx.input.option('json') as bool? ?? false;
    final follow = ctx.input.option('follow') as bool? ?? false;
    final params = <String, dynamic>{};
    final limit = int.tryParse(ctx.input.option('limit')?.toString() ?? '50');
    if (limit != null) params['limit'] = limit.toString();
    final since = ctx.input.option('since');
    if (since != null) params['since'] = since.toString();
    final type = ctx.input.option('type');
    if (type != null) params['type'] = type.toString();

    for (var polls = 1;; polls++) {
      final response = await ctx.callExtension<Map<String, dynamic>>(
        'ext.telescope.events',
        params,
      );
      final records = (response['events'] as List<dynamic>? ?? <dynamic>[])
          .cast<Map<String, dynamic>>();

      if (records.isEmpty && !json && !follow) {
        ctx.output.warning('No event records (register MagicEventWatcher).');
      }
      for (final r in records) {
        ctx.output.writeln(json ? jsonEncode(r) : _format(r));
      }

      if (!follow || _shouldStop(polls)) return 0;

      // The cursor is the last atUs seen, so the next read returns only newer
      // records and needs no limit.
      final cursor = response['cursor'];
      if (cursor != null) params['since'] = cursor.toString();
      params.remove('limit');
      await _delay(_pollInterval);
    }
  }

  String _format(Map<String, dynamic> r) {
    final listeners =
        r['listenerCount'] == null ? '' : ' listeners=${r['listenerCount']}';
    return '${r['time']} ${r['eventType']} ${r['payload']}$listeners';
  }
}

Future<void> _wait(Duration duration) => Future<void>.delayed(duration);

bool _never(int polls) => false;
