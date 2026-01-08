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

```bash
# Sync config to a target repository
./sync-to-repo.sh USER/target-repo

# Optionally specify source repo and branch
./sync-to-repo.sh USER/target-repo USER/claude-config main
```

**Note:** GitHub Actions automatically syncs `.claude/**` changes to all repositories where the GitHub App is installed when changes are pushed to `main`.

## Architecture

### Security Layers

This repository implements defense-in-depth with multiple security layers:

1. **File Permissions** ([.claude/settings.json](.claude/settings.json)) - Denies Claude Code access to sensitive files (SSH keys, certificates, cloud credentials, environment files, SOPS encrypted files, tokens/secrets)

2. **Command Blocking** ([.claude/settings.json](.claude/settings.json)) - Prevents executing commands that could expose secrets (base64 decode, sops/gpg decrypt, printenv, openssl decryption)

3. **Hookify Rules** (`.claude/hookify.common-*.local.md`) - Event-based workflow automation and safety controls for Kubernetes operations, secret management, environment access, and workflow confirmation

**Complete list:** See [.claude/settings.json](.claude/settings.json) for file/command patterns and `.claude/hookify.common-*.local.md` files for active rules. All security layers are validated by automated tests in `tests/security/` and `tests/hooks/`.

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

### Configuration Components

- **[.claude/settings.json](.claude/settings.json)** - Core configuration:
  - Permission denials for sensitive files/commands
  - PostToolUse hooks (auto-format with Prettier after edits)
  - Enabled plugins: context7, security-guidance, feature-dev, code-review, hookify

- **`.claude/hookify.common-*.local.md`** - Shared hookify rules (synced from central config)
- **`.claude/rules/common-*.md`** - Shared Claude Code rules (synced from central config)
- **`.claude/agents/common-*.md`** - Shared agents (synced from central config)

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
| `settings.json`                          | Central (always synced) | Always overwritten                      |

**Important:** The sync script only manages files with the `common-` prefix. Repo-specific files (without the prefix) are never modified or deleted by sync.

## Testing

Uses **bats-core** for testing. Run: `./test.sh`

- `tests/security/` - File permissions, command blocks (bats + Python pathspec)
- `tests/hooks/` - Hookify rules (data-driven YAML + actual hookify engine)
- `tests/unit/` - Shell script validation (bats)

**Hookify tests:** Add test cases to [tests/hooks/hookify_test_cases.yaml](tests/hooks/hookify_test_cases.yaml) with expected outcome (block/warn/allow). Tests use the actual hookify Python implementation from `anthropics/claude-plugins-official`.

**Python dependencies** (installed by devcontainer/CI): `pathspec`, `pyyaml`

## Linting & CI/CD

### MegaLinter

Configuration: [.mega-linter.yml](.mega-linter.yml). Run locally with `./lint.sh`. Output goes to `.output/` (check `*-ERROR.log` files on failure).

### GitHub Actions

- [test.yaml](.github/workflows/test.yaml) - Test suite on push/PR
- [lint.yaml](.github/workflows/lint.yaml) - MegaLinter on push/PR
- [sync-to-repos.yaml](.github/workflows/sync-to-repos.yaml) - Auto-syncs `.claude/` to target repos

### Dependabot

See [.github/dependabot.yml](.github/dependabot.yml) for auto-updates (Actions, npm, devcontainer).

## Devcontainer

See [DEVELOPMENT.md](DEVELOPMENT.md) for devcontainer setup and SSH agent configuration.
