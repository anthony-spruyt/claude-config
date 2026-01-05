#!/usr/bin/env bash
set -euo pipefail

# Track exit codes
EXIT_CODE=0

# Run all test suites
echo "============================="
echo "Running Security Tests"
echo "============================="
bats tests/security/ || EXIT_CODE=$?

echo ""
echo "============================="
echo "Running Hooks Tests"
echo "============================="
bats tests/hooks/ || EXIT_CODE=$?

echo ""
echo "============================="
echo "Running Unit Tests"
echo "============================="
bats tests/unit/ || EXIT_CODE=$?

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
