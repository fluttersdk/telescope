import 'package:flutter/foundation.dart' show FlutterTimeline;
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
    int? atUs,
    this.redacted = false,
  }) : atUs = atUs ?? FlutterTimeline.now;

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

  /// Monotonic microsecond timestamp from `FlutterTimeline.now`, captured at
  /// construction unless the caller supplies one explicitly. The same clock
  /// as `EventRecord.atUs`, so a log line orders against an event whatever
  /// the wall-clock skew; [time] stays the wall-clock field for display.
  final int atUs;

  /// True when [TelescopeRedaction.redactor] ran over this record before it
  /// was buffered. A record made while no redactor was registered is false,
  /// and a consumer that persists records (a file sink) writes only the true
  /// ones.
  final bool redacted;

  Map<String, dynamic> toJson() => {
        'level': level,
        'levelValue': levelValue,
        'message': message,
        'loggerName': loggerName,
        'time': time.toIso8601String(),
        if (error != null) 'error': error,
        if (stackTrace != null) 'stackTrace': stackTrace,
        'atUs': atUs,
        'redacted': redacted,
      };
}
