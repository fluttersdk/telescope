/// An immutable exception record captured by [ExceptionWatcher].
class ExceptionRecord {
  ExceptionRecord({
    required this.exceptionType,
    required this.message,
    required this.time,
    this.stackTrace,
    this.isolate,
    this.redacted = false,
  });

  final String exceptionType;
  final String message;
  final DateTime time;
  final String? stackTrace;
  final String? isolate;

  /// True when [TelescopeRedaction.redactor] ran over this record before it
  /// was buffered. A record made while no redactor was registered is false,
  /// and a consumer that persists records (a file sink) writes only the true
  /// ones.
  final bool redacted;

  Map<String, dynamic> toJson() => {
        'exceptionType': exceptionType,
        'message': message,
        'time': time.toIso8601String(),
        if (stackTrace != null) 'stackTrace': stackTrace,
        if (isolate != null) 'isolate': isolate,
        'redacted': redacted,
      };
}
