# Workflow

This repository has branch protection enabled on `main`. Direct pushes are blocked.

## Important

- Never attempt `git push` directly to `main`
- Always go through the PR workflow

## Making Changes

1. Check if issue exists: `gh issue list --repo anthony-spruyt/claude-config --search "keywords"`

2. Create issue if needed using template fields

3. Track issue number throughout work

4. Reference in commits: `Ref #123`

5. **Create a feature branch** from the current commit:

   ```bash
   git checkout -b <branch-name>
   ```

6. **Push the branch** to origin:

   ```bash
   git push -u origin <branch-name>
   ```

7. **Create a pull request**:

Template: `.github/ISSUE_TEMPLATE/<type>.md`

8. **Wait for status checks**

9. **Merge** after approval (or user self-approves if they have permission)

## Branch Naming

Use `<type>/<description>` format matching [conventional commit types](common-conventional-commits-and-naming.md):

## GitHub Issues

### Issue Types

Read templates from `.github/ISSUE_TEMPLATE/` to get title prefix, labels, and required fields.

| Type    | Template              | Label           | Title Prefix    |
| ------- | --------------------- | --------------- | --------------- |
| Feature | `feature_request.yml` | `enhancement`   | `feat(scope):`  |
| Bug     | `bug_report.yml`      | `bug`           | `fix(scope):`   |
| Chore   | `chore.yml`           | `chore`         | `chore(scope):` |
| Docs    | `docs.yml`            | `documentation` | `docs(scope):`  |

### Required Fields

| Type    | Required Fields                                                                    |
| ------- | ---------------------------------------------------------------------------------- |
| Feature | Summary, Motivation, Acceptance Criteria, Affected Area                            |
| Bug     | Description, Expected Behavior, Actual Behavior, Steps to Reproduce, Affected Area |
| Chore   | Summary, Motivation, Chore Type, Affected Area                                     |
| Docs    | Summary, Motivation, Documentation Type, Affected Area                             |

### CLI Pattern

```bash
gh issue create --repo anthony-spruyt/claude-config \
  --title "<prefix from template> description" \
  --label "<labels from template>" \
  --body "$(cat <<'EOF'
## <label from first required field>
<content>

## <label from second required field>
<content>
EOF
)"
```

### Affected Area Options

- Claude Config (.claude/)
- Claude Agents (.claude/agents)
- Claude Rules (.claude/rules)
- Documentation
- CI/CD (.github/)
- Other

### Additional Labels

- `blocked` - Waiting on upstream fix or external dependency
- `dep/major`, `dep/minor`, `dep/patch` - Dependency version changes (Renovate)
