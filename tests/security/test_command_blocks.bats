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

# Base64 Decode Tests (blocked by hookify with guidance, not settings.json)

@test "base64 -d not in settings.json deny (blocked by hookify)" {
  run check_command_blocked "base64 -d secret.txt"
  assert_failure  # Not in settings.json - hookify handles with guidance
}

@test "base64 --decode not in settings.json deny (blocked by hookify)" {
  run check_command_blocked "base64 --decode secret.txt"
  assert_failure  # Not in settings.json - hookify handles with guidance
}

@test "base64 -D not in settings.json deny (blocked by hookify)" {
  run check_command_blocked "base64 -D secret.txt"
  assert_failure  # Not in settings.json - hookify handles with guidance
}

@test "allows base64 encode" {
  run check_command_blocked "echo 'test' | base64"
  assert_failure
}

@test "allows base64 without decode flag" {
  run check_command_blocked "base64 file.txt"
  assert_failure
}

# OpenSSL Tests (blocked by hookify with guidance, not settings.json)

@test "openssl enc -d not in settings.json deny (blocked by hookify)" {
  run check_command_blocked "openssl enc -d -aes-256-cbc -in encrypted.bin"
  assert_failure  # Not in settings.json - hookify handles with guidance
}

@test "openssl pkcs12 not in settings.json deny (blocked by hookify)" {
  run check_command_blocked "openssl pkcs12 -in cert.p12"
  assert_failure  # Not in settings.json - hookify handles with guidance
}

@test "allows openssl genrsa (key generation)" {
  run check_command_blocked "openssl genrsa -out key.pem 2048"
  assert_failure
}

@test "allows openssl req (certificate request)" {
  run check_command_blocked "openssl req -new -key key.pem"
  assert_failure
}

# GPG Tests (blocked by hookify with guidance, not settings.json)

@test "gpg -d not in settings.json deny (blocked by hookify)" {
  run check_command_blocked "gpg -d encrypted.gpg"
  assert_failure  # Not in settings.json - hookify handles with guidance
}

@test "gpg --decrypt not in settings.json deny (blocked by hookify)" {
  run check_command_blocked "gpg --decrypt encrypted.gpg"
  assert_failure  # Not in settings.json - hookify handles with guidance
}

@test "allows gpg encrypt" {
  run check_command_blocked "gpg --encrypt -r user@example.com file.txt"
  assert_failure
}

@test "allows gpg --list-keys" {
  run check_command_blocked "gpg --list-keys"
  assert_failure
}

# Printenv Tests (blocked by hookify with guidance, not settings.json)

@test "printenv not in settings.json deny (blocked by hookify)" {
  run check_command_blocked "printenv"
  assert_failure  # Not in settings.json - hookify handles with guidance
}

@test "printenv with variable not in settings.json deny (blocked by hookify)" {
  run check_command_blocked "printenv SECRET_KEY"
  assert_failure  # Not in settings.json - hookify handles with guidance
}

@test "allows echo (not printenv)" {
  run check_command_blocked "echo 'test'"
  assert_failure
}

# SOPS Tests (blocked by hookify with guidance, not settings.json)

@test "sops -d not in settings.json deny (blocked by hookify)" {
  run check_command_blocked "sops -d secrets.yaml"
  assert_failure  # Not in settings.json - hookify handles with guidance
}

@test "sops --decrypt not in settings.json deny (blocked by hookify)" {
  run check_command_blocked "sops --decrypt secrets.yaml"
  assert_failure  # Not in settings.json - hookify handles with guidance
}

@test "sops exec-env not in settings.json deny (blocked by hookify)" {
  run check_command_blocked "sops exec-env secrets.yaml 'printenv'"
  assert_failure  # Not in settings.json - hookify handles with guidance
}

@test "sops exec-file not in settings.json deny (blocked by hookify)" {
  run check_command_blocked "sops exec-file secrets.yaml 'cat {}'"
  assert_failure  # Not in settings.json - hookify handles with guidance
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

# Age Tests (blocked by hookify with guidance, not settings.json)

@test "age -d not in settings.json deny (blocked by hookify)" {
  run check_command_blocked "age -d encrypted.age"
  assert_failure  # Not in settings.json - hookify handles with guidance
}

@test "age --decrypt not in settings.json deny (blocked by hookify)" {
  run check_command_blocked "age --decrypt encrypted.age"
  assert_failure  # Not in settings.json - hookify handles with guidance
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

@test "settings.json contains Read file blocks (Bash blocks moved to hookify)" {
  [ -f "$SETTINGS_FILE" ]

  # Check that settings.json has Read deny patterns (Bash patterns now in hookify)
  run jq -r '.permissions.deny[] | select(startswith("Read"))' "$SETTINGS_FILE"
  assert_success
  assert_output --partial "Read"
}

# Note: All Bash command blocks have been moved to hookify rules for better guidance.
# The tests below verify settings.json no longer blocks these (hookify handles them).

# Negative tests - safe commands should not be blocked by settings.json

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
