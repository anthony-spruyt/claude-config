#!/usr/bin/env bats

# Integration tests for hookify-plus warn_once and warn_interval rate limiting
# Tests the WarningState class and full PostToolUse hook flow

# Load bats libraries
load '/usr/local/lib/bats/bats-support/load'
load '/usr/local/lib/bats/bats-assert/load'

# Set REPO_ROOT
REPO_ROOT="${REPO_ROOT:-/workspaces/claude-config}"

# Find hookify plugin path (installed or local)
find_hookify_plugin() {
  local home="$HOME"
  local path=$(ls -d "$home/.claude/plugins/cache/hookify-plus-local/hookify-plus/"*/ 2>/dev/null | tail -1)
  if [[ -n "$path" ]]; then echo "$path"; return; fi
  path=$(ls -d "$home/.claude/plugins/cache/"*/hookify-plus/*/ 2>/dev/null | tail -1)
  if [[ -n "$path" ]]; then echo "$path"; return; fi
  echo ""
}

HOOKIFY_PATH=$(find_hookify_plugin)

# Clean up any test state files before and after each test
setup() {
  rm -f /tmp/claude-hookify-state-test_session*.json
  rm -f /tmp/claude-hookify-state-test_session*.tmp
}

teardown() {
  rm -f /tmp/claude-hookify-state-test_session*.json
  rm -f /tmp/claude-hookify-state-test_session*.tmp
}

# --- WarningState unit tests ---

@test "warn_once: first match returns should_warn=True" {
  [[ -n "$HOOKIFY_PATH" ]] || skip "hookify-plus plugin not installed"
  run python3 -c "
import sys
sys.path.insert(0, '$HOOKIFY_PATH')
from core.config_loader import Rule, Condition
from core.state import WarningState

# Create a warn_once rule
rule = Rule(
    name='test-warn-once',
    enabled=True,
    event='bash',
    conditions=[Condition(field='command', operator='regex_match', pattern='cat\s+')],
    action='warn',
    message='Use Read tool',
    warn_once=True,
    warn_interval=0
)

# First check - should warn (no prior matches)
state = WarningState('test_session_wo1')
assert state.should_warn(rule) == True, 'First match should return True'
print('PASS: first match returns should_warn=True')
"
  assert_success
  assert_output --partial "PASS"
}

@test "warn_once: second match returns should_warn=False" {
  [[ -n "$HOOKIFY_PATH" ]] || skip "hookify-plus plugin not installed"
  run python3 -c "
import sys
sys.path.insert(0, '$HOOKIFY_PATH')
from core.config_loader import Rule, Condition
from core.state import WarningState

rule = Rule(
    name='test-warn-once',
    enabled=True,
    event='bash',
    conditions=[Condition(field='command', operator='regex_match', pattern='cat\s+')],
    action='warn',
    message='Use Read tool',
    warn_once=True,
    warn_interval=0
)

# First match - record it
state = WarningState('test_session_wo2')
assert state.should_warn(rule) == True, 'First should be True'
state.record_match(rule)

# Second match - should be suppressed
assert state.should_warn(rule) == False, 'Second match should return False'
print('PASS: second match returns should_warn=False')
"
  assert_success
  assert_output --partial "PASS"
}

@test "warn_once: state persists across WarningState instances" {
  [[ -n "$HOOKIFY_PATH" ]] || skip "hookify-plus plugin not installed"
  run python3 -c "
import sys
sys.path.insert(0, '$HOOKIFY_PATH')
from core.config_loader import Rule, Condition
from core.state import WarningState

rule = Rule(
    name='test-warn-once',
    enabled=True,
    event='bash',
    conditions=[Condition(field='command', operator='regex_match', pattern='cat\s+')],
    action='warn',
    message='Use Read tool',
    warn_once=True,
    warn_interval=0
)

# Record a match with first instance
state1 = WarningState('test_session_wo3')
assert state1.should_warn(rule) == True, 'First instance should warn'
state1.record_match(rule)

# New instance with same session_id should see persisted state
state2 = WarningState('test_session_wo3')
assert state2.should_warn(rule) == False, 'New instance should see persisted state'
print('PASS: state persists across instances')
"
  assert_success
  assert_output --partial "PASS"
}

@test "warn_once: different rules track independently" {
  [[ -n "$HOOKIFY_PATH" ]] || skip "hookify-plus plugin not installed"
  run python3 -c "
import sys
sys.path.insert(0, '$HOOKIFY_PATH')
from core.config_loader import Rule, Condition
from core.state import WarningState

rule_a = Rule(
    name='test-rule-a',
    enabled=True,
    event='bash',
    conditions=[Condition(field='command', operator='regex_match', pattern='cat\s+')],
    action='warn',
    message='Use Read tool',
    warn_once=True,
)

rule_b = Rule(
    name='test-rule-b',
    enabled=True,
    event='bash',
    conditions=[Condition(field='command', operator='regex_match', pattern='find\s+')],
    action='warn',
    message='Use Glob tool',
    warn_once=True,
)

state = WarningState('test_session_wo4')

# Record match for rule_a only
assert state.should_warn(rule_a) == True
state.record_match(rule_a)

# rule_a should be suppressed, rule_b should still warn
assert state.should_warn(rule_a) == False, 'rule_a should be suppressed'
assert state.should_warn(rule_b) == True, 'rule_b should still warn (independent)'
print('PASS: different rules track independently')
"
  assert_success
  assert_output --partial "PASS"
}

# --- warn_interval tests ---

@test "warn_interval: warns at correct intervals" {
  [[ -n "$HOOKIFY_PATH" ]] || skip "hookify-plus plugin not installed"
  run python3 -c "
import sys
sys.path.insert(0, '$HOOKIFY_PATH')
from core.config_loader import Rule, Condition
from core.state import WarningState

rule = Rule(
    name='test-warn-interval',
    enabled=True,
    event='bash',
    conditions=[Condition(field='command', operator='regex_match', pattern='cat\s+')],
    action='warn',
    message='Interval warning',
    warn_once=False,
    warn_interval=3
)

state = WarningState('test_session_wi1')

# Match 0: should warn (0 % 3 == 0)
assert state.should_warn(rule) == True, 'Match 0 should warn'
state.record_match(rule)

# Match 1: should NOT warn (1 % 3 != 0)
assert state.should_warn(rule) == False, 'Match 1 should NOT warn'
state.record_match(rule)

# Match 2: should NOT warn (2 % 3 != 0)
assert state.should_warn(rule) == False, 'Match 2 should NOT warn'
state.record_match(rule)

# Match 3: should warn again (3 % 3 == 0)
assert state.should_warn(rule) == True, 'Match 3 should warn again'
state.record_match(rule)

# Match 4: should NOT warn (4 % 3 != 0)
assert state.should_warn(rule) == False, 'Match 4 should NOT warn'
state.record_match(rule)

# Match 5: should NOT warn (5 % 3 != 0)
assert state.should_warn(rule) == False, 'Match 5 should NOT warn'
state.record_match(rule)

# Match 6: should warn (6 % 3 == 0)
assert state.should_warn(rule) == True, 'Match 6 should warn'

print('PASS: warns at correct intervals (every 3rd match)')
"
  assert_success
  assert_output --partial "PASS"
}

@test "warn_interval: no rate limiting when interval is 0" {
  [[ -n "$HOOKIFY_PATH" ]] || skip "hookify-plus plugin not installed"
  run python3 -c "
import sys
sys.path.insert(0, '$HOOKIFY_PATH')
from core.config_loader import Rule, Condition
from core.state import WarningState

rule = Rule(
    name='test-no-limit',
    enabled=True,
    event='bash',
    conditions=[Condition(field='command', operator='regex_match', pattern='cat\s+')],
    action='warn',
    message='Always warn',
    warn_once=False,
    warn_interval=0
)

state = WarningState('test_session_wi2')

# Every match should warn
for i in range(5):
    assert state.should_warn(rule) == True, f'Match {i} should always warn'
    state.record_match(rule)

print('PASS: no rate limiting when interval is 0')
"
  assert_success
  assert_output --partial "PASS"
}

# --- State reset tests ---

@test "reset_warning_state: clears state file" {
  [[ -n "$HOOKIFY_PATH" ]] || skip "hookify-plus plugin not installed"
  run python3 -c "
import sys
import os
sys.path.insert(0, '$HOOKIFY_PATH')
from core.config_loader import Rule, Condition
from core.state import WarningState, reset_warning_state

rule = Rule(
    name='test-warn-once',
    enabled=True,
    event='bash',
    conditions=[Condition(field='command', operator='regex_match', pattern='cat\s+')],
    action='warn',
    message='Use Read tool',
    warn_once=True,
)

# Record a match
state = WarningState('test_session_rs1')
state.record_match(rule)
assert state.should_warn(rule) == False, 'Should be suppressed after match'

# Verify state file exists
state_file = '/tmp/claude-hookify-state-test_session.json'
assert os.path.exists(state_file), f'State file should exist at {state_file}'

# Reset state (simulates Task tool spawning subagent)
reset_warning_state('test_session_rs1')

# After reset, should warn again
state2 = WarningState('test_session_rs1')
assert state2.should_warn(rule) == True, 'Should warn again after reset'
print('PASS: reset clears state and re-enables warnings')
"
  assert_success
  assert_output --partial "PASS"
}

# --- Full PostToolUse hook flow test ---

@test "warn_once: full PostToolUse flow - first match warns, second is silent" {
  [[ -n "$HOOKIFY_PATH" ]] || skip "hookify-plus plugin not installed"
  run python3 -c "
import sys
import os
import json
sys.path.insert(0, '$HOOKIFY_PATH')
os.chdir('$REPO_ROOT')
from core.config_loader import load_rules
from core.rule_engine import RuleEngine
from core.state import WarningState

session_id = 'test_session_ptu'

# Load warn rules
rules = load_rules(event='bash')
warn_rules = [r for r in rules if r.action == 'warn']

# Input that triggers warn-use-read-tool (cat command)
input_data = {
    'hook_event_name': 'PostToolUse',
    'tool_name': 'Bash',
    'tool_input': {'command': 'cat README.md'},
    'session_id': session_id,
}

engine = RuleEngine()

# --- First invocation ---
state1 = WarningState(session_id)
matching_first = []
for rule in warn_rules:
    test_result = engine.evaluate_rules([rule], input_data)
    if test_result.get('systemMessage'):
        if state1.should_warn(rule):
            matching_first.append(rule.name)
        state1.record_match(rule)

assert 'warn-use-read-tool' in matching_first, f'First invocation should warn. Got: {matching_first}'
print(f'First invocation: warned for {matching_first}')

# --- Second invocation (same session) ---
state2 = WarningState(session_id)
matching_second = []
for rule in warn_rules:
    test_result = engine.evaluate_rules([rule], input_data)
    if test_result.get('systemMessage'):
        if state2.should_warn(rule):
            matching_second.append(rule.name)
        state2.record_match(rule)

assert 'warn-use-read-tool' not in matching_second, f'Second invocation should NOT warn. Got: {matching_second}'
print(f'Second invocation: warned for {matching_second} (should be empty or not contain warn-use-read-tool)')

print('PASS: full PostToolUse flow - warn_once works correctly')
"
  assert_success
  assert_output --partial "PASS: full PostToolUse flow"
}
