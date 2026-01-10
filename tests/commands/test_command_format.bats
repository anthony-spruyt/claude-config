#!/usr/bin/env bats

# Test command file format validation

# Load bats libraries
load '/usr/local/lib/bats/bats-support/load'
load '/usr/local/lib/bats/bats-assert/load'

REPO_ROOT="${REPO_ROOT:-/workspaces/claude-config}"
COMMANDS_DIR="$REPO_ROOT/.claude/commands"

@test "commands directory exists" {
  [ -d "$COMMANDS_DIR" ]
}

@test "commands: at least one common-*.md file exists" {
  run bash -c "ls '$COMMANDS_DIR'/common-*.md 2>/dev/null | wc -l"
  assert_success
  [ "$output" -gt 0 ]
}

@test "commands: all common-*.md files start with frontmatter delimiter" {
  for cmd in "$COMMANDS_DIR"/common-*.md; do
    [ -e "$cmd" ] || continue
    run head -1 "$cmd"
    assert_output "---"
  done
}

@test "commands: all common-*.md files have description field" {
  for cmd in "$COMMANDS_DIR"/common-*.md; do
    [ -e "$cmd" ] || continue
    run grep -m1 "^description:" "$cmd"
    assert_success
  done
}

@test "commands: all common-*.md files have allowed-tools field" {
  for cmd in "$COMMANDS_DIR"/common-*.md; do
    [ -e "$cmd" ] || continue
    run grep -m1 "^allowed-tools:" "$cmd"
    assert_success
  done
}

@test "commands: frontmatter is properly closed" {
  for cmd in "$COMMANDS_DIR"/common-*.md; do
    [ -e "$cmd" ] || continue
    # Count occurrences of --- (should be at least 2 for open and close)
    run bash -c "grep -c '^---$' '$cmd'"
    assert_success
    [ "$output" -ge 2 ]
  done
}
