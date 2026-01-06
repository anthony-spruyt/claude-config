#!/usr/bin/env bash

# Helper functions for security control testing
#
# PATTERN MATCHING ENGINES:
# =========================
# These helpers use the ACTUAL matching engines, not simulations:
#
# 1. File patterns (Read, Edit) - git check-ignore (gitignore semantics)
# 2. Hookify patterns - Python re module (PCRE regex)
# 3. Bash command patterns - prefix matching with shell parsing
#
# References:
# - gitignore: https://git-scm.com/docs/gitignore
# - Python re: https://docs.python.org/3/library/re.html

# =============================================================================
# FILE PERMISSION CHECKS (using Python pathspec for gitignore semantics)
# =============================================================================

# Check if file would be denied by gitignore-style patterns in settings.json
# Uses Python pathspec library for accurate gitignore matching
# Returns 0 (success) if file is DENIED, 1 if ALLOWED
check_file_would_be_denied() {
  local file_path="$1"

  if ! command -v jq &>/dev/null; then
    echo "jq not found"
    return 2
  fi

  # Extract ./**/ patterns from settings.json
  local patterns
  patterns=$(jq -r '.permissions.deny[]
    | select(startswith("Read"))
    | capture("Read\\((?<p>.*)\\)").p
    | select(startswith("./"))' "$SETTINGS_FILE" 2>/dev/null)

  if [ -z "$patterns" ]; then
    echo "No relative file patterns found"
    return 2
  fi

  # Use Python pathspec for gitignore matching
  python3 -c "
import sys
import pathspec

patterns_text = sys.argv[1]
file_path = sys.argv[2]

# Parse patterns (remove ./ prefix, pathspec handles ** correctly)
patterns = [p.lstrip('./') for p in patterns_text.strip().split('\n') if p.strip()]

# Create pathspec with gitignore-style matching
spec = pathspec.PathSpec.from_lines('gitwildmatch', patterns)

# Extract just the filename/relative path portion for matching
# For absolute paths, we match against the basename and parent components
import os
# Try matching against various path representations
paths_to_check = [
    file_path,
    os.path.basename(file_path),
    # Also check the path after the last component that might be a project root
]

# Add relative portions: /tmp/x/.ssh/id_rsa -> .ssh/id_rsa, id_rsa
parts = file_path.split('/')
for i in range(len(parts)):
    paths_to_check.append('/'.join(parts[i:]))

for path in paths_to_check:
    if spec.match_file(path):
        print(f'denied by gitignore pattern')
        sys.exit(0)

sys.exit(1)
" "$patterns" "$file_path" 2>/dev/null
}

# Check if absolute path would be denied by ~/ patterns
# Uses Python pathspec with expanded home directory
# Returns 0 (success) if file is DENIED, 1 if ALLOWED
check_file_would_be_denied_absolute() {
  local file_path="$1"

  if ! command -v jq &>/dev/null; then
    echo "jq not found"
    return 2
  fi

  # Extract ~/ patterns from settings.json
  local patterns
  patterns=$(jq -r '.permissions.deny[]
    | select(startswith("Read"))
    | capture("Read\\((?<p>.*)\\)").p
    | select(startswith("~/"))' "$SETTINGS_FILE" 2>/dev/null)

  if [ -z "$patterns" ]; then
    echo "No home directory patterns found"
    return 2
  fi

  # Use Python pathspec for gitignore matching
  python3 -c "
import sys
import os
import pathspec

patterns_text = sys.argv[1]
file_path = sys.argv[2]
home = os.path.expanduser('~')

# Expand ~ to home directory in patterns
patterns = []
for p in patterns_text.strip().split('\n'):
    if p.strip():
        # Replace ~/ with actual home path, then make it a glob pattern
        expanded = p.replace('~/', home + '/')
        patterns.append(expanded)

# Create pathspec with gitignore-style matching
spec = pathspec.PathSpec.from_lines('gitwildmatch', patterns)

if spec.match_file(file_path):
    print('denied by gitignore pattern')
    sys.exit(0)

sys.exit(1)
" "$patterns" "$file_path" 2>/dev/null
}

# Backward compatibility
check_file_permission_denied() {
  check_file_would_be_denied "$1"
}

# =============================================================================
# BASH COMMAND CHECKS (parse command, check each subcommand against patterns)
# =============================================================================

# Get all Bash deny patterns from settings.json as array
# Returns newline-separated list of command prefixes
get_bash_deny_patterns() {
  jq -r '.permissions.deny[]
    | select(startswith("Bash"))
    | capture("Bash\\((?<p>[^:)]+)").p' "$SETTINGS_FILE" 2>/dev/null
}

# Parse shell command into individual subcommands
# Splits on: && || ; | $() ``
# Returns newline-separated list of commands
parse_shell_commands() {
  local input="$1"

  # Use Python for reliable shell parsing
  python3 -c "
import re
import sys

cmd = sys.argv[1]

# Replace command substitutions with newlines to extract inner commands
# Handle \$(...) - extract content
cmd = re.sub(r'\\\$\\(([^)]+)\\)', r'\\n\\1\\n', cmd)
# Handle backticks - extract content
cmd = re.sub(r'\`([^\`]+)\`', r'\\n\\1\\n', cmd)
# Handle subshells (...) - extract content
cmd = re.sub(r'\\(([^)]+)\\)', r'\\n\\1\\n', cmd)

# Split on shell operators
parts = re.split(r'\\s*(?:&&|\\|\\||;|\\|)\\s*', cmd)

# Clean and output
for part in parts:
    part = part.strip()
    if part:
        print(part)
" "$input" 2>/dev/null
}

# Check if a single command matches any deny pattern
# Returns 0 if blocked, 1 if allowed
check_single_command_blocked() {
  local cmd="$1"
  local patterns="$2"

  # Strip leading path from command (e.g., /usr/bin/base64 -> base64)
  local cmd_base
  cmd_base="${cmd##*/}"

  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue

    # Check if command starts with pattern (prefix match)
    if [[ "$cmd" == "$pattern"* ]] || [[ "$cmd_base" == "$pattern"* ]]; then
      return 0
    fi

    # Also check after common prefixes like sudo, env, etc.
    local stripped_cmd
    stripped_cmd=$(echo "$cmd" | sed -E 's/^(sudo|env|nohup|time|nice)\s+//')
    if [[ "$stripped_cmd" == "$pattern"* ]]; then
      return 0
    fi
  done <<<"$patterns"

  return 1
}

# Check if command (possibly chained) would be blocked by settings.json
# Parses command to extract all subcommands and checks each
# Returns 0 (success) if ANY subcommand is BLOCKED, 1 if all ALLOWED
check_command_blocked() {
  local command="$1"

  if ! command -v jq &>/dev/null; then
    echo "jq not found"
    return 2
  fi

  if ! command -v python3 &>/dev/null; then
    echo "python3 not found"
    return 2
  fi

  # Get deny patterns
  local patterns
  patterns=$(get_bash_deny_patterns)

  if [ -z "$patterns" ]; then
    echo "No bash deny patterns found"
    return 2
  fi

  # Parse command into subcommands
  local subcommands
  subcommands=$(parse_shell_commands "$command")

  # Check each subcommand
  while IFS= read -r subcmd; do
    [ -z "$subcmd" ] && continue

    if check_single_command_blocked "$subcmd" "$patterns"; then
      echo "denied"
      return 0
    fi
  done <<<"$subcommands"

  return 1
}

# =============================================================================
# HOOKIFY PATTERN CHECKS (using Python re module for PCRE regex)
# =============================================================================

# Test if input matches a Python regex pattern
# Uses actual Python re module for accurate matching
# Returns 0 if MATCHES, 1 if no match
matches_python_regex() {
  local pattern="$1"
  local input="$2"

  python3 -c "
import re
import sys

pattern = sys.argv[1]
text = sys.argv[2]

if re.search(pattern, text):
    sys.exit(0)
else:
    sys.exit(1)
" "$pattern" "$input" 2>/dev/null
}

# Test if command matches hookify pattern (Python regex)
# Returns 0 (success) if command MATCHES (would be blocked), 1 if no match
matches_hookify_pattern() {
  local pattern="$1"
  local command="$2"

  if [ -z "$pattern" ] || [ -z "$command" ]; then
    return 1
  fi

  matches_python_regex "$pattern" "$command"
}

# =============================================================================
# HOOKIFY RULE FILE HELPERS
# =============================================================================

# Extract field from hookify rule YAML frontmatter
_extract_hookify_field() {
  local rule_file="$1"
  local field="$2"

  if [ ! -f "$rule_file" ]; then
    echo "Rule file not found: $rule_file"
    return 1
  fi

  sed -n '/^---$/,/^---$/p' "$rule_file" | grep "^${field}:" | cut -d: -f2- | sed 's/^ *//'
}

extract_hookify_pattern() {
  _extract_hookify_field "$1" "pattern"
}

extract_hookify_enabled() {
  _extract_hookify_field "$1" "enabled"
}

extract_hookify_name() {
  _extract_hookify_field "$1" "name"
}

extract_hookify_event() {
  _extract_hookify_field "$1" "event"
}

extract_hookify_action() {
  _extract_hookify_field "$1" "action"
}

# Validate hookify frontmatter structure
# Returns 0 if valid, 1 if invalid
validate_hookify_frontmatter() {
  local rule_file="$1"

  if [ ! -f "$rule_file" ]; then
    echo "Rule file not found: $rule_file"
    return 1
  fi

  local frontmatter
  frontmatter=$(sed -n '/^---$/,/^---$/p' "$rule_file")

  # Required fields
  echo "$frontmatter" | grep -q '^name:' || {
    echo "Missing 'name' field"
    return 1
  }
  echo "$frontmatter" | grep -q '^enabled:' || {
    echo "Missing 'enabled' field"
    return 1
  }
  echo "$frontmatter" | grep -q '^event:' || {
    echo "Missing 'event' field"
    return 1
  }
  echo "$frontmatter" | grep -q '^action:' || {
    echo "Missing 'action' field"
    return 1
  }

  # Must have pattern OR conditions
  if ! echo "$frontmatter" | grep -q '^pattern:' && ! echo "$frontmatter" | grep -q '^conditions:'; then
    echo "Missing 'pattern' or 'conditions' field"
    return 1
  fi

  return 0
}

# Count hookify rules in .claude directory
count_hookify_rules() {
  find "$REPO_ROOT/.claude" -name 'hookify.*.local.md' 2>/dev/null | wc -l
}

# Get all hookify rule files
get_hookify_rules() {
  find "$REPO_ROOT/.claude" -name 'hookify.*.local.md' -type f 2>/dev/null | sort
}
