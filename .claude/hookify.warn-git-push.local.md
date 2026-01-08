---
name: warn-git-push
enabled: true
event: bash
pattern: git\s+push
action: warn
---

**After pushing to a PR, follow this workflow:**

1. **Check CI status:** `gh pr checks <pr-number> --watch`

2. **If CI passes:**
   - Squash merge: `gh pr merge <pr-number> --squash --delete-branch`
   - Switch to main: `git checkout main && git pull`
   - Check CI on main: `gh run list --branch main --limit 1`

3. **If CI fails:**
   - Check logs: `gh run view <run-id> --log-failed`
   - Fix the issue and push again

**Do not leave PRs unmerged after CI passes.**
