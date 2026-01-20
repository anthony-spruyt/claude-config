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

# Exclusion functions tests
# These test the helper functions defined in sync-to-repo.sh

# Helper to extract and source just the functions from the script
extract_functions() {
  # Extract lines from variable definitions through is_file_excluded function
  sed -n '/^# Check for yq/,/^# Cleanup on exit/p' "$SCRIPT_PATH" | head -n -2
}

@test "sync-to-repo: is_category_excluded returns 0 for excluded category" {
  # Source the extracted functions
  eval "$(extract_functions)"

  # Set up exclusion array
  EXCLUDE_CATEGORIES=("agents" "commands")

  run is_category_excluded "agents"
  assert_success
}

@test "sync-to-repo: is_category_excluded returns 1 for non-excluded category" {
  eval "$(extract_functions)"

  EXCLUDE_CATEGORIES=("agents" "commands")

  run is_category_excluded "rules"
  assert_failure
}

@test "sync-to-repo: is_category_excluded returns 1 with empty array" {
  eval "$(extract_functions)"

  EXCLUDE_CATEGORIES=()

  run is_category_excluded "agents"
  assert_failure
}

@test "sync-to-repo: is_file_excluded returns 0 for excluded file" {
  eval "$(extract_functions)"

  EXCLUDE_FILES=("common-tdd.md" "hookify.common-block-kubectl.local.md")

  run is_file_excluded "/some/path/common-tdd.md"
  assert_success
}

@test "sync-to-repo: is_file_excluded returns 1 for non-excluded file" {
  eval "$(extract_functions)"

  EXCLUDE_FILES=("common-tdd.md")

  run is_file_excluded "/some/path/common-research.md"
  assert_failure
}

@test "sync-to-repo: is_file_excluded matches basename only" {
  eval "$(extract_functions)"

  EXCLUDE_FILES=("common-tdd.md")

  # Should match - same basename
  run is_file_excluded "rules/common-tdd.md"
  assert_success

  # Should match - different path, same basename
  run is_file_excluded "/workspaces/config/.claude/rules/common-tdd.md"
  assert_success
}

@test "sync-to-repo: is_file_excluded returns 1 with empty array" {
  eval "$(extract_functions)"

  EXCLUDE_FILES=()

  run is_file_excluded "common-tdd.md"
  assert_failure
}
