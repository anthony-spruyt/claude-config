#!/usr/bin/env bats

# Test sync-to-repo.sh shell script
# Focus: Syntax validation, argument handling, executable checks

# Load bats libraries
load '/usr/local/lib/bats/bats-support/load'
load '/usr/local/lib/bats/bats-assert/load'
load '/usr/local/lib/bats/bats-file/load'

# Load custom helpers
load '../helpers/assertions'

# Set REPO_ROOT
REPO_ROOT="${REPO_ROOT:-/workspaces/claude-config}"
SCRIPT_PATH="$REPO_ROOT/sync-to-repo.sh"

# Script existence and permissions

@test "sync-to-repo: script exists" {
  [ -f "$SCRIPT_PATH" ]
}

@test "sync-to-repo: script is executable" {
  [ -x "$SCRIPT_PATH" ]
}

@test "sync-to-repo: has valid bash syntax" {
  run bash -n "$SCRIPT_PATH"
  assert_success
}

# Argument validation tests

@test "sync-to-repo: requires at least one argument" {
  run "$SCRIPT_PATH"
  assert_failure
  assert_output --partial "Usage:"
}

@test "sync-to-repo: usage shows correct format" {
  run "$SCRIPT_PATH"
  assert_failure
  assert_output --partial "USER/target-repo"
}
