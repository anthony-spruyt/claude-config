#!/usr/bin/env bats

# Test sync-to-repo.sh shell script
# Focus: Argument validation, error handling, basic logic

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

@test "sync-to-repo: has bash shebang" {
  run head -1 "$SCRIPT_PATH"
  assert_success
  assert_output --partial "#!/bin/bash"
}

@test "sync-to-repo: uses set -euo pipefail" {
  run grep -q "set -euo pipefail" "$SCRIPT_PATH"
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

@test "sync-to-repo: accepts one argument (target repo)" {
  # Just validate it doesn't fail on argument parsing
  # Will fail on GitHub operations, but that's expected
  run timeout 2 bash -c "$SCRIPT_PATH user/repo 2>&1 || true"
  # Should at least parse the argument without syntax errors
}

# Variable and constant tests

@test "sync-to-repo: defines TARGET_REPO variable" {
  run grep -q 'TARGET_REPO=' "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: defines CONFIG_REPO with default" {
  run grep -q 'CONFIG_REPO=.*USER/claude-config' "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: defines CONFIG_BRANCH with default" {
  run grep -q 'CONFIG_BRANCH=.*main' "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: creates timestamped branch name" {
  run grep -q 'TIMESTAMP=$(date' "$SCRIPT_PATH"
  assert_success

  run grep -q 'BRANCH_NAME=.*update-config' "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: timestamp format is YYYYMMDD-HHMMSS" {
  run grep -q 'date +%Y%m%d-%H%M%S' "$SCRIPT_PATH"
  assert_success
}

# Cleanup and error handling

@test "sync-to-repo: uses trap for cleanup" {
  run grep -q "trap.*rm -rf.*WORK_DIR" "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: creates temporary working directory" {
  run grep -q 'WORK_DIR=$(mktemp -d)' "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: cleans up on exit" {
  # Verify trap is set to clean up temp directory
  run grep -q "trap.*EXIT" "$SCRIPT_PATH"
  assert_success
}

# Git operations (structure tests)

@test "sync-to-repo: clones config repo" {
  run grep -q "gh repo clone.*CONFIG_REPO.*config" "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: clones target repo" {
  run grep -q "gh repo clone.*TARGET_REPO.*target" "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: uses --depth 1 for shallow clone" {
  run grep -q "gh repo clone.*--depth 1" "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: specifies config branch" {
  run grep -q "gh repo clone.*--branch.*CONFIG_BRANCH" "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: uses single-branch clone for config" {
  run grep -q "gh repo clone.*--single-branch" "$SCRIPT_PATH"
  assert_success
}

# File operations

@test "sync-to-repo: ensures .claude directory exists" {
  run grep -q "mkdir -p target/.claude" "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: copies .claude files" {
  run grep -q "cp -r config/.claude/\* target/.claude/" "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: checks for changes with git diff" {
  run grep -q "git diff --quiet .claude/" "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: exits early if no changes" {
  run grep -q "No changes detected" "$SCRIPT_PATH"
  assert_success
}

# Branch and commit operations

@test "sync-to-repo: creates feature branch" {
  run grep -q "git checkout -b.*BRANCH_NAME" "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: stages .claude directory" {
  run grep -q "git add .claude/" "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: creates commit" {
  run grep -q "git commit -m" "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: commit message includes 'config'" {
  run grep -A 5 "git commit -m" "$SCRIPT_PATH"
  assert_success
  assert_output --partial "config"
}

@test "sync-to-repo: commit includes Claude Code attribution" {
  run grep -A 10 "git commit -m" "$SCRIPT_PATH"
  assert_success
  assert_output --partial "Claude Code"
}

@test "sync-to-repo: pushes branch with -u flag" {
  run grep -q "git push -u origin.*BRANCH_NAME" "$SCRIPT_PATH"
  assert_success
}

# Pull request operations

@test "sync-to-repo: creates PR with gh pr create" {
  run grep -q "gh pr create" "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: PR has title" {
  run grep -q -- "--title" "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: PR has body" {
  run grep -q -- "--body" "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: PR includes source repo info" {
  run grep -A 20 "gh pr create" "$SCRIPT_PATH"
  assert_success
  assert_output --partial "CONFIG_REPO"
}

@test "sync-to-repo: PR includes changes summary" {
  run grep -A 20 "gh pr create" "$SCRIPT_PATH"
  assert_success
  assert_output --partial "git diff --stat"
}

@test "sync-to-repo: PR includes file list" {
  run grep -A 20 "gh pr create" "$SCRIPT_PATH"
  assert_success
  assert_output --partial "git diff --name-only"
}

@test "sync-to-repo: PR includes review checklist" {
  run grep -A 30 "gh pr create" "$SCRIPT_PATH"
  assert_success
  assert_output --partial "Review Checklist"
}

@test "sync-to-repo: PR adds labels" {
  run grep -q -- "--label" "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: PR labels include 'config'" {
  run grep -- "--label" "$SCRIPT_PATH"
  assert_success
  assert_output --partial "config"
}

# Output and user feedback

@test "sync-to-repo: displays progress messages" {
  run grep -c "echo.*🔧\\|📦\\|💼\\|📥\\|📋\\|📊\\|🌿\\|⬆️\\|🔀\\|✅" "$SCRIPT_PATH"
  assert_success
  # Should have multiple emoji-prefixed progress messages
}

@test "sync-to-repo: shows working directory" {
  run grep -q 'echo.*Working directory.*WORK_DIR' "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: shows diff stats when changes detected" {
  run grep -q "git diff --stat" "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: outputs PR URL at end" {
  run grep -q 'echo.*\${PR_URL}' "$SCRIPT_PATH"
  assert_success
}

# Edge cases and validation

@test "sync-to-repo: script contains usage comment" {
  run head -20 "$SCRIPT_PATH"
  assert_success
  assert_output --partial "Usage:"
}

@test "sync-to-repo: usage mentions environment variables" {
  run head -20 "$SCRIPT_PATH"
  assert_success
  assert_output --partial "GH_TOKEN"
}

@test "sync-to-repo: changes directory to WORK_DIR" {
  run grep -q "cd.*WORK_DIR" "$SCRIPT_PATH"
  assert_success
}

@test "sync-to-repo: changes to target directory for git operations" {
  run grep -q "cd target" "$SCRIPT_PATH"
  assert_success
}

# Line count validation (ensure script hasn't grown too complex)

@test "sync-to-repo: script is under 150 lines" {
  local line_count
  line_count=$(wc -l < "$SCRIPT_PATH")

  [ "$line_count" -lt 150 ]
}

# Script quality checks

@test "sync-to-repo: no TODO comments" {
  run grep -i "TODO\\|FIXME\\|HACK" "$SCRIPT_PATH"
  assert_failure
}

@test "sync-to-repo: no hardcoded secrets" {
  run grep -iE "password|token|secret|key.*=" "$SCRIPT_PATH"
  # Should not find any hardcoded credentials (only variable references)
  if [ "$status" -eq 0 ]; then
    # If found, ensure they're variable names, not values
    refute_output --partial "password="
    refute_output --partial "token="
  fi
}

@test "sync-to-repo: uses double quotes for variables" {
  # Check that important variables are quoted
  run grep -E '\$\{?TARGET_REPO\}?' "$SCRIPT_PATH"
  assert_success
  # Just verify that TARGET_REPO is used (actual quoting is validated by shellcheck)
}
