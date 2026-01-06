# Security Policy

This repository distributes security-focused configurations for Claude Code. Security is a core concern.

## Supported Versions

This project follows a rolling release model on the `main` branch. Always use the latest version.

| Branch | Supported          |
| ------ | ------------------ |
| main   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do not** open a public issue
2. Email the maintainer directly or use [GitHub's private vulnerability reporting](https://github.com/anthony-spruyt/claude-config/security/advisories/new)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

You can expect:

- **Initial response:** Within 48 hours
- **Status updates:** Every 7 days until resolved
- **Credit:** In the fix commit and release notes (unless you prefer anonymity)

## Security Measures

This repository implements multiple security layers:

- **File permission denials** - Blocks Claude Code access to sensitive files
- **Command blocking** - Prevents execution of secret-exposing commands
- **Hookify rules** - Event-based safety controls
- **Automated scanning** - Gitleaks, Secretlint, and Trivy on every commit
- **Pre-commit hooks** - Local secret detection before push

## Scope

Security issues include:

- Bypass of file permission denials
- Bypass of command blocking rules
- Bypass of hookify rules
- Secrets accidentally committed
- Vulnerabilities in sync scripts that could affect target repositories

Out of scope:

- Issues in Claude Code itself (report to Anthropic)
- Issues in third-party tools (MegaLinter, bats-core, etc.)
