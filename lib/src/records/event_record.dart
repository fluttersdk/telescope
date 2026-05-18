/// An immutable app event record captured by an event watcher
/// (e.g. MagicEventWatcher shipped in the `magic` package).
class EventRecord {
  EventRecord({
    required this.eventType,
    required this.payload,
    required this.time,
    this.listenerCount,
  });

  final String eventType;
  final Map<String, dynamic> payload;
  final DateTime time;

  /// Number of listeners notified at dispatch time, when available.
  final int? listenerCount;

  Map<String, dynamic> toJson() => {
        'eventType': eventType,
        'payload': payload,
        'time': time.toIso8601String(),
        if (listenerCount != null) 'listenerCount': listenerCount,
      };
}
