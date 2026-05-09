---
name: block-env-dump
enabled: true
event: bash
# Lookahead: allow pipe to cut -d= -f1 (keys only) or wc (count only).
# -f1 boundary: ([^\S\n]|\||$) ensures -f10, -f1,2, -f1-2 stay blocked; allows pipe directly after -f1.
# Flags: (-0|--null|--zero|--) still dump all vars, so block them too.
pattern: (^|\s|&&|\|\||;|\(|`)env([^\S\n]+(-0|--null|--zero|--))*[^\S\n]*($|;|&&|\|\||\)|`|\|[^\S\n]*(?![^\S\n]*(cut[^\S\n]+-d=[^\S\n]+-f1([^\S\n]|\||$)|wc([^\S\n]|$))))
action: block
---

🚫 **Blocked: Dumping environment variables**

**What was blocked:** `env` command (shows all environment variables with values)

**Why:** Environment variables often contain secrets, tokens, and credentials.

**If you need a specific variable:**

1. Ask the user: "What is the value of `$VARIABLE_NAME`?"
2. User can provide the value if it's safe to share

**Safe alternatives:**

- List variable names only: `env | cut -d= -f1`
- Check if variable exists: `[ -n "$VAR" ] && echo "set"`
- Get specific non-secret var: `echo $PATH`

**False positive?** Open an issue: `gh issue create --repo anthony-spruyt/claude-config --title "False positive: block-env-dump" --label bug` and describe the blocked command in the body using `--body-file` to avoid re-triggering hooks.
