#!/usr/bin/env bash

# Global test environment configuration
# Dynamically detect repo root (works in CI and devcontainer)
if [ -n "$GITHUB_WORKSPACE" ]; then
  # Running in GitHub Actions
  REPO_ROOT="$GITHUB_WORKSPACE"
elif command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
  # Use git to find repo root (works anywhere in repo)
  REPO_ROOT="$(git rev-parse --show-toplevel)"
elif [ -n "$BATS_TEST_DIRNAME" ]; then
  # Running with bats - BATS_TEST_DIRNAME is the directory containing the test file
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
else
  # Final fallback
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
export REPO_ROOT
export SETTINGS_FILE="$REPO_ROOT/.claude/settings.json"

# Load bats helpers
load '/usr/local/lib/bats/bats-support/load.bash'
load '/usr/local/lib/bats/bats-assert/load.bash'
load '/usr/local/lib/bats/bats-file/load.bash'

# Setup test environment
setup_suite() {
  TEST_TEMP_DIR="$(mktemp -d)"
  export TEST_TEMP_DIR
}

teardown_suite() {
  rm -rf "$TEST_TEMP_DIR"
}
