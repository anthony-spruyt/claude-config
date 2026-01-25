#!/usr/bin/env python3
"""PreToolUse hook executor for hookify-extended.

Evaluates blocking rules before tool execution.
Uses stderr + exit 2 to ensure messages reach Claude (fix for #12446).
"""

import json
import sys
from pathlib import Path

# Add core module to path
PLUGIN_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PLUGIN_ROOT))

from core import load_rules, RuleEngine


def get_rules_dir() -> Path:
    """Get the .claude directory containing hookify rules."""
    # Look for .claude in current directory or parents
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        claude_dir = parent / ".claude"
        if claude_dir.is_dir():
            return claude_dir
    return cwd / ".claude"


def main():
    """Main entry point for PreToolUse hook."""
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)  # Invalid input, allow operation

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
        "hook_event_name": "PreToolUse",
        "tool_name": tool_name,
        "tool_input": tool_input,
    }

    # Load and evaluate rules
    rules_dir = get_rules_dir()
    rules = load_rules(event=event, rules_dir=str(rules_dir), include_disabled=False)

    # Filter to only blocking rules
    block_rules = [r for r in rules if r.action == "block"]

    if not block_rules:
        sys.exit(0)  # No blocking rules, allow

    engine = RuleEngine()
    result = engine.evaluate_rules(block_rules, hook_input)

    # Check if any rule blocked
    is_block = result.get("hookSpecificOutput", {}).get("permissionDecision") == "deny"

    if is_block:
        message = result.get("systemMessage", "Blocked by hookify rule")

        # Show to user via /dev/tty (CLI) or stdout (extension)
        try:
            with open("/dev/tty", "w") as tty:
                tty.write(f"\n🚫 BLOCKED: {message}\n")
        except (OSError, IOError):
            print(f"🚫 BLOCKED: {message}")

        # Send to Claude via stderr + exit 2
        print(message, file=sys.stderr)
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
