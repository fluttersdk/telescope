import 'package:magic/magic.dart';

/// Minimal Eloquent-style model used by the telescope Magic demo.
///
/// The home screen dispatches [ModelCreated], [ModelSaved], and
/// [ModelDeleted] for a [DemoModel] instance to verify that
/// [MagicModelWatcher] captures lifecycle events into
/// [TelescopeStore.recentMagicModels]. The model deliberately stays
/// local-only ([useRemote] = `false`, [useLocal] = `false`) so dispatch
/// does not require a backend or a SQLite table; the demo emits the
/// lifecycle events directly via `Event.dispatch(...)` to keep the
/// example self-contained.
class DemoModel extends Model with HasTimestamps, InteractsWithPersistence {
  @override
  String get table => 'demo_models';

  @override
  String get resource => 'demo-models';

  @override
  bool get incrementing => false;

  @override
  bool get useRemote => false;

  @override
  bool get useLocal => false;

  @override
  List<String> get fillable => ['id', 'name'];

  /// Convenience factory mirroring the canonical magic Model factory shape
  /// (`fill` then `syncOriginal` then `exists` based on whether the wire
  /// payload carried the primary key).
  static DemoModel fromMap(Map<String, dynamic> map) => DemoModel()
    ..fill(map)
    ..syncOriginal()
    ..exists = map.containsKey('id');
}
