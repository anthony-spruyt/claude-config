#!/usr/bin/env bash

# Helper functions for security control testing
#
# PATTERN MATCHING REFERENCE:
# ==========================
# Claude Code uses TWO different pattern matching systems:
#
# 1. settings.json permissions (Read, Edit, Bash) - GITIGNORE PATTERNS
#    - * matches anything EXCEPT /
#    - ** matches anything INCLUDING /
#    - ~/ = home directory ($HOME)
#    - ./ = relative to working directory
#    - // = absolute filesystem path
#    Reference: https://git-scm.com/docs/gitignore
#
# 2. hookify rules (pattern: field) - PYTHON/PCRE REGEX
#    - Standard regex: \s \S .* [a-z] (a|b) etc.
#    Reference: https://docs.python.org/3/library/re.html

# Check if file would be denied by ANY pattern in settings.json
# IMPORTANT: This function tests files WITHIN the working directory only.
# The ./**/ patterns in settings.json only apply relative to the working directory.
# For absolute paths outside the repo, use check_file_would_be_denied_absolute().
#
# Uses gitignore pattern matching semantics:
# - * matches anything EXCEPT /
# - ** matches anything INCLUDING /
# - ? matches single character except /
#
# Returns 0 (success) if file is DENIED, 1 if ALLOWED
check_file_would_be_denied() {
  local file_path="$1"

  # Check if jq is available
  if ! command -v jq &> /dev/null; then
    echo "jq not found - install jq to run file permission tests"
    return 2
  fi

  # Read all file Read deny patterns from settings.json
  local denials
  denials=$(jq -r '.permissions.deny[] | select(startswith("Read"))' "$SETTINGS_FILE" 2>/dev/null)

  if [ -z "$denials" ]; then
    echo "No file permissions found in settings.json"
    return 2
  fi

  # Extract just the glob patterns (between parentheses)
  # Format: Read(./**/*id_rsa*) -> ./**/*id_rsa*
  local patterns
  patterns=$(echo "$denials" | grep -oP 'Read\(\K[^)]+')

  # Only process ./**/ patterns (relative to working directory)
  while IFS= read -r pattern; do
    # Skip non-relative patterns (like ~/ patterns)
    [[ "$pattern" != './'* ]] && continue

    # Convert gitignore pattern to regex
    # Gitignore rules:
    # - * matches anything except / -> [^/]*
    # - ** matches anything including / -> .*
    # - ? matches single char except / -> [^/]
    # - . is literal -> \.

    # Strip leading ./ or ./**/ first
    local pattern_regex="${pattern#./}"
    pattern_regex="${pattern_regex#\*\*/}"

    # Escape regex special chars (except * and ?)
    pattern_regex=$(echo "$pattern_regex" | sed 's/\./\\./g' | sed 's/\[/\\[/g' | sed 's/\]/\\]/g')

    # Convert ** to placeholder, then * to [^/]*, then placeholder back to .*
    pattern_regex=$(echo "$pattern_regex" | sed 's/\*\*/\x00/g' | sed 's/\*/[^\/]*/g' | sed 's/\x00/.*/g')

    # Convert ? to [^/]
    pattern_regex=$(echo "$pattern_regex" | sed 's/?/[^\/]/g')

    # Anchor - match anywhere in path (since ./**/ means recursive)
    pattern_regex="(^|/)$pattern_regex(\$|/)"

    if echo "$file_path" | grep -qE "$pattern_regex"; then
      echo "denied by pattern: $pattern"
      return 0
    fi
  done <<< "$patterns"

  # File not blocked by any pattern
  return 1
}

# Backward compatibility wrapper (deprecated)
check_file_permission_denied() {
  check_file_would_be_denied "$1"
}

# Check if absolute file path would be denied by home directory (~) patterns
# IMPORTANT: This only checks ~/ patterns - the ./**/ patterns do NOT apply to
# arbitrary absolute paths, only to files within the working directory.
# Returns 0 (success) if file is DENIED, 1 if ALLOWED
check_file_would_be_denied_absolute() {
  local file_path="$1"

  # Check if jq is available
  if ! command -v jq &> /dev/null; then
    echo "jq not found - install jq to run file permission tests"
    return 2
  fi

  # Read all file Read deny patterns from settings.json
  local denials
  denials=$(jq -r '.permissions.deny[] | select(startswith("Read"))' "$SETTINGS_FILE" 2>/dev/null)

  if [ -z "$denials" ]; then
    echo "No file permissions found in settings.json"
    return 2
  fi

  # Extract patterns from Read(...) format
  local patterns
  patterns=$(echo "$denials" | grep -oP 'Read\(\K[^)]+')

  # Check if the file path would match any of the patterns
  while IFS= read -r pattern; do
    # Only handle home directory patterns (~/...)
    # The ./**/ patterns don't apply to arbitrary absolute paths!
    # shellcheck disable=SC2088 # We're matching literal ~/ string, not expanding
    if [[ "$pattern" == '~/'* ]]; then
      # Expand ~ to actual home directory for comparison
      local expanded_pattern="${pattern/#\~/$HOME}"

      # Handle glob patterns
      # ~/.ssh/* -> /home/user/.ssh/*
      # ~/.ssh/**/* -> /home/user/.ssh/**/*
      # Convert glob to regex
      local pattern_regex

      # Handle ** (recursive match) - replace **/* with .* to match any path
      if [[ "$expanded_pattern" == *'**'* ]]; then
        pattern_regex=$(echo "$expanded_pattern" | sed 's/\./\\./g' | sed 's/\*\*\/\*/.\*/g' | sed 's/\*/[^\/]*/g')
      else
        pattern_regex=$(echo "$expanded_pattern" | sed 's/\./\\./g' | sed 's/\*/[^\/]*/g')
      fi

      if echo "$file_path" | grep -qE "^$pattern_regex"; then
        echo "denied by pattern: $pattern"
        return 0
      fi
    fi
  done <<< "$patterns"

  # File not blocked by any pattern
  return 1
}

# Check if command would be blocked by settings.json
# Returns 0 (success) if command is BLOCKED, 1 if ALLOWED
check_command_blocked() {
  local command="$1"

  # Check if jq is available
  if ! command -v jq &> /dev/null; then
    echo "jq not found - install jq to run command block tests"
    return 2
  fi

  # Read all Bash deny patterns from settings.json
  local denials
  denials=$(jq -r '.permissions.deny[] | select(startswith("Bash"))' "$SETTINGS_FILE" 2>/dev/null)

  if [ -z "$denials" ]; then
    echo "No bash permissions found in settings.json"
    return 2
  fi

  # Extract patterns from Bash(...) format
  # Format: Bash(base64 -d:*) or Bash(sops -d:*)
  local patterns
  patterns=$(echo "$denials" | grep -oP 'Bash\(\K[^:)]+')

  # Check if command matches any pattern
  # The command can appear anywhere in a pipeline or with a full path
  while IFS= read -r pattern; do
    # Escape special regex characters in pattern for literal matching
    local escaped_pattern
    # shellcheck disable=SC2001
    escaped_pattern=$(echo "$pattern" | sed 's/[.[\*^$]/\\&/g')

    # Match pattern at start of command or after pipe/path
    if echo "$command" | grep -qE "(^|[/|[:space:]])$escaped_pattern"; then
      echo "denied"
      return 0
    fi
  done <<< "$patterns"

  # Command not blocked
  return 1
}

# Extract pattern from hookify rule file
extract_hookify_pattern() {
  local rule_file="$1"

  if [ ! -f "$rule_file" ]; then
    echo "Rule file not found: $rule_file"
    return 1
  fi

  # Extract YAML frontmatter between --- lines
  # Then get the pattern field
  sed -n '/^---$/,/^---$/p' "$rule_file" | grep '^pattern:' | cut -d: -f2- | sed 's/^ *//'
}

# Extract enabled status from hookify rule
extract_hookify_enabled() {
  local rule_file="$1"

  if [ ! -f "$rule_file" ]; then
    echo "Rule file not found: $rule_file"
    return 1
  fi

  sed -n '/^---$/,/^---$/p' "$rule_file" | grep '^enabled:' | cut -d: -f2- | sed 's/^ *//'
}

# Extract name from hookify rule
extract_hookify_name() {
  local rule_file="$1"

  if [ ! -f "$rule_file" ]; then
    echo "Rule file not found: $rule_file"
    return 1
  fi

  sed -n '/^---$/,/^---$/p' "$rule_file" | grep '^name:' | cut -d: -f2- | sed 's/^ *//'
}

# Extract event from hookify rule
extract_hookify_event() {
  local rule_file="$1"

  if [ ! -f "$rule_file" ]; then
    echo "Rule file not found: $rule_file"
    return 1
  fi

  sed -n '/^---$/,/^---$/p' "$rule_file" | grep '^event:' | cut -d: -f2- | sed 's/^ *//'
}

# Extract action from hookify rule
extract_hookify_action() {
  local rule_file="$1"

  if [ ! -f "$rule_file" ]; then
    echo "Rule file not found: $rule_file"
    return 1
  fi

  sed -n '/^---$/,/^---$/p' "$rule_file" | grep '^action:' | cut -d: -f2- | sed 's/^ *//'
}

# Test if command matches hookify pattern (uses Perl regex)
# Returns 0 (success) if command MATCHES (should be blocked), 1 if no match
matches_hookify_pattern() {
  local pattern="$1"
  local command="$2"

  if [ -z "$pattern" ] || [ -z "$command" ]; then
    return 1
  fi

  # Use grep with Perl regex for matching
  if echo "$command" | grep -qP "$pattern"; then
    return 0  # Match found - would be blocked
  else
    return 1  # No match
  fi
}

# Validate hookify frontmatter structure
# Returns 0 if valid, 1 if invalid
validate_hookify_frontmatter() {
  local rule_file="$1"

  if [ ! -f "$rule_file" ]; then
    echo "Rule file not found: $rule_file"
    return 1
  fi

  # Extract frontmatter
  local frontmatter
  frontmatter=$(sed -n '/^---$/,/^---$/p' "$rule_file")

  # Check for required fields
  echo "$frontmatter" | grep -q '^name:' || { echo "Missing 'name' field"; return 1; }
  echo "$frontmatter" | grep -q '^enabled:' || { echo "Missing 'enabled' field"; return 1; }
  echo "$frontmatter" | grep -q '^event:' || { echo "Missing 'event' field"; return 1; }
  echo "$frontmatter" | grep -q '^action:' || { echo "Missing 'action' field"; return 1; }

  # Check for pattern OR conditions (bash events use pattern, file events use conditions)
  if ! echo "$frontmatter" | grep -q '^pattern:' && ! echo "$frontmatter" | grep -q '^conditions:'; then
    echo "Missing 'pattern' field"
    return 1
  fi

  return 0
}

# Count hookify rules in .claude directory
count_hookify_rules() {
  find "$REPO_ROOT/.claude" -name 'hookify.*.local.md' | wc -l
}

# Get all hookify rule files
get_hookify_rules() {
  find "$REPO_ROOT/.claude" -name 'hookify.*.local.md' -type f | sort
}
