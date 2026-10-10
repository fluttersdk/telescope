import 'dart:async';

/// Polls a cursor-paged source until told to stop; the loop behind `--follow`.
///
/// Pure Dart: it imports no Flutter library, so a command that runs under
/// `dart run` can use it through `package:fluttersdk_telescope/cli.dart`.
///
/// Each round calls [read] with the cursor the previous round returned
/// ([since] on the first round), then asks [shouldStop], then waits
/// [interval] through [delay]. [read] returns the next cursor; a null keeps
/// the cursor of the last round that returned one, so an empty poll never
/// rewinds. [delay] and [shouldStop] exist so a test can run the loop without
/// a clock or a Ctrl-C; by default the loop waits on the real clock and ends
/// only when the process does.
Future<void> followCursor({
  required Future<int?> Function(int? since) read,
  int? since,
  Duration interval = const Duration(seconds: 1),
  Future<void> Function(Duration) delay = _wait,
  bool Function() shouldStop = _never,
}) async {
  var cursor = since;
  while (true) {
    cursor = await read(cursor) ?? cursor;
    if (shouldStop()) return;

    await delay(interval);
  }
}

Future<void> _wait(Duration duration) => Future<void>.delayed(duration);

bool _never() => false;
