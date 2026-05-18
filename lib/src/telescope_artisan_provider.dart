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
          description: 'Print recent log records from the running app.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'level': {'type': 'string'},
              'limit': {'type': 'integer'},
            },
          },
          extensionMethod: 'ext.telescope.console',
        ),
        McpToolDescriptor(
          name: 'telescope_requests',
          description:
              'Print recent HTTP request records from the running app.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'limit': {'type': 'integer'},
            },
          },
          extensionMethod: 'ext.telescope.requests',
        ),
        McpToolDescriptor(
          name: 'telescope_clear',
          description:
              'Clear all telescope ring buffers (http, logs, exceptions).',
          inputSchema: {'type': 'object', 'properties': <String, dynamic>{}},
          extensionMethod: 'ext.telescope.clear',
        ),
        McpToolDescriptor(
          name: 'telescope_exceptions',
          description: 'Print recent exception records from the running app.',
          inputSchema: {
            'type': 'object',
            'properties': {
              'limit': {'type': 'integer'},
            },
          },
          extensionMethod: 'ext.telescope.exceptions',
        ),
      ];
}
