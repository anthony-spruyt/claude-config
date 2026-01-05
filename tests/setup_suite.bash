#!/usr/bin/env bash

# Global test environment configuration
# Dynamically detect repo root (works in CI and devcontainer)
# Use BATS_TEST_DIRNAME which is set by bats to the directory containing the test file
if [ -n "$BATS_TEST_DIRNAME" ]; then
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
else
  # Fallback for when BATS_TEST_DIRNAME is not set
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
