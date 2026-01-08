---
name: warn-git-commit
enabled: true
event: bash
pattern: git\s+commit
action: warn
---

**Before committing, verify you followed the workflow:**

**Commit Format** (conventional commits):

```
<type>(<scope>): <description>

Ref #<issue-number>

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

**Valid types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`, `build`

**Workflow Checklist:**

- [ ] Issue exists or was created first
- [ ] Commit references issue: `Ref #123`
- [ ] On a feature branch (**main is protected - cannot push directly**)
- [ ] Will create PR after push

See: `.claude/rules/workflow.md` and `.claude/rules/common-conventional-commits-and-naming.md`
