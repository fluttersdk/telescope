/// An immutable debugPrint output record captured by [DumpWatcher].
class DumpRecord {
  DumpRecord({
    required this.message,
    required this.time,
    this.wrapWidth,
  });

  final String message;
  final DateTime time;

  /// The wrap width passed to the original debugPrint call, when available.
  final int? wrapWidth;

  Map<String, dynamic> toJson() => {
        'message': message,
        'time': time.toIso8601String(),
        if (wrapWidth != null) 'wrapWidth': wrapWidth,
      };
}
