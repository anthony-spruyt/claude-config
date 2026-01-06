#!/usr/bin/env bats

# Test command blocking from settings.json
# Tests that dangerous commands are blocked by settings.json Bash deny patterns

# Load bats libraries
load '/usr/local/lib/bats/bats-support/load'
load '/usr/local/lib/bats/bats-assert/load'
load '/usr/local/lib/bats/bats-file/load'

# Load custom helpers
load '../helpers/assertions'

# Set REPO_ROOT and SETTINGS_FILE
REPO_ROOT="${REPO_ROOT:-/workspaces/claude-config}"
SETTINGS_FILE="$REPO_ROOT/.claude/settings.json"

# Base64 Decode Tests

@test "blocks base64 -d command" {
  run check_command_blocked "base64 -d secret.txt"
  assert_success
  assert_output --partial "denied"
}

@test "blocks base64 --decode command" {
  run check_command_blocked "base64 --decode secret.txt"
  assert_success
  assert_output --partial "denied"
}

@test "blocks base64 -D command (BSD variant)" {
  run check_command_blocked "base64 -D secret.txt"
  assert_success
  assert_output --partial "denied"
}

@test "allows base64 encode" {
  run check_command_blocked "echo 'test' | base64"
  assert_failure
}

@test "allows base64 without decode flag" {
  run check_command_blocked "base64 file.txt"
  assert_failure
}

# OpenSSL Tests

@test "blocks openssl enc -d command" {
  run check_command_blocked "openssl enc -d -aes-256-cbc -in encrypted.bin"
  assert_success
  assert_output --partial "denied"
}

@test "blocks openssl pkcs12 command" {
  run check_command_blocked "openssl pkcs12 -in cert.p12"
  assert_success
  assert_output --partial "denied"
}

@test "allows openssl genrsa (key generation)" {
  run check_command_blocked "openssl genrsa -out key.pem 2048"
  assert_failure
}

@test "allows openssl req (certificate request)" {
  run check_command_blocked "openssl req -new -key key.pem"
  assert_failure
}

# GPG Tests

@test "blocks gpg -d command" {
  run check_command_blocked "gpg -d encrypted.gpg"
  assert_success
  assert_output --partial "denied"
}

@test "blocks gpg --decrypt command" {
  run check_command_blocked "gpg --decrypt encrypted.gpg"
  assert_success
  assert_output --partial "denied"
}

@test "allows gpg encrypt" {
  run check_command_blocked "gpg --encrypt -r user@example.com file.txt"
  assert_failure
}

@test "allows gpg --list-keys" {
  run check_command_blocked "gpg --list-keys"
  assert_failure
}

# Printenv Tests

@test "blocks printenv command" {
  run check_command_blocked "printenv"
  assert_success
  assert_output --partial "denied"
}

@test "blocks printenv with variable name" {
  run check_command_blocked "printenv SECRET_KEY"
  assert_success
  assert_output --partial "denied"
}

@test "allows echo (not printenv)" {
  run check_command_blocked "echo 'test'"
  assert_failure
}

# SOPS Tests

@test "blocks sops -d command" {
  run check_command_blocked "sops -d secrets.yaml"
  assert_success
  assert_output --partial "denied"
}

@test "blocks sops --decrypt command" {
  run check_command_blocked "sops --decrypt secrets.yaml"
  assert_success
  assert_output --partial "denied"
}

@test "blocks sops exec-env command" {
  run check_command_blocked "sops exec-env secrets.yaml 'printenv'"
  assert_success
  assert_output --partial "denied"
}

@test "blocks sops exec-file command" {
  run check_command_blocked "sops exec-file secrets.yaml 'cat {}'"
  assert_success
  assert_output --partial "denied"
}

@test "allows sops --version" {
  run check_command_blocked "sops --version"
  assert_failure
}

@test "allows sops updatekeys" {
  run check_command_blocked "sops updatekeys secrets.yaml"
  assert_failure
}

@test "allows sops encrypt" {
  run check_command_blocked "sops -e secrets.yaml"
  assert_failure
}

# Age Tests

@test "blocks age -d command" {
  run check_command_blocked "age -d encrypted.age"
  assert_success
  assert_output --partial "denied"
}

@test "blocks age --decrypt command" {
  run check_command_blocked "age --decrypt encrypted.age"
  assert_success
  assert_output --partial "denied"
}

@test "allows age encrypt" {
  run check_command_blocked "age -r recipient key.txt"
  assert_failure
}

@test "allows age-keygen" {
  run check_command_blocked "age-keygen"
  assert_failure
}

# Settings validation tests

@test "settings.json contains Bash command blocks" {
  [ -f "$SETTINGS_FILE" ]

  # Check that settings.json has Bash deny patterns
  run jq -r '.permissions.deny[] | select(startswith("Bash"))' "$SETTINGS_FILE"
  assert_success
  assert_output --partial "Bash"
}

# Compound command tests (commands in pipelines should still be blocked)

@test "blocks base64 decode in pipeline" {
  run check_command_blocked "cat secret.txt | base64 -d"
  assert_success
  assert_output --partial "denied"
}

@test "blocks printenv in pipeline" {
  run check_command_blocked "printenv | grep SECRET"
  assert_success
  assert_output --partial "denied"
}

# Chained command tests - dangerous command in middle or end of chain

@test "blocks base64 -d chained with && at end" {
  run check_command_blocked "ls && base64 -d secret.txt"
  assert_success
  assert_output --partial "denied"
}

@test "blocks gpg --decrypt chained with && at end" {
  run check_command_blocked "cd /tmp && gpg --decrypt secrets.gpg"
  assert_success
  assert_output --partial "denied"
}

@test "blocks sops -d chained with && in middle" {
  run check_command_blocked "ls && sops -d secrets.yaml && echo done"
  assert_success
  assert_output --partial "denied"
}

@test "blocks printenv chained with || at end" {
  run check_command_blocked "cat file.txt || printenv"
  assert_success
  assert_output --partial "denied"
}

@test "blocks base64 --decode chained with ; at end" {
  run check_command_blocked "echo test; base64 --decode secret.txt"
  assert_success
  assert_output --partial "denied"
}

@test "blocks sops --decrypt chained with ; in middle" {
  run check_command_blocked "cd /home; sops --decrypt file.yaml; ls"
  assert_success
  assert_output --partial "denied"
}

@test "blocks age -d chained with && after multiple commands" {
  run check_command_blocked "mkdir -p /tmp/work && cd /tmp/work && age -d encrypted.age"
  assert_success
  assert_output --partial "denied"
}

@test "blocks openssl enc -d chained with mixed operators" {
  run check_command_blocked "ls && cd /tmp || openssl enc -d -aes-256-cbc -in file.enc"
  assert_success
  assert_output --partial "denied"
}

# Command substitution tests

@test "blocks base64 -d in command substitution" {
  run check_command_blocked 'echo $(base64 -d secret.txt)'
  assert_success
  assert_output --partial "denied"
}

@test "blocks sops -d in command substitution" {
  run check_command_blocked 'export SECRET=$(sops -d secrets.yaml)'
  assert_success
  assert_output --partial "denied"
}

@test "blocks gpg -d in backtick substitution" {
  run check_command_blocked 'echo `gpg -d secret.gpg`'
  assert_success
  assert_output --partial "denied"
}

# Subshell tests

@test "blocks printenv in subshell" {
  run check_command_blocked "(printenv | grep SECRET)"
  assert_success
  assert_output --partial "denied"
}

@test "blocks base64 -d in subshell after &&" {
  run check_command_blocked "ls && (cd /tmp && base64 -d file.txt)"
  assert_success
  assert_output --partial "denied"
}

# Here-document and redirection edge cases

@test "blocks base64 -d with input redirection" {
  run check_command_blocked "base64 -d < encoded.txt"
  assert_success
  assert_output --partial "denied"
}

@test "blocks gpg --decrypt with output redirection" {
  run check_command_blocked "ls && gpg --decrypt file.gpg > output.txt"
  assert_success
  assert_output --partial "denied"
}

# Multiple pipes with dangerous command in middle

@test "blocks sops -d in middle of pipeline" {
  run check_command_blocked "cat file.enc | sops -d /dev/stdin | jq ."
  assert_success
  assert_output --partial "denied"
}

# Negative tests - safe chained commands should not be blocked

@test "allows safe commands chained with &&" {
  run check_command_blocked "ls && git status && echo done"
  assert_failure
}

@test "allows safe commands chained with ;" {
  run check_command_blocked "cd /tmp; ls; pwd"
  assert_failure
}

@test "allows safe commands in subshell" {
  run check_command_blocked "(cd /tmp && ls -la)"
  assert_failure
}

# Edge cases

@test "blocks commands with additional arguments" {
  run check_command_blocked "base64 -d --ignore-garbage secret.txt"
  assert_success
  assert_output --partial "denied"
}

@test "blocks commands regardless of path" {
  run check_command_blocked "/usr/bin/base64 -d secret.txt"
  assert_success
  assert_output --partial "denied"
}

# Negative tests - safe commands should not be blocked

@test "allows cat command" {
  run check_command_blocked "cat file.txt"
  assert_failure
}

@test "allows grep command" {
  run check_command_blocked "grep 'pattern' file.txt"
  assert_failure
}

@test "allows ls command" {
  run check_command_blocked "ls -la"
  assert_failure
}

@test "allows git commands" {
  run check_command_blocked "git status"
  assert_failure
}

@test "allows npm commands" {
  run check_command_blocked "npm install"
  assert_failure
}

@test "allows docker commands" {
  run check_command_blocked "docker ps"
  assert_failure
}
