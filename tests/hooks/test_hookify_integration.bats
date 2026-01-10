#!/usr/bin/env bats

# Integration tests for hookify rules
# Uses actual hookify implementation to test rules with JSON input/output

# Load bats libraries
load '/usr/local/lib/bats/bats-support/load'
load '/usr/local/lib/bats/bats-assert/load'

# Set REPO_ROOT
REPO_ROOT="${REPO_ROOT:-/workspaces/claude-config}"

@test "hookify integration: all test cases pass" {
  # Run the Python test runner with the test cases YAML
  run python3 "$REPO_ROOT/tests/helpers/run_hookify_tests.py" \
      "$REPO_ROOT/tests/hooks/hookify_test_cases.yaml" \
      --rules-dir "$REPO_ROOT/.claude" \
      --verbose
  assert_success
}

@test "hookify integration: hookify package is importable" {
  # Verify the hookify package can be imported
  run python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT/.claude/lib')
from common_hookify import load_rules, RuleEngine
print('Import successful')
"
  assert_success
  assert_output --partial "Import successful"
}

@test "hookify integration: rules load from .claude directory" {
  # Verify rules can be loaded
  run python3 -c "
import sys
sys.path.insert(0, '$REPO_ROOT/.claude/lib')
from common_hookify import load_rules

rules = load_rules(event='bash', rules_dir='$REPO_ROOT/.claude', include_disabled=True)
print(f'Loaded {len(rules)} bash rules')
assert len(rules) > 0, 'No rules loaded'
"
  assert_success
  assert_output --partial "Loaded"
}

@test "hookify integration: block action returns permissionDecision deny" {
  # Test that a blocking rule returns the correct JSON structure
  run python3 -c "
import sys
import json
sys.path.insert(0, '$REPO_ROOT/.claude/lib')
from common_hookify import load_rules, RuleEngine

rules = load_rules(event='bash', rules_dir='$REPO_ROOT/.claude', include_disabled=True)
engine = RuleEngine()

# Test a command that should be blocked
input_data = {
    'hook_event_name': 'PreToolUse',
    'tool_name': 'Bash',
    'tool_input': {'command': 'sops -d secrets.yaml'}
}

result = engine.evaluate_rules(rules, input_data)
print(json.dumps(result, indent=2))

# Verify block structure
assert 'hookSpecificOutput' in result, 'Missing hookSpecificOutput'
assert result['hookSpecificOutput']['permissionDecision'] == 'deny', 'Not denied'
print('Block structure verified')
"
  assert_success
  assert_output --partial "permissionDecision"
  assert_output --partial "deny"
}

@test "hookify integration: warn action returns systemMessage only" {
  # Test that a warning rule returns systemMessage without denial
  run python3 -c "
import sys
import json
sys.path.insert(0, '$REPO_ROOT/.claude/lib')
from common_hookify import load_rules, RuleEngine

rules = load_rules(event='bash', rules_dir='$REPO_ROOT/.claude', include_disabled=True)
engine = RuleEngine()

# Test a command that should warn
input_data = {
    'hook_event_name': 'PreToolUse',
    'tool_name': 'Bash',
    'tool_input': {'command': 'cat README.md'}
}

result = engine.evaluate_rules(rules, input_data)
print(json.dumps(result, indent=2))

# Verify warn structure (has systemMessage, no permissionDecision)
assert 'systemMessage' in result, 'Missing systemMessage'
assert 'hookSpecificOutput' not in result or result.get('hookSpecificOutput', {}).get('permissionDecision') != 'deny', 'Should not deny'
print('Warn structure verified')
"
  assert_success
  assert_output --partial "systemMessage"
}

@test "hookify integration: allow returns empty dict" {
  # Test that a non-matching command returns empty dict
  run python3 -c "
import sys
import json
sys.path.insert(0, '$REPO_ROOT/.claude/lib')
from common_hookify import load_rules, RuleEngine

rules = load_rules(event='bash', rules_dir='$REPO_ROOT/.claude', include_disabled=True)
engine = RuleEngine()

# Test a command that should be allowed
input_data = {
    'hook_event_name': 'PreToolUse',
    'tool_name': 'Bash',
    'tool_input': {'command': 'echo hello world'}
}

result = engine.evaluate_rules(rules, input_data)
print(json.dumps(result))

assert result == {}, f'Expected empty dict, got {result}'
print('Allow structure verified')
"
  assert_success
  assert_output --partial "{}"
}
