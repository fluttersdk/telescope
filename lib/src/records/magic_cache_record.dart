/// An immutable Magic cache operation record captured by MagicCacheWatcher
/// (shipped in `magic` package).
class MagicCacheRecord {
  MagicCacheRecord({
    required this.operation,
    required this.key,
    required this.time,
    this.ttl,
  });

  /// 'put' | 'get' | 'forget' | 'hit' | 'miss'
  final String operation;
  final String key;
  final DateTime time;
  final Duration? ttl;

  Map<String, dynamic> toJson() => {
    'operation': operation,
    'key': key,
    'time': time.toIso8601String(),
    if (ttl != null) 'ttlMs': ttl!.inMilliseconds,
  };
}
