# Persistent Claude Code Memory Across Ephemeral Environments

**Date:** 2026-05-12 **Status:** Draft **Author:** Claude Code + Anthony Spruyt

## Problem

Claude Code's auto-memory system writes to `~/.claude/projects/<project>/memory/` by default. The `autoMemoryDirectory` setting redirects this but only works from user-level settings (`~/.claude/settings.json`), not project settings.

In ephemeral environments (Coder workspaces, agent pods), `~/.claude/` is destroyed on rebuild. Memory is lost. Agents in the cluster never get memory at all.

Each repo needs its own persistent memory, shared across all environments working on that repo.

## Constraints

- `autoMemoryDirectory` must be in `~/.claude/settings.json` (user-level). Claude Code rejects it from project `.claude/settings.json` for security.
- `autoMemoryDirectory` does NOT support `<project>` placeholder. Only concrete absolute paths work (verified 2026-05-12).
- Coder workspaces and agent pods are ephemeral — `~/.claude/` is nuked on rebuild/termination.
- Local devcontainers bind-mount `~/.claude/` from host — persists across rebuilds.
- Agent pods use init containers + Kyverno (no entrypoint modification possible).
- One repo per agent pod (multi-repo agents are out of scope; if needed later, requires separate design).

## Prerequisites

- **Memory repo** `anthony-spruyt/claude-memory` must be created before first use (see [Initial Setup](#initial-setup)).
- **SSH agent forwarding** must be configured in all environments for git push/pull to memory repo:
  - Local devcontainer: SSH agent socket bind-mounted from host (already in devcontainer.json)
  - Coder workspace: SSH agent forwarded via Coder's built-in mechanism
  - Agent pods: Git credentials injected via init container or Kyverno (same mechanism used for repo clone)
- **`jq`** must be installed in all container images (devcontainer-common and agent image).

## Environments

| Environment        | Workspace path            | `~/.claude/`           | Bootstrap hook             | Bootstrap `$PWD`                                                      |
| ------------------ | ------------------------- | ---------------------- | -------------------------- | --------------------------------------------------------------------- |
| Local devcontainer | `/workspaces/<repo>`      | Bind-mounted from host | `devcontainer-post-create` | Workspace root (set by `cd ${containerWorkspaceFolder}`)              |
| Coder workspace    | `/workspaces/<repo>`      | Ephemeral              | `devcontainer-post-create` | Workspace root (set by `cd ${containerWorkspaceFolder}`)              |
| Agent pod          | `/workspaces/repo/<repo>` | Ephemeral              | Init container             | Passed as argument: `claude-memory-bootstrap /workspaces/repo/<repo>` |

## Solution

Dedicated private memory repo (`anthony-spruyt/claude-memory`) + bootstrap script baked into container images + auto-sync script called from Claude Code PostToolUse hook.

### Architecture

```text
                   ┌─────────────────────┐
                   │  claude-memory repo  │
                   │  (private, GitHub)   │
                   └──────────┬──────────┘
                              │ git clone/pull/push
              ┌───────────────┼───────────────┐
              │               │               │
     ┌────────▼──────┐ ┌─────▼───────┐ ┌─────▼───────┐
     │  Devcontainer  │ │    Coder    │ │  Agent Pod  │
     │                │ │  Workspace  │ │             │
     │ ~/.claude-     │ │ ~/.claude-  │ │ ~/.claude-  │
     │   memory/      │ │   memory/   │ │   memory/   │
     │   <repo>/      │ │   <repo>/   │ │   <repo>/   │
     └────────────────┘ └─────────────┘ └─────────────┘
```

### Memory Repo Structure

```text
anthony-spruyt/claude-memory (private)
├── .gitattributes
├── claude-config/
│   ├── MEMORY.md           # Index only (links to topic files)
│   └── feedback_commit_push.md
├── spruyt-labs/
│   ├── MEMORY.md
│   └── ...
├── repo-operator/
│   └── MEMORY.md
└── <any-repo>/
    └── ...
```

**Conflict mitigation:** Claude memory format uses one file per topic with a flat MEMORY.md index. Concurrent writes to different topic files never conflict. MEMORY.md index conflicts (two envs adding a line simultaneously) are the only realistic conflict scenario — resolved by preferring the local version and re-adding the missing entry on the next memory write.

`.gitattributes`:

```gitattributes
MEMORY.md merge=ours
```

Only MEMORY.md index gets `merge=ours`. Topic files are one-per-entry so conflicts are rare. If a topic file does conflict, git's default 3-way merge handles it better than blanket `ours`.

### Components

#### 1. Bootstrap Script — `claude-memory-bootstrap`

**Location:** `/usr/local/bin/claude-memory-bootstrap` in both `devcontainer-common` and agent images (built from `container-images` repo).

**Responsibility:** Clone/pull memory repo, set `autoMemoryDirectory` in user settings.

**Usage:**

```bash
claude-memory-bootstrap              # detect repo from $PWD
claude-memory-bootstrap /path/to/repo  # explicit workspace path (for init containers)
```

```bash
#!/bin/bash
set -euo pipefail

MEMORY_REPO="${CLAUDE_MEMORY_REPO:-git@github.com:anthony-spruyt/claude-memory.git}"
MEMORY_DIR="${CLAUDE_MEMORY_DIR:-$HOME/.claude-memory}"
LOG_FILE="$HOME/.claude/memory-sync.log"

log() { echo "[$(date -Iseconds)] $*" >> "$LOG_FILE" 2>/dev/null || true; }

# Require jq
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed." >&2
  log "FATAL: jq not found"
  exit 1
fi

# Workspace path: argument or $PWD
WORKSPACE="${1:-$PWD}"

# Detect repo name: owner/repo from git remote, fallback to basename
detect_repo_name() {
  local url
  if url=$(git -C "$WORKSPACE" remote get-url origin 2>/dev/null); then
    # Extract owner/repo from SSH or HTTPS URL
    # git@github.com:owner/repo.git -> owner/repo
    # https://github.com/owner/repo.git -> owner/repo
    echo "$url" | sed -E 's#.*[:/]([^/]+/[^/]+?)(\.git)?$#\1#'
  else
    basename "$WORKSPACE"
  fi
}

REPO_NAME=$(detect_repo_name)

# Clone or pull memory repo
if [ -d "$MEMORY_DIR/.git" ]; then
  log "Pulling memory repo"
  if ! git -C "$MEMORY_DIR" pull --rebase --quiet 2>>"$LOG_FILE"; then
    log "WARNING: pull --rebase failed, resetting to origin/main"
    git -C "$MEMORY_DIR" fetch --quiet 2>>"$LOG_FILE" || true
    git -C "$MEMORY_DIR" reset --hard origin/main 2>>"$LOG_FILE" || true
  fi
else
  log "Cloning memory repo"
  if ! git clone --quiet "$MEMORY_REPO" "$MEMORY_DIR" 2>>"$LOG_FILE"; then
    log "FATAL: Failed to clone memory repo"
    echo "WARNING: Failed to clone memory repo. Memory will not persist." >&2
    exit 0
  fi
fi

# Verify HEAD is on a branch (not detached)
if ! git -C "$MEMORY_DIR" symbolic-ref HEAD &>/dev/null; then
  log "WARNING: detached HEAD, checking out main"
  git -C "$MEMORY_DIR" checkout main 2>>"$LOG_FILE" || true
fi

# Ensure project subdir exists with MEMORY.md stub
mkdir -p "$MEMORY_DIR/$REPO_NAME"
if [ ! -f "$MEMORY_DIR/$REPO_NAME/MEMORY.md" ]; then
  touch "$MEMORY_DIR/$REPO_NAME/MEMORY.md"
fi

# Write autoMemoryDirectory to user settings (merge, don't overwrite)
SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$SETTINGS")"

TARGET_DIR="$MEMORY_DIR/$REPO_NAME"

if [ -f "$SETTINGS" ]; then
  tmp=$(mktemp)
  if jq --arg dir "$TARGET_DIR" '.autoMemoryDirectory = $dir' "$SETTINGS" > "$tmp" 2>>"$LOG_FILE"; then
    mv "$tmp" "$SETTINGS"
  else
    log "WARNING: jq merge failed, overwriting settings"
    rm -f "$tmp"
    printf '{"autoMemoryDirectory": "%s"}\n' "$TARGET_DIR" > "$SETTINGS"
  fi
else
  printf '{"autoMemoryDirectory": "%s"}\n' "$TARGET_DIR" > "$SETTINGS"
fi

log "Memory configured: $TARGET_DIR (repo: $REPO_NAME)"
echo "Claude memory configured: $TARGET_DIR"
```

**Environment variable overrides:**

| Variable             | Default                                           | Purpose          |
| -------------------- | ------------------------------------------------- | ---------------- |
| `CLAUDE_MEMORY_REPO` | `git@github.com:anthony-spruyt/claude-memory.git` | Memory repo URL  |
| `CLAUDE_MEMORY_DIR`  | `$HOME/.claude-memory`                            | Local clone path |

#### 2. Auto-Sync Script — `claude-memory-sync`

**Location:** `/usr/local/bin/claude-memory-sync` in both container images (alongside bootstrap).

**Responsibility:** After memory file writes, commit and push changes to memory repo.

Extracted to a script (not inline in settings.json) for testability and readability.

```bash
#!/bin/bash
set -euo pipefail

MEMORY_DIR="${CLAUDE_MEMORY_DIR:-$HOME/.claude-memory}"
LOG_FILE="$HOME/.claude/memory-sync.log"

log() { echo "[$(date -Iseconds)] $*" >> "$LOG_FILE" 2>/dev/null || true; }

# Read tool input from stdin (Claude Code PostToolUse passes JSON)
file_path=$(jq -r '.tool_input.file_path // empty' 2>/dev/null < /dev/stdin) || true

# Only act on writes inside memory dir
case "$file_path" in
  "$MEMORY_DIR"/*)
    log "Syncing memory: $file_path"
    ;;
  *)
    exit 0
    ;;
esac

cd "$MEMORY_DIR" || exit 0

# Detect repo name for commit message
repo_name=$(basename "$(git -C "$PWD" remote get-url origin 2>/dev/null)" .git 2>/dev/null || echo "unknown")

# Stash local changes
git stash --quiet 2>>"$LOG_FILE" || true

# Pull latest
if ! git pull --rebase --quiet 2>>"$LOG_FILE"; then
  log "WARNING: rebase failed, resetting to origin/main and re-applying"
  git rebase --abort 2>/dev/null || true
  git fetch --quiet 2>>"$LOG_FILE" || true
  git reset --hard origin/main 2>>"$LOG_FILE" || true
fi

# Reapply local changes
if git stash list 2>/dev/null | grep -q .; then
  if ! git stash pop --quiet 2>>"$LOG_FILE"; then
    log "WARNING: stash pop conflict, keeping local version"
    git checkout --ours . 2>>"$LOG_FILE" || true
    git add . 2>>"$LOG_FILE" || true
    git stash drop --quiet 2>>"$LOG_FILE" || true
  fi
fi

# Commit and push
git add . 2>>"$LOG_FILE" || true
if ! git diff --cached --quiet 2>/dev/null; then
  git commit -m "auto: update memory" --quiet 2>>"$LOG_FILE" || true
  if ! git push --quiet 2>>"$LOG_FILE"; then
    log "WARNING: push failed, will retry on next write"
  else
    log "Pushed memory update"
  fi
else
  log "No changes to push"
fi
```

#### 3. Hook Definition — PostToolUse in `settings.json`

**Location:** `.claude/settings.json` in claude-config (synced to all repos).

The hook calls the extracted script:

```json
{
  "matcher": "Edit|Write",
  "hooks": [
    {
      "type": "command",
      "command": "claude-memory-sync"
    }
  ]
}
```

Claude Code pipes tool input JSON to stdin. The script reads it, checks if the file is inside the memory dir, and syncs if so.

#### 4. Integration Points

| Repo                 | File                                           | Change                                                                    |
| -------------------- | ---------------------------------------------- | ------------------------------------------------------------------------- |
| **container-images** | `devcontainer-common/Dockerfile`               | Add `claude-memory-bootstrap` + `claude-memory-sync` to `/usr/local/bin/` |
| **container-images** | `devcontainer-common/devcontainer-post-create` | Add `claude-memory-bootstrap` call after Claude CLI install               |
| **container-images** | `agent-image/Dockerfile`                       | Add `claude-memory-bootstrap` + `claude-memory-sync` to `/usr/local/bin/` |
| **spruyt-labs**      | Kyverno policy or init container spec          | Call `claude-memory-bootstrap /workspaces/repo/<repo>`                    |
| **claude-config**    | `.claude/settings.json`                        | Add PostToolUse hook calling `claude-memory-sync`                         |

### Local Devcontainer Handling

Local devcontainers bind-mount `~/.claude/` from host. The bootstrap script still works:

- If `~/.claude-memory/` already exists on host (cloned previously), bootstrap does `git pull`
- If not, bootstrap clones fresh
- `autoMemoryDirectory` written to `~/.claude/settings.json` (persists on host via bind-mount)
- After first run, subsequent rebuilds skip clone (already on host)

Note: host home directory must be writable. If host home is read-only (NFS, CI runner), bootstrap logs a warning and memory falls back to default (non-persistent).

### Initial Setup

Before any environment can use persistent memory:

1. Create the memory repo:

   ```bash
   gh repo create anthony-spruyt/claude-memory --private --description "Claude Code persistent memory"
   cd $(mktemp -d)
   git init && git remote add origin git@github.com:anthony-spruyt/claude-memory.git
   echo "MEMORY.md merge=ours" > .gitattributes
   git add . && git commit -m "init: memory repo with merge strategy"
   git push -u origin main
   ```

1. Migrate existing memory:

   ```bash
   # From default path
   mkdir -p claude-config
   cp ~/.claude/projects/-workspaces-claude-config/memory/* claude-config/
   # Repeat for other repos with existing memory
   git add . && git commit -m "migrate: existing memory files"
   git push
   ```

1. Deploy bootstrap script + sync script to container images (container-images repo).

1. Add PostToolUse hook to claude-config settings.json.

1. Rebuild environments to pick up changes.

### Edge Cases

| Case                                       | Handling                                                                                                                             |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| No git access (broken token/key)           | Bootstrap warns, exits 0. Sync script exits 0. Memory falls back to default (non-persistent). Logged to `~/.claude/memory-sync.log`. |
| Concurrent writes to different topic files | No conflict — one file per topic. Push succeeds.                                                                                     |
| Concurrent writes to MEMORY.md index       | `merge=ours` keeps local version. Missing index entry re-added on next memory write by Claude Code.                                  |
| Rebase failure (corrupted state)           | Bootstrap and sync both reset to `origin/main` and re-apply. Logged.                                                                 |
| Detached HEAD                              | Bootstrap detects and checks out main.                                                                                               |
| Agent pod killed mid-push                  | That single write lost. Previous pushes safe. Logged (if log write completes).                                                       |
| Memory repo doesn't exist yet              | Bootstrap fails gracefully (exit 0), warns on stderr. See [Initial Setup](#initial-setup).                                           |
| New repo (no subdir in memory repo)        | Bootstrap creates subdir + empty `MEMORY.md`.                                                                                        |
| Sync script fails                          | Logged to `~/.claude/memory-sync.log`. Memory saved locally, pushed on next successful sync (`git add .` catches up).                |
| `jq` not available                         | Bootstrap exits 1 with clear error. Sync script silently skips (reads empty file_path, exits). Images MUST include `jq`.             |
| Host home read-only (local devcontainer)   | Clone fails, bootstrap warns and exits 0. Memory non-persistent.                                                                     |

### Security Considerations

- Memory repo is private (GitHub access control).
- Bootstrap uses SSH (`git@github.com:...`) — requires SSH agent forwarding (see [Prerequisites](#prerequisites)).
- Agent pods need git credentials injected via init container or Kyverno (same mechanism used for repo clone).
- No secrets stored in memory files (Claude Code's deny rules prevent reading secrets, so they shouldn't end up in memory).
- Auto-sync hook only fires after Claude writes to memory dir, not on arbitrary paths (path checked in script).
- Sync script reads stdin from Claude Code (tool input JSON). Uses `jq` with no shell expansion — no injection risk.

### Testing

- **Bootstrap script:** Unit test with bats — mock git clone, verify settings.json written correctly, verify repo name detection for SSH/HTTPS URLs, verify `jq` requirement enforced.
- **Auto-sync script:** Unit test with bats — mock git operations, verify only memory dir writes trigger sync, verify stash/pull/push flow.
- **Integration test:** Write to memory dir, verify commit+push happens, verify log file populated.
- **Conflict resolution:** Test concurrent writes from two environments, verify no data loss on topic files, verify MEMORY.md index recovers.
- **Failure modes:** Test with no git access, no `jq`, read-only home — verify graceful degradation and logging.
- **Repo name detection:** Test with `git@github.com:owner/repo.git`, `https://github.com/owner/repo.git`, and fallback to `basename $PWD`.

### Environment Variables

Both container images must have `jq` installed. Environment variables are optional — defaults work for all current environments.

| Variable             | Default                                           | Set in                       |
| -------------------- | ------------------------------------------------- | ---------------------------- |
| `CLAUDE_MEMORY_REPO` | `git@github.com:anthony-spruyt/claude-memory.git` | Image build or container env |
| `CLAUDE_MEMORY_DIR`  | `$HOME/.claude-memory`                            | Image build or container env |

### Future Considerations

- If `autoMemoryDirectory` gains `<project>` placeholder support, bootstrap simplifies (one static path, no per-repo detection)
- Memory repo could gain CI that validates memory format (frontmatter, MEMORY.md index consistency)
- Could add memory pruning (TTL on stale entries) via scheduled agent
- Multi-repo agent pods would need a different memory path strategy (mount multiple subdirs or use a shared flat dir)
