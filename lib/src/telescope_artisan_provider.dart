import 'package:fluttersdk_artisan/artisan.dart';

import 'commands/telescope_clear_command.dart';
import 'commands/telescope_requests_command.dart';
import 'commands/telescope_tail_command.dart';

/// Contributes telescope:* commands and MCP tool descriptors to the artisan
/// dispatcher.
///
/// V1 ships 3 CLI commands (telescope:tail, telescope:requests, telescope:clear)
/// and 4 MCP tools backed by ext.telescope.* VM Service extensions registered
/// by [registerAllTelescopeExtensions]. The pause/resume extensions are BACKLOG
/// per D5 and are intentionally absent from mcpTools().
class TelescopeArtisanProvider extends ArtisanServiceProvider {
  @override
  String get providerName => 'fluttersdk_telescope';

  @override
  List<ArtisanCommand> commands() => <ArtisanCommand>[
        TelescopeTailCommand(),
        TelescopeRequestsCommand(),
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
      ];
}
