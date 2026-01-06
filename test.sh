#!/usr/bin/env bash
set -euo pipefail

# Track exit codes
EXIT_CODE=0

# Get repo root (where this script lives)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT
export SETTINGS_FILE="$REPO_ROOT/.claude/settings.json"

echo "============================="
echo "Running Security Tests"
echo "============================="
bats "$REPO_ROOT/tests/security/" || EXIT_CODE=$?

echo ""
echo "============================="
echo "Running Hooks Tests"
echo "============================="
bats "$REPO_ROOT/tests/hooks/" || EXIT_CODE=$?

echo ""
echo "============================="
echo "Running Unit Tests"
echo "============================="
bats "$REPO_ROOT/tests/unit/" || EXIT_CODE=$?

echo ""
echo "============================="
echo "Test Summary"
echo "============================="
echo "✅ Security: File permissions, command blocks"
echo "✅ Hooks: Hookify rules validation and behavior"
echo "✅ Unit: Shell scripts, devcontainer setup"
echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo "🎉 All tests passed!"
else
  echo "⚠️  Some tests failed (exit code: $EXIT_CODE)"
  echo "Run individual test files to see details"
fi

exit $EXIT_CODE
