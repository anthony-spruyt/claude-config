#!/usr/bin/env bats

# Test agent file format validation

# Load bats libraries
load '/usr/local/lib/bats/bats-support/load'
load '/usr/local/lib/bats/bats-assert/load'

REPO_ROOT="${REPO_ROOT:-/workspaces/claude-config}"
AGENTS_DIR="$REPO_ROOT/.claude/agents"

@test "agents directory exists" {
  [ -d "$AGENTS_DIR" ]
}

@test "agents: at least one common-*.md file exists" {
  run bash -c "ls '$AGENTS_DIR'/common-*.md 2>/dev/null | wc -l"
  assert_success
  [ "$output" -gt 0 ]
}

@test "agents: all common-*.md files start with frontmatter delimiter" {
  for agent in "$AGENTS_DIR"/common-*.md; do
    [ -e "$agent" ] || continue
    run head -1 "$agent"
    assert_output "---"
  done
}

@test "agents: all common-*.md files have name field" {
  for agent in "$AGENTS_DIR"/common-*.md; do
    [ -e "$agent" ] || continue
    run grep -m1 "^name:" "$agent"
    assert_success
  done
}

@test "agents: all common-*.md files have description field" {
  for agent in "$AGENTS_DIR"/common-*.md; do
    [ -e "$agent" ] || continue
    run grep -m1 "^description:" "$agent"
    assert_success
  done
}

@test "agents: all common-*.md files have model field" {
  for agent in "$AGENTS_DIR"/common-*.md; do
    [ -e "$agent" ] || continue
    run grep -m1 "^model:" "$agent"
    assert_success
  done
}

@test "agents: model field has valid value (opus or sonnet)" {
  for agent in "$AGENTS_DIR"/common-*.md; do
    [ -e "$agent" ] || continue
    model=$(grep "^model:" "$agent" | head -1 | sed 's/^model:[[:space:]]*//')
    [[ "$model" == "opus" || "$model" == "sonnet" ]]
  done
}

@test "agents: frontmatter is properly closed" {
  for agent in "$AGENTS_DIR"/common-*.md; do
    [ -e "$agent" ] || continue
    # Count occurrences of --- (should be at least 2 for open and close)
    run bash -c "grep -c '^---$' '$agent'"
    assert_success
    [ "$output" -ge 2 ]
  done
}

@test "agents: description uses escaped newlines for multiline content" {
  for agent in "$AGENTS_DIR"/common-*.md; do
    [ -e "$agent" ] || continue
    # Extract the description line and check it's on a single line (uses \n not actual newlines)
    # The description should be on line 3 (after --- and name:)
    desc_line=$(sed -n '/^description:/p' "$agent" | head -1)
    # If description is multiline, it should contain \n escape sequences
    if [[ "$desc_line" =~ "When to use" ]]; then
      [[ "$desc_line" =~ \\n ]]
    fi
  done
}

@test "agents: no .example files exist for common-* agents" {
  run bash -c "ls '$AGENTS_DIR'/common-*.md.example 2>/dev/null | wc -l"
  # Should be 0 - no example files for common agents
  [ "$output" -eq 0 ] || [ "$status" -ne 0 ]
}

@test "agents: description does NOT use YAML multiline syntax (| or >)" {
  # YAML multiline block scalars (|, >, |-, >-) are NOT supported for descriptions
  # Descriptions must use escaped \n for newlines on a single line
  for agent in "$AGENTS_DIR"/common-*.md; do
    [ -e "$agent" ] || continue
    # Check for YAML block scalar indicators after description:
    run grep -E '^description:\s*[|>]' "$agent"
    # Should NOT find any matches (grep should fail)
    assert_failure "Agent $agent uses YAML multiline syntax in description - use escaped \\n instead"
  done
}

@test "agents: description is on a single line (no YAML multiline)" {
  for agent in "$AGENTS_DIR"/common-*.md; do
    [ -e "$agent" ] || continue
    # Extract frontmatter (between first and second ---)
    frontmatter=$(sed -n '2,/^---$/p' "$agent" | head -n -1)
    # Count how many lines start with description:
    desc_count=$(echo "$frontmatter" | grep -c '^description:' || echo "0")
    # There should be exactly 1 description line
    [ "$desc_count" -eq 1 ]
    # The line after description: should be either model: or --- or another field
    # NOT a continuation of the description (which would indicate YAML multiline)
    line_after_desc=$(echo "$frontmatter" | grep -A1 '^description:' | tail -1)
    # Line after should start with a field name (word:) or be empty
    [[ "$line_after_desc" =~ ^[a-z]+: ]] || [ -z "$line_after_desc" ]
  done
}
