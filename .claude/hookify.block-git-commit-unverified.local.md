---
name: block-git-commit-unverified
enabled: true
event: bash
pattern: (^|[;&|]\s*)git\s+commit\s+-
action: block
---

**BLOCKED: Unverified commit attempt.**

**Before committing, verify ALL of the following:**

1. **Issue exists?** Run `gh issue list --search "keyword"` or create with `gh issue create`
2. **On feature branch?** Run `git branch --show-current` - must NOT be `main`
3. **Commit message includes `Ref #<issue>`?**
4. **Commit message includes `Co-Authored-By: Claude <Model> <noreply@anthropic.com>`?**

**After verifying, use `command git` to bypass:**

```bash
# Direct commit:
command git commit -m "$(cat <<'EOF'
<type>(<scope>): <description>

Ref #<issue-number>

Co-Authored-By: Claude <Model> <noreply@anthropic.com>
EOF
)"

# Chained with add:
git add . && command git commit -m "..."
```

The `command` prefix bypasses this block. Do NOT use it without completing verification first.
