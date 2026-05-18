import 'package:magic/magic.dart';

/// Demo policy registering the `demo.allow` ability.
///
/// The home screen calls `Gate.allows('demo.allow')` to fire a
/// [GateAccessChecked] event, which [MagicGateWatcher] translates into
/// a [GateRecord] in [TelescopeStore.recentGates]. The ability always
/// returns `true` because the demo cares about capture mechanics, not
/// the authorization outcome itself.
class DemoPolicy extends Policy {
  /// Plain constructor. Magic's [Policy] base does not expose a const
  /// constructor, so the demo follows the same shape as the magic docs
  /// (`DemoPolicy().register()`).
  DemoPolicy();

  @override
  void register() {
    Gate.define('demo.allow', (user, [arguments]) => true);
  }
}
