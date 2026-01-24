#!/usr/bin/env bats
# Test scripts/sync-files.sh shell script

# Get repo root
setup() {
  REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)}"
  SCRIPT_PATH="$REPO_ROOT/scripts/sync-files.sh"
}

@test "sync-files: script exists" {
  [ -f "$SCRIPT_PATH" ]
}

@test "sync-files: script is executable" {
  [ -x "$SCRIPT_PATH" ]
}

@test "sync-files: has valid bash syntax" {
  run bash -n "$SCRIPT_PATH"
  [ "$status" -eq 0 ]
}

@test "sync-files: requires two arguments" {
  run "$SCRIPT_PATH"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "sync-files: usage shows correct format" {
  run "$SCRIPT_PATH"
  [[ "$output" == *"<source_dir>"* ]]
  [[ "$output" == *"<target_dir>"* ]]
}
