#!/usr/bin/env python3
"""Data-driven hookify test runner.

Reads test cases from YAML config and runs them through the hookify rule engine.
Uses the actual hookify implementation for accurate testing.
"""

import sys
import os
import argparse

# Add helpers directory to path for hookify import
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import yaml
from hookify import load_rules, RuleEngine


def get_result_type(result: dict) -> str:
    """Determine result type from hookify output.

    Args:
        result: Hookify evaluation result dict

    Returns:
        "block", "warn", or "allow"
    """
    if not result:
        return "allow"
    if result.get('hookSpecificOutput', {}).get('permissionDecision') == 'deny':
        return "block"
    if 'systemMessage' in result:
        return "warn"
    return "allow"


def run_tests(config_path: str, rules_dir: str, verbose: bool = False) -> list:
    """Run all test cases from config file.

    Args:
        config_path: Path to test cases YAML file
        rules_dir: Directory containing hookify rules
        verbose: Print detailed output

    Returns:
        List of failure messages (empty if all passed)
    """
    with open(config_path) as f:
        config = yaml.safe_load(f)

    engine = RuleEngine()
    failures = []
    passed = 0

    for test in config.get('test_cases', []):
        name = test.get('name', 'unnamed')
        tool = test.get('tool', 'Bash')
        expect = test.get('expect', 'allow')

        # Build input JSON based on tool type
        if tool == 'Bash':
            input_data = {
                "hook_event_name": "PreToolUse",
                "tool_name": "Bash",
                "tool_input": {"command": test.get('command', '')}
            }
        elif tool in ['Read', 'Edit', 'Write']:
            input_data = {
                "hook_event_name": "PreToolUse",
                "tool_name": tool,
                "tool_input": {
                    "file_path": test.get('file_path', ''),
                    "content": test.get('content', ''),
                    "new_string": test.get('new_string', ''),
                    "old_string": test.get('old_string', '')
                }
            }
        else:
            input_data = {
                "hook_event_name": "PreToolUse",
                "tool_name": tool,
                "tool_input": test.get('tool_input', {})
            }

        # Determine event type for rule loading
        event = "bash" if tool == "Bash" else "file"

        # Load rules and evaluate
        rules = load_rules(event=event, rules_dir=rules_dir)
        result = engine.evaluate_rules(rules, input_data)

        # Check expectation
        actual = get_result_type(result)

        if actual != expect:
            msg = f"FAIL: {name}: expected {expect}, got {actual}"
            failures.append(msg)
            if verbose:
                print(f"\033[91m{msg}\033[0m")  # Red
                print(f"  Input: {input_data}")
                print(f"  Result: {result}")
        else:
            passed += 1
            if verbose:
                print(f"\033[92mPASS: {name}\033[0m")  # Green

    # Summary
    total = passed + len(failures)
    print(f"\n{passed}/{total} tests passed")

    return failures


def main():
    parser = argparse.ArgumentParser(description='Run hookify test cases')
    parser.add_argument('config', help='Path to test cases YAML file')
    parser.add_argument('--rules-dir', '-r', default='.claude',
                       help='Directory containing hookify rules (default: .claude)')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Print detailed output')
    args = parser.parse_args()

    failures = run_tests(args.config, args.rules_dir, args.verbose)

    if failures:
        print("\nFailures:")
        for f in failures:
            print(f"  {f}", file=sys.stderr)
        sys.exit(1)
    else:
        print("\nAll tests passed!")
        sys.exit(0)


if __name__ == "__main__":
    main()
