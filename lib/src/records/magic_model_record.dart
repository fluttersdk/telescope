/// An immutable Magic model lifecycle event captured by MagicModelWatcher
/// (shipped in `magic` package via TelescopePlugin.registerWatcher).
class MagicModelRecord {
  MagicModelRecord({
    required this.modelClass,
    required this.event,
    required this.modelKey,
    required this.time,
    this.attributes,
  });

  final String modelClass;

  /// 'created' | 'saved' | 'deleted'
  final String event;
  final String modelKey;
  final DateTime time;
  final Map<String, dynamic>? attributes;

  Map<String, dynamic> toJson() => {
        'modelClass': modelClass,
        'event': event,
        'modelKey': modelKey,
        'time': time.toIso8601String(),
        if (attributes != null) 'attributes': attributes,
      };
}
