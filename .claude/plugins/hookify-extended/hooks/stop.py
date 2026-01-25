#!/usr/bin/env python3
"""Stop hook executor for hookify-extended.

Evaluates rules when Claude is about to stop/complete.
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
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        claude_dir = parent / ".claude"
        if claude_dir.is_dir():
            return claude_dir
    return cwd / ".claude"


def main():
    """Main entry point for Stop hook."""
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    # Build hook input for rule engine
    hook_input = {
        "hook_event_name": "Stop",
        "reason": input_data.get("reason", ""),
        "transcript_path": input_data.get("transcript_path", ""),
    }

    # Load stop rules
    rules_dir = get_rules_dir()
    rules = load_rules(event="stop", rules_dir=str(rules_dir), include_disabled=False)

    if not rules:
        sys.exit(0)

    engine = RuleEngine()
    result = engine.evaluate_rules(rules, hook_input)

    # Check if any rule blocked
    is_block = result.get("decision") == "block" or \
               result.get("hookSpecificOutput", {}).get("permissionDecision") == "deny"

    if is_block:
        message = result.get("systemMessage") or result.get("reason", "Blocked by hookify rule")
        print(message, file=sys.stderr)
        sys.exit(2)

    # Check for warnings
    if result.get("systemMessage"):
        print(result["systemMessage"], file=sys.stderr)
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
