import 'package:logging/logging.dart';

/// An immutable log record captured by [LogWatcher].
class LogRecordEntry {
  LogRecordEntry({
    required this.level,
    required this.levelValue,
    required this.message,
    required this.loggerName,
    required this.time,
    this.error,
    this.stackTrace,
  });

  factory LogRecordEntry.fromLogRecord(LogRecord r) => LogRecordEntry(
        level: r.level.name,
        levelValue: r.level.value,
        message: r.message,
        loggerName: r.loggerName,
        time: r.time,
        error: r.error?.toString(),
        stackTrace: r.stackTrace?.toString(),
      );

  final String level;
  final int levelValue;
  final String message;
  final String loggerName;
  final DateTime time;
  final String? error;
  final String? stackTrace;

  Map<String, dynamic> toJson() => {
        'level': level,
        'levelValue': levelValue,
        'message': message,
        'loggerName': loggerName,
        'time': time.toIso8601String(),
        if (error != null) 'error': error,
        if (stackTrace != null) 'stackTrace': stackTrace,
      };
}
