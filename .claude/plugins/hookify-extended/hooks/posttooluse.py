#!/usr/bin/env python3
"""PostToolUse hook executor for hookify-extended.

Evaluates warning rules after tool execution.
Supports rate limiting via warn_once and warn_interval.
Uses stderr + exit 2 to ensure messages reach Claude (fix for #12446).
"""

import json
import sys
from pathlib import Path

# Add core module to path
PLUGIN_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PLUGIN_ROOT))

from core import load_rules, RuleEngine, WarningState


def get_rules_dir() -> Path:
    """Get the .claude directory containing hookify rules."""
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        claude_dir = parent / ".claude"
        if claude_dir.is_dir():
            return claude_dir
    return cwd / ".claude"


def main():
    """Main entry point for PostToolUse hook."""
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    # Map tool to event type
    if tool_name in ("Read", "Write", "Edit", "MultiEdit"):
        event = "file"
    elif tool_name == "Bash":
        event = "bash"
    else:
        event = "all"

    # Build hook input for rule engine
    hook_input = {
        "hook_event_name": "PostToolUse",
        "tool_name": tool_name,
        "tool_input": tool_input,
    }

    # Load and evaluate rules
    rules_dir = get_rules_dir()
    rules = load_rules(event=event, rules_dir=str(rules_dir), include_disabled=False)

    # Filter to only warning rules
    warn_rules = [r for r in rules if r.action == "warn"]

    if not warn_rules:
        sys.exit(0)

    # Initialize state for rate limiting
    state = WarningState()

    # Evaluate which rules match
    engine = RuleEngine()
    matching_rules = []

    for rule in warn_rules:
        # Check if rule matches
        test_result = engine.evaluate_rules([rule], hook_input)
        if test_result.get("systemMessage"):
            # Rule matched - record it and check rate limit
            if state.should_warn(rule):
                matching_rules.append(rule)
            state.record_match(rule)

    if not matching_rules:
        sys.exit(0)

    # Build combined message
    messages = [f"**[{r.name}]**\n{r.message}" for r in matching_rules]
    combined_message = "\n\n".join(messages)

    # Send to Claude via stderr + exit 2
    print(combined_message, file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
