# Plan: Verify Hookify Fix & Remove Bridge Workaround

## Background

Issue [#12446](https://github.com/anthropics/claude-code/issues/12446) reported that hookify plugin blocked commands but only showed messages to users, not to Claude. Our bridge workaround (`common-hookify-bridge.py`) outputs via stderr + exit 2 so Claude receives messages.

**The fix in Claude Code 2.1.9:** Added `permissionDecisionReason` to hookify's block response, allowing Claude to receive the detailed blocking message.

## Phase 1: Verify the Fix Works (Incremental Test)

### Step 1: Prepare test rule

1. Pick a simple rule: `hookify.common-block-base64-decode.local.md`
2. Set `enabled: true` (hookify plugin will handle it)
3. Add `bridgeEnabled: false` (bridge will skip it)

### Step 2: Remove bridge hook temporarily

1. Comment out PreToolUse Bash hook in `settings.json` (or the test rule won't go through native plugin)
2. Keep hookify plugin enabled (already is: `"hookify@claude-plugins-official": true`)

### Step 3: Trigger the block

1. Run command: `base64 -d <<< "dGVzdA=="`
2. **Pass:** Claude's response references the blocking message content (mentions alternatives like "Ask the user to decode")
3. **Fail:** Claude only sees generic "Hook denied" without the rule's message body

### Step 4: Verify and document

- If pass: Proceed to Phase 2 (full migration)
- If fail: Re-enable bridge, investigate further, open issue with hookify maintainers

## Phase 2: Migration (if fix verified)

### 2.1 Update all 23 hookify rules

- Change `enabled: false` to `enabled: true`
- Remove `bridgeEnabled` field (no longer needed)

**Files:**

- `.claude/hookify.common-block-*.local.md` (blocking rules)
- `.claude/hookify.common-warn-*.local.md` (warning rules)

### 2.2 Remove bridge from settings.json

- Remove PreToolUse hook entries for `common-hookify-bridge.py`
- Remove PostToolUse hook entries for `common-hookify-bridge.py --post`
- Keep the Prettier formatting hooks (unrelated to bridge)

### 2.3 Delete bridge files

- `.claude/hooks/common-hookify-bridge.py` - Main bridge script
- `.claude/lib/common_hookify/` - Entire shared module directory

### 2.4 Rewrite tests to use hookify plugin from GitHub

Download hookify plugin from official source for reproducible tests:

**Source:** <https://github.com/anthropics/claude-plugins-official/tree/main/plugins/hookify>

**Test setup script** (new file: `tests/helpers/setup_hookify.sh`):

```bash
#!/bin/bash
# Download hookify plugin for tests
HOOKIFY_DIR="${HOOKIFY_DIR:-/tmp/hookify-plugin}"
if [ ! -d "$HOOKIFY_DIR/core" ]; then
  git clone --depth 1 --filter=blob:none --sparse \
    https://github.com/anthropics/claude-plugins-official.git "$HOOKIFY_DIR-repo"
  cd "$HOOKIFY_DIR-repo" && git sparse-checkout set plugins/hookify
  mv plugins/hookify "$HOOKIFY_DIR"
  rm -rf "$HOOKIFY_DIR-repo"
fi
```

**Updated test runner** (`tests/helpers/run_hookify_tests.py`):

```python
import sys, os
HOOKIFY_DIR = os.environ.get("HOOKIFY_DIR", "/tmp/hookify-plugin")
sys.path.insert(0, HOOKIFY_DIR)
from core import load_rules, RuleEngine
```

**Implementation steps:**

1. Create `tests/helpers/setup_hookify.sh` to download plugin
2. Update `tests/helpers/run_hookify_tests.py` to import from downloaded plugin
3. Update `tests/hooks/test_hookify_integration.bats` to call setup script first
4. Update CI workflow to cache the downloaded plugin
5. Test cases in `hookify_test_cases.yaml` remain unchanged

**Files to create/update:**

- `tests/helpers/setup_hookify.sh` - New: download script
- `tests/helpers/run_hookify_tests.py` - Update imports
- `tests/hooks/test_hookify_integration.bats` - Call setup, update unit tests

### 2.5 Update documentation

- `CLAUDE.md`: Remove "Hookify Bridge Workaround" section
- Update state matrix to reflect native plugin handling
- Remove bridge-related comments from rule files

## Phase 3: Verification

1. Run full test suite: `./test.sh`
2. Run security tests: `bats tests/security/`
3. Run hook tests: `bats tests/hooks/`
4. Manual testing:
   - Try blocked commands (sops -d, base64 -d, kubectl get secret -o yaml)
   - Verify Claude receives and understands blocking messages
   - Try warned commands (cat file, grep pattern)
   - Verify warnings appear to Claude

## Summary of Changes

### Files to Create

| File                             | Purpose                             |
| -------------------------------- | ----------------------------------- |
| `tests/helpers/setup_hookify.sh` | Download hookify plugin from GitHub |

### Files to Modify

| File                                        | Change                                     |
| ------------------------------------------- | ------------------------------------------ |
| 23x `.claude/hookify.common-*.local.md`     | Set `enabled: true`                        |
| `.claude/settings.json`                     | Remove bridge hook entries (lines 123-151) |
| `tests/helpers/run_hookify_tests.py`        | Import from downloaded hookify plugin      |
| `tests/hooks/test_hookify_integration.bats` | Call setup script, update unit tests       |
| `CLAUDE.md`                                 | Remove "Hookify Bridge Workaround" section |

### Files to Delete

| File                                          | Reason                  |
| --------------------------------------------- | ----------------------- |
| `.claude/hooks/common-hookify-bridge.py`      | Bridge no longer needed |
| `.claude/lib/common_hookify/__init__.py`      | Shared module deleted   |
| `.claude/lib/common_hookify/config_loader.py` | Shared module deleted   |
| `.claude/lib/common_hookify/rule_engine.py`   | Shared module deleted   |

## Rollback Plan

If native hookify doesn't work as expected:

1. Revert all `enabled: true` back to `enabled: false`
2. Restore bridge hooks in settings.json
3. Restore deleted files from git: `git checkout HEAD -- .claude/hooks/ .claude/lib/`
