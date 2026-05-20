# Telescope MCP Integration Overview

<a name="toc"></a>

- [What Telescope Contributes](#what-telescope-contributes)
- [Substrate Tools vs Plugin Tools](#substrate-vs-plugin)
- [How the 9 Tools Surface](#how-tools-surface)
- [VM Service Extension Routing](#vm-service-routing)
- [Architecture Diagram](#architecture-diagram)
- [Related](#related)

---

<a name="what-telescope-contributes"></a>

## What Telescope Contributes

`fluttersdk_telescope` is a plugin for `fluttersdk_artisan`. It contributes **9 MCP tools** via
`TelescopeArtisanProvider.mcpTools()` and **6 CLI commands** via `TelescopeArtisanProvider.commands()`.

The 9 MCP tools give an LLM agent read-only access to ring buffers that telescope maintains inside the
running Flutter app. Each tool reads one buffer type: HTTP traffic, log lines, uncaught exceptions,
in-app events, Gate authorization checks, `debugPrint` output, database queries, and cache operations.
A tenth tool (`telescope_clear`) wipes all buffers at once as a "set zero" before a repro.

The tools share a single design rule: **no side effects on the running app**. Reading a buffer is
non-destructive; only `telescope_clear` mutates state, and that mutation is intentional.

---

<a name="substrate-vs-plugin"></a>

## Substrate Tools vs Plugin Tools

artisan's MCP server distinguishes two categories of tools. Understanding the distinction explains
why telescope tools appear or disappear in Claude Code's tool list depending on registration.

**Substrate tools** (`artisan_*` prefix) are built into `fluttersdk_artisan` itself. They are always
registered when the MCP server starts; they require no plugin, no running app (for most of them), and
no VM Service connection. Examples: `artisan_start`, `artisan_stop`, `artisan_status`, `artisan_logs`.

**Plugin tools** (`telescope_*` prefix, `dusk_*` prefix, etc.) are contributed by packages that
extend `ArtisanServiceProvider`. They surface in the MCP catalog **only when** the plugin's provider
is registered in the consumer's `bin/dispatcher.dart` (auto-wired by `telescope:install`) and the MCP server is (re)started. Plugin tools
always dispatch via the VM Service and therefore require a running Flutter app.

`TelescopeArtisanProvider` contributes the `fluttersdk_telescope` plugin tools. Its `providerName`
is `fluttersdk_telescope`, which is the key used in `.artisan/mcp.json` package filter rules.

---

<a name="how-tools-surface"></a>

## How the 9 Tools Surface

The call chain from Claude Code to the Telescope ring buffer:

1. `TelescopeArtisanProvider.mcpTools()` returns a `List<McpToolDescriptor>` with the 9 descriptors.
2. `McpServer.initialize()` collects descriptors from every registered provider and sends the full
   catalog to the MCP client (Claude Code) in the `initialize` response.
3. The agent invokes a tool by name (e.g. `telescope_tail`) with optional parameters.
4. `McpServer` looks up the `McpToolDescriptor.extensionMethod` for that tool name (e.g.
   `ext.telescope.console`) and dispatches via `VmServiceClient.callServiceExtension`.
5. The VM Service handler registered by `registerAllTelescopeExtensions()` in the running Flutter app
   reads the matching `TelescopeStore` ring buffer, applies any `limit` / `level` filter params, and
   returns a JSON-encoded payload.
6. `McpServer` wraps the payload in a `CallToolResult` text content block and returns it to the agent.

The pause/resume extensions (`ext.telescope.pause` / `ext.telescope.resume`) are registered inside
the app but intentionally absent from `mcpTools()` in the current release; they are V1.x backlog.

---

<a name="vm-service-routing"></a>

## VM Service Extension Routing

Each MCP tool maps to exactly one VM Service extension:

| MCP tool | VM Service extension |
|---|---|
| `telescope_tail` | `ext.telescope.console` |
| `telescope_requests` | `ext.telescope.requests` |
| `telescope_exceptions` | `ext.telescope.exceptions` |
| `telescope_events` | `ext.telescope.events` |
| `telescope_gates` | `ext.telescope.gates` |
| `telescope_dumps` | `ext.telescope.dumps` |
| `telescope_queries` | `ext.telescope.queries` |
| `telescope_caches` | `ext.telescope.caches` |
| `telescope_clear` | `ext.telescope.clear` |

Every extension is registered via `registerExtensionIdempotent` (from `fluttersdk_artisan`) so that
Flutter hot restarts do not throw `ArgumentError` on duplicate registration. `VmServiceClient` inside
artisan lazy-reconnects on every dispatch call, so `artisan_start` followed immediately by a
`telescope_*` call picks up the new VM Service URI automatically from `~/.artisan/state.json`.

---

<a name="architecture-diagram"></a>

## Architecture Diagram

```
  Claude Code (MCP client)
        |
        | stdio JSON-RPC  (initialize / tools/call)
        |
  dart run fluttersdk_artisan:mcp
        |
   McpServer
        |
        +-- substrate tools (artisan_start, artisan_stop, ...)
        |         |
        |         v
        |   ArtisanRegistry  (in-process command dispatch)
        |
        +-- telescope_* plugin tools
                  |
                  | VM Service WebSocket
                  | ws://localhost:PORT/<token>/ws
                  |
             VmServiceClient
                  |
                  | ext.telescope.*
                  |
          Flutter app isolate (debug mode)
                  |
          TelescopeStore (ring buffers)
          +--------+----------+---------+----------+
          |        |          |         |          |
       console  requests  exceptions  events    gates
          |        |          |         |          |
       dumps   queries    caches
```

**Flow summary:**

1. The MCP client connects to the server over stdio and calls `initialize`.
2. `McpServer` collects `McpToolDescriptor` instances from `TelescopeArtisanProvider.mcpTools()` (and
   any other registered provider) and sends the unified catalog to the client.
3. On each `telescope_*` tool call, `McpServer` routes via `VmServiceClient` to the matching
   `ext.telescope.*` handler in the running Flutter isolate.
4. The handler reads the `TelescopeStore` ring buffer, applies filter parameters, and returns JSON.
5. Results return as `CallToolResult` text content; errors carry `isError: true` with an actionable
   message.

---

<a name="related"></a>

## Related

- [artisan MCP overview](https://fluttersdk.com/artisan/mcp/overview): full substrate tool catalog,
  state file contract, and artisan's own architecture diagram.
- [Setup guide](setup.md): how to wire `TelescopeArtisanProvider` and enable the 9 tools in Claude
  Code or Cursor.
- [Tool reference](tool-reference.md): per-tool input schema, output shape, example invocations, and
  the VM Service extension each tool routes through.
