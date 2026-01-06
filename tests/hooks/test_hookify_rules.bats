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

@test "hookify: all rules use block or warn action" {
  while IFS= read -r rule_file; do
    local action
    action=$(extract_hookify_action "$rule_file")
    [[ "$action" == "block" || "$action" == "warn" ]]
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

@test "hookify: block-sops-decrypt triggers on 'sops exec-env'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-sops-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "sops exec-env secrets.yaml 'printenv'"
  assert_success
}

@test "hookify: block-sops-decrypt triggers on 'sops exec-file'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-sops-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "sops exec-file secrets.yaml 'cat {}'"
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

# 4. block-kubectl-s3crets tests

@test "hookify: block-kubectl-s3crets file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-block-kubectl-s3crets.local.md" ]
}

@test "hookify: block-kubectl-s3crets has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kubectl-s3crets.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

@test "hookify: block-kubectl-s3crets triggers on 'kubectl get secret -o yaml'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kubectl-s3crets.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "kubectl get secret my-secret -o yaml"
  assert_success
}

@test "hookify: block-kubectl-s3crets triggers on 'kubectl get secret -o go-template'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kubectl-s3crets.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "kubectl get secret my-secret -o go-template='{{.data.password}}'"
  assert_success
}

@test "hookify: block-kubectl-s3crets allows plain 'kubectl get secrets'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kubectl-s3crets.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "kubectl get secrets"
  assert_failure
}

# 4b. block-kubectl-describe-s3crets tests

@test "hookify: block-kubectl-describe-s3crets file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-block-kubectl-describe-s3crets.local.md" ]
}

@test "hookify: block-kubectl-describe-s3crets has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kubectl-describe-s3crets.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

@test "hookify: block-kubectl-describe-s3crets triggers on 'kubectl describe secret'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kubectl-describe-s3crets.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "kubectl describe secret my-secret"
  assert_success
}

@test "hookify: block-kubectl-describe-s3crets triggers on 'kubectl describe secrets'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kubectl-describe-s3crets.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "kubectl describe secrets"
  assert_success
}

@test "hookify: block-kubectl-describe-s3crets allows 'kubectl describe pod'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kubectl-describe-s3crets.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "kubectl describe pod my-pod"
  assert_failure
}

# 5. block-kubectl-exec-s3crets tests

@test "hookify: block-kubectl-exec-s3crets file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-block-kubectl-exec-s3crets.local.md" ]
}

@test "hookify: block-kubectl-exec-s3crets has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-kubectl-exec-s3crets.local.md"

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

# Hookify-only: all Bash blocks handled by hookify with guidance

@test "hookify-only: sops -d blocked by hookify with guidance" {
  # NOT in settings.json deny - hookify provides the block with instructions
  run check_command_blocked "sops -d file.yaml"
  assert_failure  # Not blocked by settings.json

  # Blocked by hookify rule with helpful message
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-sops-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "sops -d file.yaml"
  assert_success
}

@test "hookify-only: printenv blocked by hookify with guidance" {
  # NOT in settings.json deny - hookify provides the block with instructions
  run check_command_blocked "printenv"
  assert_failure  # Not blocked by settings.json

  # Blocked by hookify rule with helpful message
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-printenv.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "printenv"
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

# Multiple hookify rules for comprehensive coverage

@test "hookify: sops has decrypt rule for blocking" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-sops-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  # sops decrypt blocked
  run matches_hookify_pattern "$pattern" "sops -d secrets.yaml"
  assert_success

  # sops encrypt allowed
  run matches_hookify_pattern "$pattern" "sops -e secrets.yaml"
  assert_failure
}

@test "hookify: environment access has multiple blocking rules" {
  # Rule 1: block-printenv blocks standalone printenv
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-printenv.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "printenv"
  assert_success

  # Rule 2: block-env-grep blocks env | grep
  rule_file="$REPO_ROOT/.claude/hookify.common-block-env-grep.local.md"
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "env | grep SECRET"
  assert_success

  # Rule 3: block-env-dump blocks standalone env
  rule_file="$REPO_ROOT/.claude/hookify.common-block-env-dump.local.md"
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "env"
  assert_success
}

# 9. warn-shell-wrappers tests

@test "hookify: warn-shell-wrappers file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-warn-shell-wrappers.local.md" ]
}

@test "hookify: warn-shell-wrappers has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-warn-shell-wrappers.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

@test "hookify: warn-shell-wrappers triggers on 'sh -c'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-warn-shell-wrappers.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "sh -c 'echo hello'"
  assert_success
}

@test "hookify: warn-shell-wrappers triggers on 'bash -c'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-warn-shell-wrappers.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "bash -c 'cat file'"
  assert_success
}

@test "hookify: warn-shell-wrappers triggers on 'eval'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-warn-shell-wrappers.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "eval 'printenv'"
  assert_success
}

@test "hookify: warn-shell-wrappers triggers on chained 'sh -c'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-warn-shell-wrappers.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "mkdir /tmp && sh -c 'cat /etc/passwd'"
  assert_success
}

@test "hookify: warn-shell-wrappers allows plain bash command" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-warn-shell-wrappers.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "bash script.sh"
  assert_failure
}

# 10. block-env-dump tests

@test "hookify: block-env-dump file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-block-env-dump.local.md" ]
}

@test "hookify: block-env-dump has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-env-dump.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

@test "hookify: block-env-dump triggers on standalone 'env'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-env-dump.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "env"
  assert_success
}

@test "hookify: block-env-dump triggers on 'env' with pipe" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-env-dump.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "env | head"
  assert_success
}

@test "hookify: block-env-dump triggers on chained 'env'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-env-dump.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "mkdir /tmp && env"
  assert_success
}

@test "hookify: block-env-dump allows 'env VAR=value command'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-env-dump.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  # env with args to set variables is safe
  run matches_hookify_pattern "$pattern" "env PATH=/bin command"
  assert_failure
}

# 10b. block-printenv tests

@test "hookify: block-printenv file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-block-printenv.local.md" ]
}

@test "hookify: block-printenv has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-printenv.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

@test "hookify: block-printenv triggers on standalone 'printenv'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-printenv.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "printenv"
  assert_success
}

@test "hookify: block-printenv triggers on 'printenv' with variable" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-printenv.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "printenv SECRET_KEY"
  assert_success
}

@test "hookify: block-printenv triggers on chained 'printenv'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-printenv.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "ls && printenv"
  assert_success
}

# 11. warn-use-read-tool tests

@test "hookify: warn-use-read-tool file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-warn-use-read-tool.local.md" ]
}

@test "hookify: warn-use-read-tool has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-warn-use-read-tool.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

@test "hookify: warn-use-read-tool triggers on 'cat file'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-warn-use-read-tool.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "cat README.md"
  assert_success
}

@test "hookify: warn-use-read-tool triggers on 'head file'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-warn-use-read-tool.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "head -n 50 file.txt"
  assert_success
}

@test "hookify: warn-use-read-tool triggers on 'tail file'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-warn-use-read-tool.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "tail -f logfile"
  assert_success
}

@test "hookify: warn-use-read-tool triggers on 'cat' in pipeline (should use Grep tool)" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-warn-use-read-tool.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  # cat file | grep should trigger - agent should use Grep tool instead
  run matches_hookify_pattern "$pattern" "cat file.txt | grep pattern"
  assert_success
}

# 12. warn-use-grep-tool tests

@test "hookify: warn-use-grep-tool file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-warn-use-grep-tool.local.md" ]
}

@test "hookify: warn-use-grep-tool has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-warn-use-grep-tool.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

@test "hookify: warn-use-grep-tool triggers on 'grep pattern'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-warn-use-grep-tool.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "grep 'TODO' src/"
  assert_success
}

@test "hookify: warn-use-grep-tool triggers on 'rg pattern'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-warn-use-grep-tool.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "rg 'function' --type js"
  assert_success
}

# 13. warn-use-edit-tool tests

@test "hookify: warn-use-edit-tool file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-warn-use-edit-tool.local.md" ]
}

@test "hookify: warn-use-edit-tool has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-warn-use-edit-tool.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

@test "hookify: warn-use-edit-tool triggers on 'sed -i'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-warn-use-edit-tool.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "sed -i 's/old/new/g' file.txt"
  assert_success
}

@test "hookify: warn-use-edit-tool allows 'sed' without -i (non-destructive)" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-warn-use-edit-tool.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "sed 's/old/new/g' file.txt"
  assert_failure
}

# 14. block-base64-decode tests

@test "hookify: block-base64-decode file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-block-base64-decode.local.md" ]
}

@test "hookify: block-base64-decode has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-base64-decode.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

@test "hookify: block-base64-decode triggers on 'base64 -d'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-base64-decode.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "base64 -d secret.txt"
  assert_success
}

@test "hookify: block-base64-decode triggers on 'base64 --decode'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-base64-decode.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "base64 --decode secret.txt"
  assert_success
}

@test "hookify: block-base64-decode triggers on 'base64 -D' (BSD)" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-base64-decode.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "base64 -D secret.txt"
  assert_success
}

@test "hookify: block-base64-decode allows 'base64' encode" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-base64-decode.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "echo 'test' | base64"
  assert_failure
}

# 15. block-gpg-decrypt tests

@test "hookify: block-gpg-decrypt file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-block-gpg-decrypt.local.md" ]
}

@test "hookify: block-gpg-decrypt has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-gpg-decrypt.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

@test "hookify: block-gpg-decrypt triggers on 'gpg -d'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-gpg-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "gpg -d secrets.gpg"
  assert_success
}

@test "hookify: block-gpg-decrypt triggers on 'gpg --decrypt'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-gpg-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "gpg --decrypt secrets.gpg"
  assert_success
}

@test "hookify: block-gpg-decrypt allows 'gpg --encrypt'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-gpg-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "gpg --encrypt -r user@example.com file"
  assert_failure
}

@test "hookify: block-gpg-decrypt allows 'gpg --list-keys'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-gpg-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "gpg --list-keys"
  assert_failure
}

# 16. block-openssl-decrypt tests

@test "hookify: block-openssl-decrypt file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-block-openssl-decrypt.local.md" ]
}

@test "hookify: block-openssl-decrypt has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-openssl-decrypt.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

@test "hookify: block-openssl-decrypt triggers on 'openssl enc -d'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-openssl-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "openssl enc -d -aes-256-cbc -in file.enc"
  assert_success
}

@test "hookify: block-openssl-decrypt triggers on 'openssl pkcs12'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-openssl-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "openssl pkcs12 -in cert.p12"
  assert_success
}

@test "hookify: block-openssl-decrypt allows 'openssl x509'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-openssl-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "openssl x509 -in cert.pem -text"
  assert_failure
}

@test "hookify: block-openssl-decrypt allows 'openssl genrsa'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-openssl-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "openssl genrsa -out key.pem 2048"
  assert_failure
}

# 17. block-age-decrypt tests

@test "hookify: block-age-decrypt file exists" {
  [ -f "$REPO_ROOT/.claude/hookify.common-block-age-decrypt.local.md" ]
}

@test "hookify: block-age-decrypt has valid frontmatter" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-age-decrypt.local.md"

  run validate_hookify_frontmatter "$rule_file"
  assert_success
}

@test "hookify: block-age-decrypt triggers on 'age -d'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-age-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "age -d -i key.txt file.age"
  assert_success
}

@test "hookify: block-age-decrypt triggers on 'age --decrypt'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-age-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "age --decrypt file.age"
  assert_success
}

@test "hookify: block-age-decrypt allows 'age' encrypt" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-age-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "age -r recipient -o file.age file"
  assert_failure
}

@test "hookify: block-age-decrypt allows 'age-keygen'" {
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-age-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "age-keygen -o key.txt"
  assert_failure
}

# Hookify-only blocks: these commands are blocked by hookify (with guidance) not settings.json

@test "hookify-only: base64 decode blocked by hookify with guidance" {
  # NOT in settings.json deny - hookify provides the block with instructions
  run check_command_blocked "base64 -d secret.txt"
  assert_failure  # Not blocked by settings.json

  # Blocked by hookify rule with helpful message
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-base64-decode.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "base64 -d secret.txt"
  assert_success
}

@test "hookify-only: gpg decrypt blocked by hookify with guidance" {
  # NOT in settings.json deny - hookify provides the block with instructions
  run check_command_blocked "gpg -d secrets.gpg"
  assert_failure  # Not blocked by settings.json

  # Blocked by hookify rule with helpful message
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-gpg-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "gpg -d secrets.gpg"
  assert_success
}

@test "hookify-only: age decrypt blocked by hookify with guidance" {
  # NOT in settings.json deny - hookify provides the block with instructions
  run check_command_blocked "age -d file.age"
  assert_failure  # Not blocked by settings.json

  # Blocked by hookify rule with helpful message
  local rule_file="$REPO_ROOT/.claude/hookify.common-block-age-decrypt.local.md"
  local pattern
  pattern=$(extract_hookify_pattern "$rule_file")

  run matches_hookify_pattern "$pattern" "age -d file.age"
  assert_success
}
