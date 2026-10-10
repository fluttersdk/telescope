# Cursor and filters

`ext.telescope.console` (log records) and `ext.telescope.events` (event records) accept filters and answer
a `cursor`, so a reader can follow a buffer without re-reading it or skipping a record. The parameters
are part of the VM Service extension and the CLI. The MCP descriptors for `telescope_tail` and
`telescope_events` still declare only `limit` (and `level` on tail); an MCP agent that needs the cursor
reads the extension through the CLI (`telescope:tail --json`, `telescope:events --json`).

## Extension parameters

All values are strings on the wire, as with every VM Service extension.

| Extension | Parameter | Meaning |
|---|---|---|
| `ext.telescope.console` | `level` | Minimum `package:logging` level name. An unknown name matches nothing. |
| `ext.telescope.console` | `logger` | Exact logger name. |
| `ext.telescope.events` | `type` | Prefix of `eventType`. |
| both | `since` | Microseconds, exclusive, compared with the record's `atUs`. |
| both | `limit` | Applied after the filters. A zero or negative value returns nothing. |

A `since` that is not an integer is refused with `invalidParams` (`since must be an integer number of
microseconds.`) rather than read as "from the start", so a typo cannot return the whole buffer as if it
were new.

## Which records `limit` keeps

The filters run first, then `limit`:

- With `since`, `limit` keeps the OLDEST N records after it. Paging by `cursor` then skips nothing.
- Without `since`, `limit` keeps the NEWEST N records that matched.

Records come back oldest first either way.

## The `cursor`

Both answers carry `cursor`: the largest `atUs` among the returned records, else the `since` you passed,
else null. Pass it back as `since` and the next answer holds only newer records.

```json
{
  "messages": [
    {"level": "INFO", "message": "synced", "loggerName": "Sync", "atUs": 81234567, "redacted": true}
  ],
  "cursor": 81234567
}
```

`ext.telescope.console` answers its records under `messages`, `ext.telescope.events` under `events`.
Every other read extension keeps its existing envelope and takes `limit` only.

## CLI

`telescope:tail` and `telescope:events` expose the same parameters as flags:

| Flag | `telescope:tail` | `telescope:events` | Meaning |
|---|---|---|---|
| `--limit=<n>` | yes (50) | yes (50) | Records to print. |
| `--level=<name>` | yes | no | Minimum log level. |
| `--since=<atUs>` | yes | yes | Only records after this `atUs`. |
| `--logger=<name>` | yes | no | Exact logger name. |
| `--type=<prefix>` | no | yes | Event types starting with this prefix. |
| `--json` | yes | yes | One JSON object per line, the payload as JSON. |
| `--follow` | yes | yes | Keep polling until interrupted. |

`--follow` re-reads once a second from the cursor the previous read returned. After the first read it
drops `--limit`, since the cursor already bounds the read. A null cursor from an empty poll keeps the
previous one, so a quiet buffer never rewinds. Without `--json` an empty read prints the usual
empty-buffer hint; with `--json` or `--follow` it prints nothing.

```bash
./bin/fsa telescope:tail --logger=Sync --json --follow
./bin/fsa telescope:events --type=Auth --since=81234567
```

## `followCursor`

The loop behind `--follow` is a pure Dart function, exported from `package:fluttersdk_telescope/cli.dart`
so a command that runs under `dart run` can build on it:

```dart
import 'package:fluttersdk_telescope/cli.dart' show followCursor;

await followCursor(
  since: null,
  interval: const Duration(seconds: 1),
  read: (int? since) async {
    final response = await fetch(since); // call the extension with `since`
    handle(response);
    return response['cursor'] as int?;   // the next cursor
  },
);
```

| Parameter | Default | Meaning |
|---|---|---|
| `read` | required | Called with the cursor the previous round returned; returns the next cursor. A null keeps the last one. |
| `since` | null | The cursor of the first round. |
| `interval` | 1 second | Wait between rounds. |
| `delay` | real clock | Replaceable wait, so a test runs the loop without a clock. |
| `shouldStop` | never | Asked after each read; the loop ends when it returns true. By default it ends only when the process does. |
