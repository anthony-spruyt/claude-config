#!/usr/bin/env bash

# Global test environment configuration
# REPO_ROOT and SETTINGS_FILE should be set by test.sh
# This provides fallbacks for running individual test files directly
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "/workspaces/claude-config")"
  export REPO_ROOT
fi
if [ -z "$SETTINGS_FILE" ]; then
  export SETTINGS_FILE="$REPO_ROOT/.claude/settings.json"
fi

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
