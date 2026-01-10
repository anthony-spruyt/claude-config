# Workflow Agents Test Plan

Manual testing checklist for the development workflow agents. Run after merging and clearing context.

## Prerequisites

- Fresh Claude Code session (`/clear`)
- On `main` branch with all changes merged

## Test 1: issue-workflow

**Goal:** Verify issue creation and "Next" guidance.

```
User: "Create an issue for adding a dark mode toggle"
```

**Expected:**

- Agent searches for existing issues first
- Creates issue with conventional title: `feat(ui): add dark mode toggle`
- Returns: `Created issue: #XX - feat(ui): add dark mode toggle`
- Returns: `Next: Implement the work, then use git-workflow for #XX`

## Test 2: Block Branch Without Issue

**Goal:** Verify branch creation is blocked without issue number.

```
User: "Create a branch called feat/dark-mode"
```

**Expected:**

- Hook blocks with message: "Branch name must include issue number"
- Suggests format: `feat/dark-mode-XX`

## Test 3: git-workflow State Awareness

**Goal:** Verify git-workflow finds existing branches/PRs.

```
User: "Commit this change for #XX" (use issue from Test 1)
```

**Expected:**

- Agent checks for existing branch: `git branch -r --list "origin/*/*-XX"`
- If none, creates: `feat/dark-mode-XX`
- Commits with `Ref #XX`
- Pushes to feature branch (NOT main)
- Creates PR with title including `(#XX)`
- Returns structured output with "Next: pr-review and/or qa-workflow if available"

## Test 4: Block PR Without Issue

**Goal:** Verify PR creation is blocked without issue reference.

```
User: "Create a PR with title 'Add dark mode'"
```

**Expected:**

- Hook blocks with message: "PR title must include issue reference"
- Suggests format: `feat(ui): add dark mode (#XX)`

## Test 5: git-workflow Existing PR

**Goal:** Verify git-workflow detects existing PR.

```
User: "Make another commit for #XX" (same issue)
```

**Expected:**

- Agent finds existing branch
- Agent finds existing PR
- Pushes to existing branch
- Reports "PR #YY updated via push" (not creating duplicate)

## Test 6: merge-workflow Checks

**Goal:** Verify merge-workflow refuses without approval/CI.

```
User: "Merge PR #YY"
```

**Expected (if not approved):**

- Agent checks PR state, approval, CI, conflicts
- Refuses with clear reason: "Changes requested" or "CI failing"
- Reports "Action Required: ..."

## Test 7: merge-workflow Success

**Goal:** Verify successful merge with cleanup.

```
User: "Merge PR #YY" (after approval + CI passes)
```

**Expected:**

- Squash merges with `--delete-branch`
- Verifies issue auto-closed
- Returns: "Next: Check for post-deploy agent if configured"

## Test 8: Workflow Chain

**Goal:** Verify full workflow with "Next" guidance.

Run through entire flow:

1. issue-workflow creates #123
2. (implement changes)
3. git-workflow commits for #123, creates PR #45
4. (pr-review if available)
5. merge-workflow merges #45
6. (post-deploy if available)

**Verify:** Each agent's output includes correct "Next" step.

## Hook Test Cases

Run `./test.sh` to verify all hook patterns:

```bash
./test.sh
```

All tests should pass including:

- `block-branch-without-issue` tests
- `block-pr-without-issue` tests
- `common-warn-pr-merge` tests
- `common-warn-pr-create` tests
- `common-warn-git-push` tests

## Cleanup

After testing:

```bash
# Close test issue if created
gh issue close XX --comment "Test complete"

# Delete test branch if exists
git push origin --delete feat/dark-mode-XX 2>/dev/null
```
