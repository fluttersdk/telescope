import '../telescope_redaction.dart';

/// An immutable exception record captured by [ExceptionWatcher].
class ExceptionRecord {
  ExceptionRecord({
    required this.exceptionType,
    required this.message,
    required this.time,
    this.stackTrace,
    this.isolate,
  });

  final String exceptionType;
  final String message;
  final DateTime time;
  final String? stackTrace;
  final String? isolate;

  /// True when [TelescopeRedaction.redactor] ran over this record before it
  /// was buffered: only the store's redaction pass sets it, so a record a
  /// caller constructs is always false. A record made while no redactor was
  /// registered is false too, and a consumer that persists records (a file
  /// sink) writes only the true ones.
  bool get redacted => TelescopeRedaction.isRedacted(this);

  Map<String, dynamic> toJson() => {
        'exceptionType': exceptionType,
        'message': message,
        'time': time.toIso8601String(),
        if (stackTrace != null) 'stackTrace': stackTrace,
        if (isolate != null) 'isolate': isolate,
        'redacted': redacted,
      };
}
