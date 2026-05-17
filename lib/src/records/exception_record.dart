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

  Map<String, dynamic> toJson() => {
    'exceptionType': exceptionType,
    'message': message,
    'time': time.toIso8601String(),
    if (stackTrace != null) 'stackTrace': stackTrace,
    if (isolate != null) 'isolate': isolate,
  };
}
