import '../adapters/http_adapter.dart';

/// Library-internal registry of HTTP adapters whose [TelescopeHttpAdapter.pendingCount]
/// feeds [TelescopeStore.pendingHttpCount].
///
/// Populated by [TelescopePlugin.registerHttpAdapter] on every successful
/// adapter registration. Cleared by [TelescopeStore.resetForTesting] for test
/// isolation. Not exported from the public barrel (`lib/telescope.dart`); the
/// only public surface that touches the list is [TelescopeStore.pendingHttpCount]
/// (read) and [TelescopePlugin.registerHttpAdapter] (append).
///
/// Kept here (rather than as a private static on [TelescopeStore]) so the
/// "TelescopeStore gains exactly one new public symbol (pendingHttpCount)"
/// constraint stays intact while still letting [TelescopePlugin] in a separate
/// file feed the list.
final List<TelescopeHttpAdapter> httpAdapterRegistry = <TelescopeHttpAdapter>[];
