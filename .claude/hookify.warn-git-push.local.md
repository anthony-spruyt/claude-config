---
name: warn-git-push
enabled: true
event: bash
pattern: git\s+push
action: warn
---

**After pushing to a PR, follow this workflow:**

1. **Check CI status:** `gh pr checks <pr-number> --watch`

2. **If ALL CI checks pass:**
   - Squash merge: `gh pr merge <pr-number> --squash --delete-branch`
   - Switch to main: `git checkout main && git pull`
   - **IMPORTANT: Verify ALL CI on main passes:**
     ```
     gh run list --branch main --limit 5
     gh run watch <run-id>  # Watch each workflow
     ```

3. **If CI fails:**
   - Check logs: `gh run view <run-id> --log-failed`
   - Fix the issue and push again

**Do not leave PRs unmerged after CI passes.**
