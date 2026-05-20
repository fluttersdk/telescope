import 'package:fluttersdk_artisan/artisan.dart';

import 'commands/telescope_caches_command.dart';
import 'commands/telescope_clear_command.dart';
import 'commands/telescope_install_command.dart';
import 'commands/telescope_queries_command.dart';
import 'commands/telescope_requests_command.dart';
import 'commands/telescope_tail_command.dart';

/// Contributes telescope:* commands and MCP tool descriptors to the artisan
/// dispatcher.
///
/// V1 ships 6 CLI commands (telescope:install, telescope:tail, telescope:requests,
/// telescope:queries, telescope:caches, telescope:clear) and 9 MCP tools backed
/// by ext.telescope.* VM Service extensions registered by
/// [registerAllTelescopeExtensions]. The pause/resume extensions are BACKLOG
/// per D5 and are intentionally absent from mcpTools().
class TelescopeArtisanProvider extends ArtisanServiceProvider {
  @override
  String get providerName => 'fluttersdk_telescope';

  @override
  List<ArtisanCommand> commands() => <ArtisanCommand>[
        TelescopeInstallCommand(),
        TelescopeTailCommand(),
        TelescopeRequestsCommand(),
        TelescopeQueriesCommand(),
        TelescopeCachesCommand(),
        TelescopeClearCommand(),
      ];

  @override
  List<McpToolDescriptor> mcpTools() => const <McpToolDescriptor>[
        McpToolDescriptor(
          name: 'telescope_tail',
          description: 'Return recent log records from the running Flutter '
              'app.\n'
              '\n'
              'Reads the Telescope log ring buffer (populated by every '
              '`package:logging` Logger call in the app) and returns the '
              'most recent entries. Each record carries timestamp, level, '
              'logger name, message, and any attached error / stackTrace. '
              'Use this to inspect what the app logged without scraping '
              'flutter run stdout via artisan_logs.\n'
              '\n'
              'Usage:\n'
              '- Pass `limit: <n>` to cap how many records come back '
              '(default returns the whole buffer; cap is ring-buffer '
              'size).\n'
              '- Pass `level: "<name>"` (e.g. `"WARNING"`, `"SEVERE"`) to '
              'filter by minimum log level; omit for all levels.\n'
              '- Returns newest-first; pair with telescope_clear before a '
              'repro to isolate just the relevant logs.\n'
              '- For HTTP traffic use telescope_requests; for crashes use '
              'telescope_exceptions; this tool covers general logs only.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'level': {
                'type': 'string',
                'description': 'Minimum log level to include. Common '
                    'values: `FINE`, `INFO`, `WARNING`, `SEVERE`, '
                    '`SHOUT`. Omit for all levels.',
              },
              'limit': {
                'type': 'integer',
                'description': 'Maximum number of records to return '
                    '(newest first). Omit for the whole buffer (cap '
                    'enforced by the ring-buffer size, typically 200).',
              },
            },
          },
          extensionMethod: 'ext.telescope.console',
        ),
        McpToolDescriptor(
          name: 'telescope_requests',
          description: 'Return recent HTTP request records from the '
              'running Flutter app.\n'
              '\n'
              'Reads the Telescope HTTP ring buffer (populated by the '
              'Telescope Dio interceptor or any HttpAdapter the app '
              'installs). Each record carries method, url, status code, '
              'duration, request headers, response body snippet, and '
              'error if the call failed. Use this to debug API issues '
              'without instrumenting the app or watching network panels '
              'in DevTools.\n'
              '\n'
              'Usage:\n'
              '- Pass `limit: <n>` to cap the response size; default '
              'returns the whole buffer.\n'
              '- Returns newest-first; pair with telescope_clear to '
              'isolate traffic from a specific user action.\n'
              '- Only HTTP calls that go through an installed Telescope '
              'adapter are recorded; raw `dart:io HttpClient` calls are '
              'invisible to this tool.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'limit': {
                'type': 'integer',
                'description': 'Maximum number of HTTP records to return '
                    '(newest first). Omit for the whole buffer.',
              },
            },
          },
          extensionMethod: 'ext.telescope.requests',
        ),
        McpToolDescriptor(
          name: 'telescope_clear',
          description: 'Clear every Telescope ring buffer (http, logs, '
              'exceptions).\n'
              '\n'
              'Wipes the three ring buffers in one call so the next '
              'telescope_tail / telescope_requests / telescope_exceptions '
              'returns only records produced AFTER this clear. Useful as '
              'a "set zero" before reproducing a bug or capturing the '
              'output of a specific user action.\n'
              '\n'
              'Usage:\n'
              '- No parameters; clears all three buffers atomically.\n'
              '- Idempotent: safe to call when buffers are already empty.\n'
              '- Does NOT affect the live `package:logging` stream; only '
              'the captured ring buffers.',
          inputSchema: {'type': 'object', 'properties': <String, dynamic>{}},
          extensionMethod: 'ext.telescope.clear',
        ),
        McpToolDescriptor(
          name: 'telescope_exceptions',
          description: 'Return recent uncaught exception records from the '
              'running Flutter app.\n'
              '\n'
              'Reads the Telescope exception ring buffer (populated by '
              'the `FlutterError.onError` hook the Telescope plugin '
              'installs). Each record carries timestamp, exception type, '
              'message, library, and full stackTrace. Use this when a '
              'crash or `Exception` was thrown and you need the stack '
              'without scraping flutter run stdout.\n'
              '\n'
              'Usage:\n'
              '- Pass `limit: <n>` to cap how many records come back '
              '(default returns the whole buffer).\n'
              '- Returns newest-first.\n'
              '- Covers uncaught exceptions only; expected `try / catch` '
              'flows do not surface here. Pair with telescope_tail to '
              'see what the app logged around the crash.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'limit': {
                'type': 'integer',
                'description': 'Maximum number of exception records to '
                    'return (newest first). Omit for the whole buffer.',
              },
            },
          },
          extensionMethod: 'ext.telescope.exceptions',
        ),
        McpToolDescriptor(
          name: 'telescope_events',
          description: 'Return recent in-app event records from the running '
              'Flutter app.\n'
              '\n'
              'Reads the Telescope events ring buffer (populated by the '
              'MagicEventWatcher whenever `Event.dispatch()` is called). '
              'Each record carries timestamp, event class name, and a JSON '
              'snapshot of the event payload. Use this to trace event-driven '
              'side effects (cache invalidation, broadcast echoes, model '
              'lifecycle transitions) without adding debug print statements '
              'to the codebase.\n'
              '\n'
              'Usage:\n'
              '- Pass `limit: <n>` to cap how many records come back '
              '(default returns the whole buffer; cap is ring-buffer '
              'size).\n'
              '- Returns newest-first; pair with telescope_clear before a '
              'repro to isolate just the relevant event sequence.\n'
              '- Only events dispatched through the Magic `Event` facade '
              'are recorded; raw `ChangeNotifier.notifyListeners` calls '
              'are invisible to this tool.\n'
              '- For HTTP traffic use telescope_requests; for gate '
              'checks use telescope_gates.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'limit': {
                'type': 'integer',
                'description': 'Maximum number of event records to return '
                    '(newest first). Omit for the whole buffer (cap '
                    'enforced by the ring-buffer size, typically 500).',
              },
            },
          },
          extensionMethod: 'ext.telescope.events',
        ),
        McpToolDescriptor(
          name: 'telescope_gates',
          description: 'Return recent Gate authorization check records from '
              'the running Flutter app.\n'
              '\n'
              'Reads the Telescope gates ring buffer (populated by the '
              'MagicGateWatcher on every `Gate.allows / Gate.denies` call). '
              'Each record carries timestamp, ability name, result (allowed '
              'or denied), authenticated user id, and the argument class '
              'name if one was provided. Use this to debug authorization '
              'issues (why a button is hidden, why a route is blocked) '
              'without modifying policy classes.\n'
              '\n'
              'Usage:\n'
              '- Pass `limit: <n>` to cap how many records come back '
              '(default returns the whole buffer).\n'
              '- Returns newest-first; pair with telescope_clear before '
              'walking a guarded flow to isolate just the relevant checks.\n'
              '- Only checks routed through the Magic `Gate` facade are '
              'recorded; direct policy class calls are not captured.\n'
              '- For event side effects use telescope_events; for HTTP '
              'traffic use telescope_requests.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'limit': {
                'type': 'integer',
                'description': 'Maximum number of gate check records to '
                    'return (newest first). Omit for the whole buffer (cap '
                    'enforced by the ring-buffer size, typically 500).',
              },
            },
          },
          extensionMethod: 'ext.telescope.gates',
        ),
        McpToolDescriptor(
          name: 'telescope_dumps',
          description: 'Return recent debug dump records from the running '
              'Flutter app.\n'
              '\n'
              'Reads the Telescope dumps ring buffer (populated by the '
              'DumpWatcher which overrides `debugPrint` globally). Each '
              'record carries timestamp and the full message string that '
              'was passed to `debugPrint`. Use this to read `print()` / '
              '`debugPrint()` output from within the running app without '
              'scraping flutter run stdout.\n'
              '\n'
              'Usage:\n'
              '- Pass `limit: <n>` to cap how many records come back '
              '(default returns the whole buffer).\n'
              '- Returns newest-first; pair with telescope_clear before '
              'a repro to isolate just the relevant print output.\n'
              '- Only output routed through `debugPrint` (the global '
              'override point) is captured; `dart:io stdout.write` calls '
              'are invisible to this tool.\n'
              '- For structured logs use telescope_tail; for crashes use '
              'telescope_exceptions.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'limit': {
                'type': 'integer',
                'description': 'Maximum number of dump records to return '
                    '(newest first). Omit for the whole buffer (cap '
                    'enforced by the ring-buffer size, typically 500).',
              },
            },
          },
          extensionMethod: 'ext.telescope.dumps',
        ),
        McpToolDescriptor(
          name: 'telescope_queries',
          description: 'Return recent database query records from the '
              'running Flutter app.\n'
              '\n'
              'Reads the Telescope queries ring buffer (populated by the '
              'MagicQueryWatcher subscribed to magic\'s `QueryExecuted` '
              'event). Each record carries timestamp, SQL string, bindings '
              'list, execution time (ms), and connection name. Use this to '
              'inspect what queries the QueryBuilder dispatched without '
              'attaching a separate SQL profiler.\n'
              '\n'
              'Usage:\n'
              '- Pass `limit: <n>` to cap how many records come back '
              '(default returns the whole buffer).\n'
              '- Returns newest-first; pair with telescope_clear before '
              'a repro to isolate the queries from a specific user action.\n'
              '- Only queries that go through magic\'s QueryBuilder (and '
              'dispatch `QueryExecuted` via EventDispatcher) are recorded; '
              'raw SQL on a direct sqlite3/dio client bypasses this tool.\n'
              '- For Magic Cache traffic use telescope_caches; for HTTP '
              'use telescope_requests; for app log lines use telescope_tail.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'limit': {
                'type': 'integer',
                'description': 'Maximum number of query records to return '
                    '(newest first). Omit for the whole buffer (cap '
                    'enforced by the ring-buffer size, typically 500).',
              },
            },
          },
          extensionMethod: 'ext.telescope.queries',
        ),
        McpToolDescriptor(
          name: 'telescope_caches',
          description: 'Return recent Magic Cache operation records from '
              'the running Flutter app.\n'
              '\n'
              'Reads the Telescope caches ring buffer (populated by the '
              'MagicCacheWatcher subscribed to magic\'s CacheHit / CacheMiss '
              '/ CachePut / CacheForget / CacheFlush events). Each record '
              'carries timestamp, operation tag (`hit | miss | put | forget '
              '| flush`), cache key, and optional TTL. Use this to inspect '
              'cache traffic without instrumenting the consumer code.\n'
              '\n'
              'Usage:\n'
              '- Pass `limit: <n>` to cap how many records come back '
              '(default returns the whole buffer).\n'
              '- Returns newest-first; pair with telescope_clear before '
              'a repro to isolate the cache traffic of a specific action.\n'
              '- Only Magic.Cache facade calls dispatch these events; raw '
              'driver-level cache calls bypass this tool.\n'
              '- For DB queries use telescope_queries; for HTTP use '
              'telescope_requests.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'limit': {
                'type': 'integer',
                'description': 'Maximum number of cache records to return '
                    '(newest first). Omit for the whole buffer (cap '
                    'enforced by the ring-buffer size, typically 500).',
              },
            },
          },
          extensionMethod: 'ext.telescope.caches',
        ),
      ];
}
