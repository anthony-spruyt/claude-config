# hookify-extended

Extended hookify plugin with rate-limited warnings and proper Claude message delivery.

## Why This Plugin?

The official hookify plugin has a bug ([#12446](https://github.com/anthropics/claude-code/issues/12446)) where block/warning messages don't reach Claude - only the user sees them. This means Claude doesn't know why a command was blocked.

This plugin fixes the issue by using `stderr` + exit code `2` instead of `stdout` + exit code `0`.

## Features

- **Fix #12446** - Messages reach Claude via stderr
- **Rate-limited warnings** - `warn_once` and `warn_interval` fields
- **PPID-scoped state** - Subagents get independent warning state

## Rate Limiting

Add optional fields to your hookify rules:

```yaml
---
name: warn-use-glob-tool
event: bash
pattern: (^|\s)(find|ls)\s+\S
action: warn
warn_once: true # Only warn once per session
warn_interval: 5 # OR: warn every N matches
---
```

| Field           | Type | Default | Description                           |
| --------------- | ---- | ------- | ------------------------------------- |
| `warn_once`     | bool | false   | Only warn once per agent session      |
| `warn_interval` | int  | 0       | Warn every N matches (0 = every time) |

## State Storage

State is stored in `/tmp/claude-hookify-state-{ppid}.json`:

- PPID-based scoping ensures main agent and subagents have independent state
- 24h TTL with auto-cleanup on startup

## Installation

Add to `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "hookify-extended-local": {
      "source": {
        "source": "directory",
        "path": ".claude/plugins/hookify-extended"
      }
    }
  },
  "enabledPlugins": {
    "hookify-extended@hookify-extended-local": true,
    "hookify@claude-plugins-official": false
  }
}
```
