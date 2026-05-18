import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttersdk_telescope/telescope.dart';
import 'package:magic/magic.dart';

import 'app/models/demo_model.dart';
import 'app/policies/demo_policy.dart';
import 'config/app.dart';

/// Demo entry. Boots a Magic-stack app and (in debug builds only) wires the
/// fluttersdk_telescope plugin plus the Magic-side adapter integration.
///
/// Install order mirrors the canonical pattern in
/// `uptizm-app/lib/main.dart:41-93`:
/// 1. `TelescopePlugin.install()` runs BEFORE `Magic.init()` so the
///    framework-side VM Service extensions + log sink come up regardless of
///    Magic's container readiness.
/// 2. `MagicTelescopeIntegration.install()` runs AFTER `Magic.init()` because
///    its adapters resolve `NetworkDriver` from the IoC container and bind
///    listener factories on `EventDispatcher`.
/// `kDebugMode` is the only gate: release builds tree-shake the entire
/// branch on every platform.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    TelescopePlugin.install();
  }

  await Magic.init(configFactories: [() => appConfig]);

  if (kDebugMode) {
    MagicTelescopeIntegration.install();
    // Define the demo ability BEFORE the user can tap the gate button.
    // Mirrors a `PolicyServiceProvider.boot()` registration.
    DemoPolicy().register();
  }

  runApp(const _DemoApp());
}

/// Plain Material root. We do not use [MagicApplication] because the demo
/// does not need routes / theme / title plumbing; the magic facades the
/// buttons call (`Http`, `Event`, `Gate`) work the moment `Magic.init()`
/// resolves, independent of the widget tree.
class _DemoApp extends StatelessWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telescope Magic Demo',
      debugShowCheckedModeBanner: false,
      home: const _HomeScreen(),
    );
  }
}

/// Single-screen demo. Each button exercises exactly one
/// telescope-via-magic capture surface; the snackbar feedback confirms the
/// trigger fired so the operator knows to pull the matching telescope MCP
/// tool (`telescope_requests`, `telescope_magic_models`, `telescope_gates`,
/// `telescope_events`) to see the captured record.
class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  /// Triggers a real Magic.Http GET. The request flows through magic's
  /// network driver, which carries the `_TelescopeNetworkInterceptor`
  /// installed by [MagicHttpFacadeAdapter]; the capture lands in
  /// [TelescopeStore.recentHttpRequests] regardless of network outcome.
  Future<void> _onHttpPressed(BuildContext context) async {
    try {
      await Http.get('https://httpbin.org/get');
    } catch (_) {
      // The interceptor records on error too; the snackbar is feedback
      // only, the capture has already happened.
    }
    if (!context.mounted) return;
    _flash(context, 'Dispatched Http.get ; check telescope_requests');
  }

  /// Dispatches [ModelCreated] for a fresh [DemoModel]. The synthetic
  /// dispatch skips magic's `save()` round-trip (no backend, no SQLite
  /// table) but exercises the exact event channel [MagicModelWatcher]
  /// subscribes to.
  Future<void> _onCreateModelPressed(BuildContext context) async {
    final model = DemoModel.fromMap({'id': 'demo-1', 'name': 'Hello'});
    await Event.dispatch(ModelCreated(model));
    if (!context.mounted) return;
    _flash(context, 'Dispatched ModelCreated ; check telescope_magic_models');
  }

  /// Dispatches [ModelSaved] for the same [DemoModel] shape. Mirrors the
  /// second half of `Model.save()` so [MagicModelWatcher] records a
  /// `saved` event tag separate from `created`.
  Future<void> _onSaveModelPressed(BuildContext context) async {
    final model = DemoModel.fromMap({'id': 'demo-1', 'name': 'Hello updated'});
    await Event.dispatch(ModelSaved(model));
    if (!context.mounted) return;
    _flash(context, 'Dispatched ModelSaved ; check telescope_magic_models');
  }

  /// Dispatches [ModelDeleted]. Closes the lifecycle so the operator can
  /// verify all three event tags (`created` / `saved` / `deleted`) land in
  /// [TelescopeStore.recentMagicModels].
  Future<void> _onDeleteModelPressed(BuildContext context) async {
    final model = DemoModel.fromMap({'id': 'demo-1', 'name': 'Hello'});
    await Event.dispatch(ModelDeleted(model));
    if (!context.mounted) return;
    _flash(context, 'Dispatched ModelDeleted ; check telescope_magic_models');
  }

  /// Calls `Gate.allows('demo.allow')`. Magic's gate manager dispatches
  /// [GateAccessChecked] for both allow AND deny outcomes; without an
  /// authenticated user, the call returns `false` but the capture still
  /// fires (denied path), which is the assertion under test.
  void _onGatePressed(BuildContext context) {
    Gate.allows('demo.allow');
    _flash(context, 'Checked Gate.allows ; check telescope_gates');
  }

  /// Dispatches an [AuthFailed] event with synthetic credentials. The
  /// event lives in the curated set [MagicEventWatcher] subscribes to;
  /// using [AuthFailed] keeps the demo free of an Authenticatable user
  /// stub (which [AuthLogin] / [AuthRestored] would require).
  Future<void> _onEventPressed(BuildContext context) async {
    await Event.dispatch(
      AuthFailed(const {'email': 'demo@example.com'}),
    );
    if (!context.mounted) return;
    _flash(context, 'Dispatched AuthFailed ; check telescope_events');
  }

  /// Context-bound feedback. We use [ScaffoldMessenger] instead of
  /// `Magic.toast` because the latter looks up [MagicRouter]'s navigator
  /// key, which is only wired when [MagicApplication] is the root widget
  /// (the demo uses a plain [MaterialApp] to keep the surface minimal).
  void _flash(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Telescope Magic Demo')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Each button triggers exactly one capture surface. Run '
                '`dart run fluttersdk_artisan:mcp` from the consumer to '
                'list captures via the matching telescope_* tool.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _onHttpPressed(context),
                child: const Text('Make Magic.Http call'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _onCreateModelPressed(context),
                child: const Text('Create DemoModel'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _onSaveModelPressed(context),
                child: const Text('Save DemoModel'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _onDeleteModelPressed(context),
                child: const Text('Delete DemoModel'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _onGatePressed(context),
                child: const Text('Check gate ability'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _onEventPressed(context),
                child: const Text('Trigger custom event'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
