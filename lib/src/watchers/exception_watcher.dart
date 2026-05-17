import 'package:flutter/foundation.dart';

import '../records/exception_record.dart';
import '../telescope_store.dart';
import 'watcher.dart';

/// Hooks [FlutterError.onError] to capture framework + widget exceptions.
///
/// For Dart isolate-level errors (zoned errors from `runZonedGuarded`),
/// the host's runApp() wrapper must explicitly call
/// `TelescopeStore.recordException(ExceptionRecord(...))` since wrapping
/// runApp from inside this watcher would require a runApp lambda.
class ExceptionWatcher implements TelescopeWatcher {
  @override
  String get name => 'exception';

  FlutterExceptionHandler? _previous;
  bool _installed = false;

  @override
  void install() {
    if (_installed) return;
    _installed = true;
    _previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      TelescopeStore.recordException(
        ExceptionRecord(
          exceptionType: details.exception.runtimeType.toString(),
          message: details.exceptionAsString(),
          time: DateTime.now(),
          stackTrace: details.stack?.toString(),
        ),
      );
      _previous?.call(details);
    };
  }

  @override
  void uninstall() {
    if (!_installed) return;
    FlutterError.onError = _previous;
    _installed = false;
  }
}
