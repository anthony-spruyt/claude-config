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

3. **Hookify Rules** (`.claude/hookify.*.local.md`) - Event-based workflow automation and safety controls for Kubernetes operations, secret management, environment access, and workflow confirmation

**Complete list:** See [.claude/settings.json](.claude/settings.json) for file/command patterns and `.claude/hookify.*.local.md` files for active rules. All security layers are validated by automated tests in `tests/security/` and `tests/hooks/`.

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
   - Copies `.claude/*` to target repo
   - Creates a branch with timestamp
   - Commits changes
   - Opens PR with detailed changelog and review checklist

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

- **`.claude/hookify.*.local.md`** - Hookify rules
- **`.claude/rules/`** - Custom Claude Code rules
- **`.claude/agents/`** - Custom agents

## Testing

Uses **bats-core** for TDD testing of security controls and shell scripts. Run: `./test.sh`

**Adding tests:** Create `.bats` file in `tests/security/`, `tests/hooks/`, or `tests/unit/`, load helpers, write `@test` blocks. See existing files for patterns.

## Linting & CI/CD

### MegaLinter

Configuration: [.mega-linter.yml](.mega-linter.yml)

**Active Linters:**

- `ACTION_ACTIONLINT` - GitHub Actions validation
- `BASH_SHELLCHECK` - Shell script linting
- `MARKDOWN_MARKDOWNLINT` - Markdown formatting
- `REPOSITORY_GITLEAKS` - Secret detection
- `REPOSITORY_SECRETLINT` - Secret pattern scanning
- `REPOSITORY_TRIVY` - Security vulnerability scanning
- `SPELL_LYCHEE` - Link validation
- `YAML_YAMLLINT` - YAML syntax validation

Run locally with `./lint.sh` or via CI on push/PR.

**Output Location:**

MegaLinter outputs reports and logs to `.output/` in the repository root. This directory is:

- Created fresh on each run (removed and recreated)
- Mapped from the MegaLinter container's `/tmp/lint/.output` to the host
- Contains detailed linter reports, logs, and any auto-fixed files in `.output/updated_sources/`
- Ignored by git (in [.gitignore](.gitignore))

To check linting failures, inspect `.output/` after running [lint.sh](lint.sh).

### GitHub Actions

- **[.github/workflows/test.yaml](.github/workflows/test.yaml)** - Runs test suite on all pushes and PRs to main
- **[.github/workflows/lint.yaml](.github/workflows/lint.yaml)** - Runs MegaLinter on all pushes and PRs to main
- **[.github/workflows/sync-to-repos.yaml](.github/workflows/sync-to-repos.yaml)** - Auto-syncs `.claude/` changes to all repositories with the GitHub App installed

### Dependabot

Configuration: [.github/dependabot.yml](.github/dependabot.yml)

Automatically updates:

- Devcontainer features
- GitHub Actions versions
- NPM packages

## Devcontainer

The devcontainer ([.devcontainer/devcontainer.json](.devcontainer/devcontainer.json)) provides a standardized development environment with:

- **Base:** Ubuntu (jammy)
- **Features:** pre-commit, GitHub CLI, Docker-in-Docker, Node.js, Python
- **Mounts:** SSH agent, `.claude` config, `.gitconfig`
- **Extensions:** YAML, Git Graph, Prettier, Claude Code

**Setup Scripts:**

- [.devcontainer/post-create.sh](.devcontainer/post-create.sh) - Installs safe-chain, Claude Code CLI, pre-commit hooks, and bats-core testing framework
- [.devcontainer/verify-setup.sh](.devcontainer/verify-setup.sh) - Validates setup
