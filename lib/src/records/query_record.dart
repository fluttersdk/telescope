/// An immutable database query record captured by MagicQueryWatcher
/// (shipped in `magic` package via TelescopePlugin.registerWatcher).
class QueryRecord {
  QueryRecord({
    required this.sql,
    required this.bindings,
    required this.timeMs,
    required this.time,
    this.connectionName = 'default',
  });

  /// The SQL string the QueryBuilder dispatched to the underlying driver.
  final String sql;

  /// Positional or named query bindings. Held as `List<Object?>` so the
  /// JSON envelope stays predictable; magic dispatches `List<dynamic>`,
  /// which is structurally identical.
  final List<Object?> bindings;

  /// Execution time in milliseconds reported by magic's QueryBuilder.
  final int timeMs;

  /// Connection name (`default` when the consumer did not name it).
  final String connectionName;
  final DateTime time;

  Map<String, dynamic> toJson() => {
        'sql': sql,
        'bindings': bindings,
        'timeMs': timeMs,
        'connectionName': connectionName,
        'time': time.toIso8601String(),
      };
}
