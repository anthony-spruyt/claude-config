# claude-config (ARCHIVED)

> **This repository has been archived.** Its content has been migrated to:
>
> - **Hookify rules** → [claude-plugins](https://github.com/anthony-spruyt/claude-plugins) (hookify-plus + security-hooks + best-practices plugins)
> - **Settings + rules distribution** → [repo-operator](https://github.com/anthony-spruyt/repo-operator) (xfg `claude` group)
> - **Infrastructure rules** → [spruyt-labs](https://github.com/anthony-spruyt/spruyt-labs) (`.claude/hookify-plus/`)

## Migration Guide

### For users of this repo's sync

1. Remove the GitHub App from your repos (if still installed)
1. Install plugins: `/plugin marketplace add anthony-spruyt/claude-plugins`
1. Enable: `hookify-plus`, `security-hooks`, `best-practices`
1. Old `hookify.*.local.md` files in `.claude/` can be deleted — the new engine ignores them

### For repo-operator managed repos

Settings and rules are now delivered via the `claude` xfg group. No action needed — next sync cycle handles it.
