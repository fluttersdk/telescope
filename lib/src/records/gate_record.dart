/// An immutable authorization gate check record captured by a gate watcher
/// (e.g. MagicGateWatcher shipped in the `magic` package).
class GateRecord {
  GateRecord({
    required this.ability,
    required this.result,
    required this.arguments,
    required this.time,
    this.userId,
  });

  final String ability;

  /// True when the gate allowed the action; false when denied.
  final bool result;
  final List<Object?> arguments;
  final DateTime time;

  /// The authenticated user's ID at check time, when available.
  final String? userId;

  Map<String, dynamic> toJson() => {
        'ability': ability,
        'result': result,
        'arguments': arguments,
        'time': time.toIso8601String(),
        if (userId != null) 'userId': userId,
      };
}
