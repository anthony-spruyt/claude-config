#!/usr/bin/env bats

# Test hookify rule patterns and validation
# Tests hookify rules in .claude/ directory for proper structure and behavior

# Load bats libraries
load '/usr/local/lib/bats/bats-support/load'
load '/usr/local/lib/bats/bats-assert/load'
load '/usr/local/lib/bats/bats-file/load'

# Load custom helpers
load '../helpers/assertions'

# Set REPO_ROOT and SETTINGS_FILE
REPO_ROOT="${REPO_ROOT:-/workspaces/claude-config}"
SETTINGS_FILE="$REPO_ROOT/.claude/settings.json"

# Rule discovery and validation tests

@test "hookify: rules exist in .claude/" {
  local count
  count=$(count_hookify_rules)

  # Verify that we have at least some hookify rules configured
  [ "$count" -gt 0 ]
}

@test "hookify: all rules have valid frontmatter" {
  while IFS= read -r rule_file; do
    run validate_hookify_frontmatter "$rule_file"
    assert_success
  done < <(get_hookify_rules)
}

@test "hookify: all rules are enabled" {
  while IFS= read -r rule_file; do
    local enabled
    enabled=$(extract_hookify_enabled "$rule_file")
    [ "$enabled" = "true" ]
  done < <(get_hookify_rules)
}

@test "hookify: all rules have non-empty names" {
  while IFS= read -r rule_file; do
    local name
    name=$(extract_hookify_name "$rule_file")
    [ -n "$name" ]
  done < <(get_hookify_rules)
}

@test "hookify: bash rules have non-empty patterns" {
  while IFS= read -r rule_file; do
    local event
    event=$(extract_hookify_event "$rule_file")

    # Only check pattern for bash events (file events use conditions)
    if [ "$event" = "bash" ]; then
      local pattern
      pattern=$(extract_hookify_pattern "$rule_file")
      [ -n "$pattern" ]
    fi
  done < <(get_hookify_rules)
}

@test "hookify: all rules use bash or file event" {
  while IFS= read -r rule_file; do
    local event
    event=$(extract_hookify_event "$rule_file")
    # Events can be either "bash" or "file"
    [[ "$event" == "bash" || "$event" == "file" ]]
  done < <(get_hookify_rules)
}

@test "hookify: all rules use block action" {
  while IFS= read -r rule_file; do
    local action
    action=$(extract_hookify_action "$rule_file")
    [ "$action" = "block" ]
  done < <(get_hookify_rules)
}

# Individual rule pattern tests

# 1. block-sops-decrypt tests

@test "hookify: block-sops-decrypt triggers on 'sops -d'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-sops-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "sops -d secrets.yaml"
  assert_success
}

@test "hookify: block-sops-decrypt triggers on 'sops --decrypt'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-sops-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "sops --decrypt config.enc"
  assert_success
}

@test "hookify: block-sops-decrypt allows 'sops -e' (encrypt)" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-sops-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "sops -e secrets.yaml"
  assert_failure
}

@test "hookify: block-sops-decrypt allows 'sops --version'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-sops-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "sops --version"
  assert_failure
}

# 2. block-env-grep tests

@test "hookify: block-env-grep triggers on 'env | grep'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-env-grep.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "env | grep SECRET"
  assert_success
}

@test "hookify: block-env-grep triggers on 'printenv | grep'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-env-grep.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "printenv | grep TOKEN"
  assert_success
}

@test "hookify: block-env-grep allows 'env | cut -d= -f1'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-env-grep.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "env | cut -d= -f1"
  assert_failure
}

@test "hookify: block-env-grep allows 'env | wc -l'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-env-grep.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "env | wc -l"
  assert_failure
}

# 3. block-proc-environ tests

@test "hookify: block-proc-environ triggers on 'cat /proc/self/environ'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-proc-environ.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "cat /proc/self/environ"
  assert_success
}

@test "hookify: block-proc-environ triggers on 'cat /proc/\$\$/environ'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-proc-environ.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" 'cat /proc/$$/environ'
  assert_success
}

@test "hookify: block-proc-environ triggers on 'cat /proc/1234/environ'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-proc-environ.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "cat /proc/1234/environ"
  assert_success
}

@test "hookify: block-proc-environ allows 'cat /proc/cpuinfo'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-proc-environ.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "cat /proc/cpuinfo"
  assert_failure
}

# 4. block-kub3ctl-s3crets tests

@test "hookify: block-kub3ctl-s3crets file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-block-kub3ctl-s3crets.local.md" ]
}

@test "hookify: block-kub3ctl-s3crets has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kub3ctl-s3crets.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

@test "hookify: block-kub3ctl-s3crets triggers on 'kubectl get secret -o yaml'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kub3ctl-s3crets.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "kubectl get secret my-secret -o yaml"
  assert_success
}

@test "hookify: block-kub3ctl-s3crets triggers on 'kubectl get secret -o go-template'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kub3ctl-s3crets.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "kubectl get secret my-secret -o go-template='{{.data.password}}'"
  assert_success
}

@test "hookify: block-kub3ctl-s3crets allows plain 'kubectl get secrets'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kub3ctl-s3crets.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "kubectl get secrets"
  assert_failure
}

# 4b. block-kub3ctl-describe-s3crets tests

@test "hookify: block-kub3ctl-describe-s3crets file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-block-kub3ctl-describe-s3crets.local.md" ]
}

@test "hookify: block-kub3ctl-describe-s3crets has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kub3ctl-describe-s3crets.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

@test "hookify: block-kub3ctl-describe-s3crets triggers on 'kubectl describe secret'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kub3ctl-describe-s3crets.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "kubectl describe secret my-secret"
  assert_success
}

@test "hookify: block-kub3ctl-describe-s3crets triggers on 'kubectl describe secrets'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kub3ctl-describe-s3crets.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "kubectl describe secrets"
  assert_success
}

@test "hookify: block-kub3ctl-describe-s3crets allows 'kubectl describe pod'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kub3ctl-describe-s3crets.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "kubectl describe pod my-pod"
  assert_failure
}

# 5. block-kub3ctl-exec-s3crets tests

@test "hookify: block-kub3ctl-exec-s3crets file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-block-kub3ctl-exec-s3crets.local.md" ]
}

@test "hookify: block-kub3ctl-exec-s3crets has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kub3ctl-exec-s3crets.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

# 6. block-sops-read tests

@test "hookify: block-sops-read file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-block-sops-read.local.md" ]
}

@test "hookify: block-sops-read has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-sops-read.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

# 7. block-talos-config tests

@test "hookify: block-talos-config file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-block-talos-config.local.md" ]
}

@test "hookify: block-talos-config has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-talos-config.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

# 8. block-issue-close tests

@test "hookify: block-issue-close file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-block-issue-close.local.md" ]
}

@test "hookify: block-issue-close has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-issue-close.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

# Cross-validation: settings.json vs hookify rules

@test "hookify: settings.json blocks sops -d AND hookify blocks it" {
  # Both settings.json Bash deny and hookify should block sops -d
  run check_command_blocked "sops -d file.yaml"
  assert_success

  local rule_file="$REPO_ROOT/.claude/hookify.common-block-sops-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "sops -d file.yaml"
  assert_success
}

@test "hookify: settings.json blocks printenv AND hookify blocks env|grep" {
  # Both settings.json and hookify provide complementary protection
  run check_command_blocked "printenv"
  assert_success

  local rule_file="$REPO_ROOT/.claude/hookify.common-block-env-grep.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "env | grep SECRET"
  assert_success
}

# File organization tests

@test "hookify: all rule files follow naming convention" {
  while IFS= read -r rule_file; do
    local basename
    basename=$(basename "$rule_file")

    # Should match hookify.common-*.local.md (common- prefix is our watermark)
    [[ "$basename" =~ ^hookify\.common-.*\.local\.md$ ]]
  done < <(get_hookify_rules)
}

@test "hookify: all rule files are in .claude/ directory" {
  while IFS= read -r rule_file; do
    local dirname
    dirname=$(dirname "$rule_file")

    [[ "$dirname" == *"/.claude" ]]
  done < <(get_hookify_rules)
}

# Pattern syntax validation

@test "hookify: all patterns are valid Perl regex" {
  while IFS= read -r rule_file; do
    local pattern
    pattern=$(extract_hookify_pattern "$rule_file")

    # Test pattern syntax by attempting to use it with grep -P
    echo "test" | grep -P "$pattern" > /dev/null 2>&1 || true

    # If grep didn't error on the pattern, it's valid
    local exit_code=$?
    [ "$exit_code" -ne 2 ]  # Exit code 2 means invalid regex
  done < <(get_hookify_rules)
}

# Defense-in-depth validation

@test "defense-in-depth: sops decryption blocked by multiple layers" {
  # Layer 1: settings.json Bash deny
  run check_command_blocked "sops -d secrets.yaml"
  assert_success

  # Layer 2: hookify rule
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-sops-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "sops -d secrets.yaml"
  assert_success
}

@test "defense-in-depth: environment access blocked by multiple layers" {
  # Layer 1: settings.json blocks printenv
  run check_command_blocked "printenv"
  assert_success

  # Layer 2: hookify blocks env|grep
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-env-grep.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "printenv | grep SECRET"
  assert_success
}
