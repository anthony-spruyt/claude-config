# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a **centralized Claude Code configuration repository** that uses a hub-and-spoke model to distribute security-focused configurations across multiple repositories. It provides:

- Security rules preventing accidental secret exposure
- Permission controls blocking access to sensitive files
- Standardized development environment via devcontainer
- Automated synchronization to all repositories where a GitHub App is installed

## Common Commands

### Development

```bash
# Run MegaLinter locally (auto-fixes enabled)
./lint.sh

# Check linting failures efficiently (exit code first, then details if needed)
./lint.sh || cat .output/linters_logs/*-ERROR.log

# Run test suite
./test.sh

# Run specific test suites
bats tests/security/  # File permissions, command blocks
bats tests/hooks/     # Hookify rules validation
bats tests/unit/      # Shell script tests
```

### Configuration Sync

Syncing is automated via GitHub Actions. To manually trigger a sync:

```bash
# Sync to all repos with the GitHub App installed
gh workflow run "Sync to Target Repos"

# Sync to specific repos only
gh workflow run "Sync to Target Repos" -f target_repos="owner/repo1,owner/repo2"
```

**Note:** GitHub Actions automatically syncs `.claude/**` changes to all repositories where the GitHub App is installed when changes are pushed to `main`.

## Architecture

### Security Layers

This repository implements defense-in-depth with multiple security layers:

1. **File Permissions** ([.claude/settings.json](.claude/settings.json)) - Denies Claude Code access to sensitive files (SSH keys, certificates, cloud credentials, environment files, SOPS encrypted files, tokens/secrets)

2. **Command Blocking** ([.claude/settings.json](.claude/settings.json)) - Prevents executing commands that could expose secrets (base64 decode, sops/gpg decrypt, printenv, openssl decryption)

3. **Hookify Rules** (`.claude/hookify.common-*.local.md`) - Event-based workflow automation and safety controls for Kubernetes operations, secret management, environment access, and workflow confirmation

4. **Hookify-Plus Plugin** ([anthony-spruyt/hookify-plus](https://github.com/anthony-spruyt/hookify-plus)) - Extended hookify that fixes [#12446](https://github.com/anthropics/claude-code/issues/12446) and adds rate-limited warnings

**Complete list:** See [.claude/settings.json](.claude/settings.json) for file/command patterns and `.claude/hookify.common-*.local.md` files for active rules. All security layers are validated by automated tests in `tests/security/` and `tests/hooks/`.

### Hookify-Plus Plugin

The official hookify plugin has a bug ([#12446](https://github.com/anthropics/claude-code/issues/12446)) where messages don't reach Claude. We use [hookify-plus](https://github.com/anthony-spruyt/hookify-plus) with fixes:

**Installation:**

1. `/plugin` → Add plugin → `anthony-spruyt/hookify-plus`
2. Restart Claude Code
3. Hooks will fire on tool use

**Features:**

1. **Fix #12446** - Messages reach Claude via stderr + exit 2 (not stdout + exit 0)
2. **Rate-limited warnings** - `warn_once` and `warn_interval` fields to reduce context waste
3. **Per-subagent state** - State resets when Task tool spawns subagents

**Rate limiting fields:**

```yaml
---
name: warn-use-glob-tool
enabled: true
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

**State storage:** `/tmp/claude-hookify-state-{session_id[:12]}.json` with 24h TTL.

### Pattern Matching Reference

**IMPORTANT:** Claude Code uses two different pattern matching systems:

#### 1. Permissions (settings.json) - Gitignore Patterns

The `Read()`, `Edit()`, and `Bash()` rules in `permissions.deny` and `permissions.allow` use **[gitignore pattern syntax](https://git-scm.com/docs/gitignore)**:

| Pattern | Meaning                            | Example                                           |
| ------- | ---------------------------------- | ------------------------------------------------- |
| `*`     | Matches anything **except** `/`    | `*.pem` matches `cert.pem` but NOT `dir/cert.pem` |
| `**`    | Matches anything **including** `/` | `./**/*.pem` matches `dir/sub/cert.pem`           |
| `~/`    | Home directory (`$HOME`)           | `~/.ssh/*` matches `$HOME/.ssh/id_rsa`            |
| `./`    | Relative to working directory      | `./**/.env` matches `config/.env`                 |
| `//`    | Absolute filesystem path           | `//etc/passwd`                                    |

**Common mistakes:**

- Using `*` when you need `**` for recursive matching
- Forgetting that `./**/` only applies to the working directory, not `/tmp/` or other paths
- Using `/path` (relative to settings file) instead of `//path` (absolute)

#### 2. Hookify Rules - Python/PCRE Regex

The `pattern:` field in hookify rules uses **Python-compatible regular expressions (PCRE)**:

```yaml
pattern: kubectl\s+describe\s+secrets?
```

Common regex features:

- `\s+` - one or more whitespace
- `\S+` - one or more non-whitespace
- `.*` - any characters (greedy)
- `(a|b)` - alternation
- `secrets?` - optional character

#### 3. Deny vs Allow Precedence

**Critical:** `deny` rules are evaluated differently than `allow`:

- **Deny wins over allow** - If a path matches both, it's denied
- **More specific patterns don't override deny** - A deny on `*.env` cannot be overridden by allowing `test.env`
- **Deny patterns must be exact** - Common mistake: adding `Read(.env)` without `./` prefix won't work

If your deny rules aren't working:

1. Check you're using the correct prefix (`./**/`, `~/`, `//`)
2. Verify glob vs regex syntax (permissions use globs, hooks use regex)
3. Test with the actual path Claude Code would use

### Distribution Model

**Central Source of Truth:**

- This repository contains the canonical `.claude/` configuration
- Changes to `.claude/**` trigger automatic synchronization

**Automated Distribution:**

1. Changes pushed to `main` branch
2. GitHub Actions workflow ([.github/workflows/sync-to-repos.yaml](.github/workflows/sync-to-repos.yaml)) triggers
3. Workflow queries GitHub App installations to find target repositories
4. For each target repo:
   - Clones both config and target repos
   - Syncs only `common-` prefixed files (preserves repo-specific config)
   - Uses fixed branch `chore/update-claude-config` (one PR per repo)
   - Opens or updates PR with changelog and review checklist

**Webhook Automation (Optional):**

When new repositories install the GitHub App, automatically trigger sync via n8n webhook:

- GitHub App webhook → n8n workflow → GitHub Actions workflow_dispatch
- See [.n8n/README.md](.n8n/README.md) for n8n workflow template and setup instructions
- Alternative: Manually trigger via GitHub UI (Actions → Sync to Target Repos → Run workflow)

**Dashboard Issue (On-Demand Sync):**

Each target repository gets a dashboard issue (`🔄 Claude Config Sync Dashboard`) that allows on-demand sync:

- Created automatically on first sync
- Contains a "Request sync now" checkbox
- Checking the box triggers a single-repo sync via n8n webhook
- Shows sync status, config version, and any exclusions

Sync modes:

| Trigger            | Mode         | Behavior                                                    |
| ------------------ | ------------ | ----------------------------------------------------------- |
| Push to `main`     | All-repos    | Syncs to all installations                                  |
| New installation   | Single-repo  | Syncs only newly added repos                                |
| Dashboard checkbox | Single-repo  | Syncs only the requesting repo                              |
| Manual dispatch    | Configurable | Pass `target_repos` input for single-repo, or empty for all |

### Sync Opt-Out (Target Repos)

Target repositories can opt out of specific synced files by adding `.claude/.sync-config.yaml`:

```yaml
# Opt out of entire categories
exclude_categories:
  - commands # Don't sync common-*.md commands
  - agents # Don't sync common-*.md agents

# Opt out of specific files (basename match)
exclude_files:
  - "hookify.common-block-kubectl-describe-secrets.local.md"
  - "common-tdd.md"
```

**Available categories:** `settings`, `hookify`, `agents`, `rules`, `hooks`, `lib`, `plugins`, `commands`

**How it works:**

1. Sync script clones target repo
2. Checks for `.claude/.sync-config.yaml`
3. Skips excluded categories/files during sync
4. Excluded files are not deleted if they already exist

**Note:** Requires `yq` (YAML parser) on the sync runner. If `yq` is unavailable, exclusions are ignored and all files sync normally.

### Configuration Components

- **[.claude/settings.json](.claude/settings.json)** - Core configuration:
  - Permission denials for sensitive files/commands
  - PreToolUse/PostToolUse hooks (hookify-plus plugin from GitHub)
  - PostToolUse hooks (auto-format with Prettier after edits)
  - Enabled plugins: context7, security-guidance, feature-dev, hookify-plus

- **`.claude/hookify.common-*.local.md`** - Shared hookify rules (synced from central config)
- **`.claude/rules/common-*.md`** - Shared Claude Code rules (synced from central config)
- **`.claude/agents/common-*.md`** - Shared agents (synced from central config)
- **`.claude/commands/common-*.md`** - Shared slash commands (synced from central config)

### Slash Commands

Commands are user-invocable workflows in `.claude/commands/`. Invoke with `/command-name` or `/command-name arguments`.

**Command file format:**

```yaml
---
description: What the command does
allowed-tools: Read, Glob, Grep, Bash(git:*), Bash(gh:*)
---
# Title

Instructions with $ARGUMENTS placeholder for user input.
```

**Note:** The command name is derived from the filename (e.g., `common-debug.md` → `/common-debug`).

### Structured Agents

Agents are specialized assistants in `.claude/agents/`. They can be referenced directly or invoked by other agents.

| Agent            | Model  | Description                                                                          |
| ---------------- | ------ | ------------------------------------------------------------------------------------ |
| `code-reviewer`  | opus   | Code quality review using [Conventional Comments](https://conventionalcomments.org/) |
| `debugging`      | sonnet | Systematic debugging with scientific method                                          |
| `git-workflow`   | sonnet | Git operations following project conventions                                         |
| `issue-workflow` | opus   | Creates/finds GitHub issues (does NOT implement work)                                |
| `merge-workflow` | sonnet | Merges PRs after checking approval, CI, conflicts                                    |

#### Agent Tool Restrictions

Agents can be restricted to specific tools using `allowed-tools` in frontmatter:

```yaml
---
name: issue-workflow
model: opus
allowed-tools: Bash(gh:*), Bash(ls:*), Bash(cat:*), Read
---
```

**Why this matters:** Without restrictions, agents have access to ALL tools and may perform unintended actions (e.g., deleting files when asked to "remove" something instead of creating an issue for removal).

#### Reloading Agent Changes

Agent `.md` file changes require a reload to take effect:

1. **During session:** Use `/reload` command (if available in your CLI version)
2. **Otherwise:** Exit and restart the session

Text instructions (like "NEVER delete files") are often ignored by agents. Use `allowed-tools` restrictions for enforcement.

### File Naming Convention

Files use a `common-` prefix to distinguish centrally-managed config from repo-specific config:

| Pattern                                  | Source                  | Example                                 |
| ---------------------------------------- | ----------------------- | --------------------------------------- |
| `hookify.common-*.local.md`              | Central (synced)        | `hookify.common-block-secrets.local.md` |
| `hookify.*.local.md` (without `common-`) | Repo-specific           | `hookify.my-project-rule.local.md`      |
| `agents/common-*.md`                     | Central (synced)        | `agents/common-security-agent.md`       |
| `agents/*.md` (without `common-`)        | Repo-specific           | `agents/my-project-agent.md`            |
| `rules/common-*.md`                      | Central (synced)        | `rules/common-code-style.md`            |
| `rules/*.md` (without `common-`)         | Repo-specific           | `rules/my-project-rules.md`             |
| `commands/common-*.md`                   | Central (synced)        | `commands/common-debug.md`              |
| `commands/*.md` (without `common-`)      | Repo-specific           | `commands/my-deploy.md`                 |
| `settings.json`                          | Central (always synced) | Always overwritten                      |

**Important:** The sync script only manages files with the `common-` prefix. Repo-specific files (without the prefix) are never modified or deleted by sync.

## Testing

Uses **bats-core** for testing. Run: `./test.sh`

- `tests/security/` - File permissions, command blocks (bats + Python pathspec)
- `tests/hooks/` - Hookify rules (data-driven YAML + actual hookify engine)
- `tests/unit/` - Shell script validation (bats)
- `tests/commands/` - Command file format validation (frontmatter, required fields)
- `tests/agents/` - Agent file format validation (frontmatter, model field)

**Hookify tests:** Add test cases to [tests/hooks/hookify_test_cases.yaml](tests/hooks/hookify_test_cases.yaml) with expected outcome (block/warn/allow). Tests use the installed hookify-plus plugin (install via `/plugin` → `anthony-spruyt/hookify-plus`).

**Python dependencies** (installed by devcontainer/CI): `pathspec`, `pyyaml`

## Linting & CI/CD

### MegaLinter

Configuration: [.mega-linter.yml](.mega-linter.yml). Run locally with `./lint.sh`. Output goes to `.output/` (check `*-ERROR.log` files on failure).

### GitHub Actions

- [ci.yaml](.github/workflows/ci.yaml) - Orchestrates lint, test, and sync jobs (uses repo-operator)
- [\_test.yaml](.github/workflows/_test.yaml) - Local reusable test workflow
- [sync-to-repos.yaml](.github/workflows/sync-to-repos.yaml) - Auto-syncs `.claude/` to target repos
- [trivy-scan.yaml](.github/workflows/trivy-scan.yaml) - Vulnerability scanning

### Dependabot

See [.github/dependabot.yml](.github/dependabot.yml) for auto-updates (Actions, npm, devcontainer).

## Devcontainer

See [DEVELOPMENT.md](DEVELOPMENT.md) for devcontainer setup and SSH agent configuration.
