#!/usr/bin/env bash

# Global test environment configuration
export REPO_ROOT="/workspaces/claude-config"
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
