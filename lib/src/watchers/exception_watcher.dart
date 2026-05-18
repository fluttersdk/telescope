import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../records/exception_record.dart';
import '../telescope_store.dart';
import 'watcher.dart';

/// Hooks both [FlutterError.onError] and [PlatformDispatcher.instance.onError]
/// to capture all unhandled exceptions in a Flutter app.
///
/// This matches the Flutter "Handling errors" canonical pattern:
/// - [FlutterError.onError] covers synchronous framework + widget errors
///   (null dereferences, assertion failures, layout overflows, etc.).
/// - [PlatformDispatcher.instance.onError] covers asynchronous errors,
///   errors from other isolates, and plugin-originated errors; paths that
///   never reach [FlutterError.onError].
///
/// Both hooks chain-preserve any previously-registered handler (Sentry,
/// Bugsnag, etc.) so that downstream observability is never silently masked.
/// The [PlatformDispatcher.onError] handler always returns `true` to signal
/// that the error has been handled, preventing the default platform error
/// handler from treating it as fatal.
///
/// On [uninstall], both handlers are restored to exactly the values they held
/// before [install] was called. Calling [install] while already installed is
/// a no-op (idempotent).
class ExceptionWatcher implements TelescopeWatcher {
  @override
  String get name => 'exception';

  FlutterExceptionHandler? _previousFlutterOnError;
  ErrorCallback? _previousPlatformOnError;
  bool _installed = false;

  @override
  void install() {
    if (_installed) return;
    _installed = true;

    // 1. Chain-preserve and replace FlutterError.onError (sync framework errors).
    _previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      TelescopeStore.recordException(
        ExceptionRecord(
          exceptionType: details.exception.runtimeType.toString(),
          message: details.exceptionAsString(),
          time: DateTime.now(),
          stackTrace: details.stack?.toString(),
        ),
      );
      _previousFlutterOnError?.call(details);
    };

    // 2. Chain-preserve and replace PlatformDispatcher.onError (async + isolate + plugin errors).
    _previousPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      TelescopeStore.recordException(
        ExceptionRecord(
          exceptionType: error.runtimeType.toString(),
          message: error.toString(),
          time: DateTime.now(),
          stackTrace: stack.toString(),
        ),
      );
      _previousPlatformOnError?.call(error, stack);
      // Return true to signal the error is handled and prevent the platform
      // from treating it as a fatal unhandled exception.
      return true;
    };
  }

  @override
  void uninstall() {
    if (!_installed) return;

    // 3. Restore both handlers symmetrically.
    FlutterError.onError = _previousFlutterOnError;
    PlatformDispatcher.instance.onError = _previousPlatformOnError;
    _installed = false;
  }
}
