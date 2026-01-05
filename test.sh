#!/usr/bin/env bash
set -euo pipefail

# Track exit codes
EXIT_CODE=0

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR/tests"

# Run all test suites from tests directory (so setup_suite.bash is loaded)
cd "$TESTS_DIR"

echo "============================="
echo "Running Security Tests"
echo "============================="
bats security/ || EXIT_CODE=$?

echo ""
echo "============================="
echo "Running Hooks Tests"
echo "============================="
bats hooks/ || EXIT_CODE=$?

echo ""
echo "============================="
echo "Running Unit Tests"
echo "============================="
bats unit/ || EXIT_CODE=$?

# Return to original directory
cd - >/dev/null

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
