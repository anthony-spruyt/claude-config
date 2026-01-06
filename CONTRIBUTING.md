# Contributing to Claude Config

Thank you for your interest in contributing! This guide will help you get started.

For an overview of the project, see the [README](README.md).

## Development Setup

1. Fork this repository
2. Clone your fork:

   ```bash
   git clone https://github.com/YOUR_USERNAME/claude-config.git
   cd claude-config
   ```

3. Open in VS Code and reopen in devcontainer
4. Verify your setup: `./test.sh && ./lint.sh`

For detailed setup instructions (prerequisites, SSH agent, troubleshooting), see [DEVELOPMENT.md](DEVELOPMENT.md).

## Branching Strategy

| Branch Type | Pattern               | Example                   |
| ----------- | --------------------- | ------------------------- |
| Main        | `main`                | Protected, requires PR    |
| Feature     | `feat/<description>`  | `feat/add-new-rule`       |
| Bug fix     | `fix/<description>`   | `fix/command-block-regex` |
| Docs        | `docs/<description>`  | `docs/update-readme`      |
| Chore       | `chore/<description>` | `chore/update-deps`       |

## Commit Convention

This project uses [Conventional Commits](https://www.conventionalcommits.org/).

### Format

```text
type(scope): description
```

### Types

| Type       | Description                                         |
| ---------- | --------------------------------------------------- |
| `feat`     | New feature                                         |
| `fix`      | Bug fix                                             |
| `docs`     | Documentation changes                               |
| `chore`    | Maintenance tasks                                   |
| `test`     | Adding or updating tests                            |
| `refactor` | Code changes that neither fix bugs nor add features |

### Examples

```bash
feat(hookify): add rule for blocking kubectl secrets
fix(sync): correct regex for common- prefix matching
docs(readme): add architecture diagram
chore(deps): update bats-core to latest version
test(security): add tests for new file permission patterns
```

## Pull Request Process

1. **Create a branch** from `main` using the naming convention above

2. **Make your changes** and commit using Conventional Commits

3. **Ensure all checks pass**:

   ```bash
   ./test.sh   # All tests must pass
   ./lint.sh   # No linting errors
   ```

4. **Push and open a PR** against `main`

5. **Request a review** and address any feedback

## Testing Requirements

All security controls must be tested. Before submitting:

- Run the full test suite: `./test.sh`
- Add tests for new functionality:

  | Change Type      | Test Location                               |
  | ---------------- | ------------------------------------------- |
  | File permissions | `tests/security/test_file_permissions.bats` |
  | Command blocks   | `tests/security/test_command_blocks.bats`   |
  | Hookify rules    | `tests/hooks/test_hookify_rules.bats`       |
  | Shell scripts    | `tests/unit/`                               |

## Code Style

Code style is enforced automatically:

| File Type     | Linter/Formatter          |
| ------------- | ------------------------- |
| Shell scripts | ShellCheck                |
| YAML          | yamllint                  |
| Markdown      | markdownlint              |
| All files     | Prettier (via pre-commit) |

Pre-commit hooks run automatically on commit. To run manually:

```bash
pre-commit run --all-files
```

## Security Considerations

This is a security-focused project. When contributing:

- **Never commit secrets** - gitleaks and secretlint will block this
- **Follow the `common-` prefix convention** - Centrally-managed files use this prefix
- **Test security rules** - All deny patterns must have corresponding tests
- **Consider defense-in-depth** - Multiple layers are better than one

## Questions?

Open an issue for questions or suggestions.
