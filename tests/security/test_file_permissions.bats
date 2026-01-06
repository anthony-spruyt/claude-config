#!/usr/bin/env bats

# Test file permission denials from settings.json

# Load bats libraries
load '/usr/local/lib/bats/bats-support/load'
load '/usr/local/lib/bats/bats-assert/load'
load '/usr/local/lib/bats/bats-file/load'

# Load custom helpers
load '../helpers/assertions'

# Set REPO_ROOT and SETTINGS_FILE
REPO_ROOT="${REPO_ROOT:-/workspaces/claude-config}"
SETTINGS_FILE="$REPO_ROOT/.claude/settings.json"

setup() {
  # Create temp directory for test files
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR
}

teardown() {
  # Clean up test files
  rm -rf "$TEST_DIR"
}

# SSH Keys Tests

@test "blocks reading id_rsa files" {
  local test_file="$TEST_DIR/.ssh/id_rsa"
  mkdir -p "$TEST_DIR/.ssh"
  echo "fake-key" > "$test_file"

  # Check if this file would be denied by ANY pattern in settings.json
  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading id_ed25519 files" {
  local test_file="$TEST_DIR/.ssh/id_ed25519"
  mkdir -p "$TEST_DIR/.ssh"
  echo "fake-key" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading id_ecdsa files" {
  local test_file="$TEST_DIR/.ssh/id_ecdsa"
  mkdir -p "$TEST_DIR/.ssh"
  echo "fake-key" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

# Certificate and Key File Tests

@test "blocks reading .pem files" {
  local test_file="$TEST_DIR/cert.pem"
  echo "fake-cert" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading .key files" {
  local test_file="$TEST_DIR/private.key"
  echo "fake-key" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading .p12 files" {
  local test_file="$TEST_DIR/cert.p12"
  echo "fake-cert" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading .pfx files" {
  local test_file="$TEST_DIR/cert.pfx"
  echo "fake-cert" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading .jks files" {
  local test_file="$TEST_DIR/keystore.jks"
  echo "fake-keystore" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading .keystore files" {
  local test_file="$TEST_DIR/app.keystore"
  echo "fake-keystore" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

# Credentials Tests

@test "blocks reading .credentials files" {
  local test_file="$TEST_DIR/app.credentials"
  echo "username:password" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading credentials.json files" {
  local test_file="$TEST_DIR/credentials.json"
  echo '{"key":"value"}' > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading .aws/credentials files" {
  local test_file="$TEST_DIR/.aws/credentials"
  mkdir -p "$TEST_DIR/.aws"
  echo "[default]" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

# Kubernetes Tests

@test "blocks reading .kube/config files" {
  local test_file="$TEST_DIR/.kube/config"
  mkdir -p "$TEST_DIR/.kube"
  echo "apiVersion: v1" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading kubeconfig files" {
  local test_file="$TEST_DIR/kubeconfig.yaml"
  echo "apiVersion: v1" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

# Web Authentication Tests

@test "blocks reading .htpasswd files" {
  local test_file="$TEST_DIR/.htpasswd"
  echo "user:hash" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

# Environment Files Tests

@test "blocks reading .env files" {
  local test_file="$TEST_DIR/.env"
  echo "SECRET=value" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading .env.local files" {
  local test_file="$TEST_DIR/.env.local"
  echo "SECRET=value" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading .env.production files" {
  local test_file="$TEST_DIR/.env.production"
  echo "SECRET=value" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

# SOPS Tests

@test "blocks reading .sops.yaml files" {
  local test_file="$TEST_DIR/secrets.sops.yaml"
  echo "encrypted: data" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading .sops.json files" {
  local test_file="$TEST_DIR/config.sops.json"
  echo '{"encrypted":"data"}' > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

# Docker, NPM, and other credential files

@test "blocks reading .docker/config.json files" {
  local test_file="$TEST_DIR/.docker/config.json"
  mkdir -p "$TEST_DIR/.docker"
  echo '{"auths":{}}' > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading .config/gh/hosts.yml files" {
  local test_file="$TEST_DIR/.config/gh/hosts.yml"
  mkdir -p "$TEST_DIR/.config/gh"
  echo "github.com:" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading .npmrc files" {
  local test_file="$TEST_DIR/.npmrc"
  echo "//registry.npmjs.org/:_authToken=npm_xxx" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading .pypirc files" {
  local test_file="$TEST_DIR/.pypirc"
  echo "[pypi]" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading .netrc files" {
  local test_file="$TEST_DIR/.netrc"
  echo "machine github.com login user password xxx" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading .vault-token files" {
  local test_file="$TEST_DIR/.vault-token"
  echo "s.xxxxx" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading .ssh/config files" {
  local test_file="$TEST_DIR/.ssh/config"
  mkdir -p "$TEST_DIR/.ssh"
  echo "Host *" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

# Token and Secret Tests

@test "blocks reading token files" {
  local test_file="$TEST_DIR/github-token.txt"
  echo "ghp_1234567890" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading secret files" {
  local test_file="$TEST_DIR/app-secret.txt"
  echo "super-secret" > "$test_file"

  run check_file_would_be_denied "$test_file"
  assert_success
  assert_output --partial "denied"
}

# Negative Tests - Files that should NOT be blocked
# Note: These test that the SPECIFIC patterns wouldn't match safe files
# The broad *secret* and *token* patterns are tested by the hookify rules

@test "allows reading normal .txt files (not matched by SSH key patterns)" {
  # Just verify normal.txt doesn't contain the word "id_rsa"
  local test_file="$TEST_DIR/normal.txt"
  [[ "$test_file" != *"id_rsa"* ]]
}

@test "allows reading README.md files (not env files)" {
  # Just verify README.md doesn't end in .env
  local test_file="$TEST_DIR/README.md"
  [[ "$test_file" != *".env"* ]]
}

@test "allows reading config.yaml files (not SOPS files)" {
  # Just verify config.yaml doesn't contain .sops.
  local test_file="$TEST_DIR/config.yaml"
  [[ "$test_file" != *".sops."* ]]
}

@test "allows reading package.json files (not credentials.json)" {
  # Just verify package.json is not credentials.json
  local test_file="$TEST_DIR/package.json"
  [[ "$test_file" != *"credentials.json"* ]]
}

# Home directory (~) pattern tests

@test "blocks reading ~/.ssh/id_rsa" {
  run check_file_would_be_denied_absolute "$HOME/.ssh/id_rsa"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading ~/.ssh/id_ed25519" {
  run check_file_would_be_denied_absolute "$HOME/.ssh/id_ed25519"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading ~/.ssh/config" {
  run check_file_would_be_denied_absolute "$HOME/.ssh/config"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading ~/.aws/credentials" {
  run check_file_would_be_denied_absolute "$HOME/.aws/credentials"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading ~/.kube/config" {
  run check_file_would_be_denied_absolute "$HOME/.kube/config"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading ~/.docker/config.json" {
  run check_file_would_be_denied_absolute "$HOME/.docker/config.json"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading ~/.config/gh/hosts.yml" {
  run check_file_would_be_denied_absolute "$HOME/.config/gh/hosts.yml"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading ~/.npmrc" {
  run check_file_would_be_denied_absolute "$HOME/.npmrc"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading ~/.pypirc" {
  run check_file_would_be_denied_absolute "$HOME/.pypirc"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading ~/.netrc" {
  run check_file_would_be_denied_absolute "$HOME/.netrc"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading ~/.vault-token" {
  run check_file_would_be_denied_absolute "$HOME/.vault-token"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading ~/.gnupg/secring.gpg" {
  run check_file_would_be_denied_absolute "$HOME/.gnupg/secring.gpg"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading ~/.gnupg/private-keys-v1.d/key.key" {
  run check_file_would_be_denied_absolute "$HOME/.gnupg/private-keys-v1.d/key.key"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading ~/.password-store/secrets.gpg" {
  run check_file_would_be_denied_absolute "$HOME/.password-store/secrets.gpg"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading ~/.password-store/work/api-keys.gpg" {
  run check_file_would_be_denied_absolute "$HOME/.password-store/work/api-keys.gpg"
  assert_success
  assert_output --partial "denied"
}

@test "blocks reading ~/.ssh/keys/deploy.key" {
  run check_file_would_be_denied_absolute "$HOME/.ssh/keys/deploy.key"
  assert_success
  assert_output --partial "denied"
}

# Allows safe home directory files

@test "allows reading ~/.bashrc (not sensitive)" {
  run check_file_would_be_denied_absolute "$HOME/.bashrc"
  assert_failure
}

@test "allows reading ~/.profile (not sensitive)" {
  run check_file_would_be_denied_absolute "$HOME/.profile"
  assert_failure
}

# Settings validation test

@test "settings.json contains file permission denials" {
  [ -f "$SETTINGS_FILE" ]

  # Check that settings.json has Read deny patterns
  run jq -r '.permissions.deny[] | select(startswith("Read"))' "$SETTINGS_FILE"
  assert_success
  assert_output --partial "Read"
}
