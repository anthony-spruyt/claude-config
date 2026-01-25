#!/usr/bin/env python3
"""Rate limiting state management for hookify-extended.

Tracks warning counts per rule to support warn_once and warn_interval.
State is stored in /tmp/claude-hookify-state-{ppid}.json with 24h TTL.
"""

import hashlib
import json
import os
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .config_loader import Rule

STATE_TTL_HOURS = 24
STATE_DIR = Path("/tmp")


class WarningState:
    """Manages rate limiting state for hookify warnings."""

    def __init__(self):
        """Initialize state manager with PPID-based scope."""
        self.scope_id = self._get_scope_id()
        self.state_file = STATE_DIR / f"claude-hookify-state-{self.scope_id}.json"
        self._cleanup_old_state_files()
        self.state = self._load_state()

    def _get_scope_id(self) -> str:
        """Get scope identifier based on HOOKIFY_STATE_SCOPE env var.

        Options:
        - ppid (default): Per-agent context (subagents get separate state)
        - cwd: Per-project (all agents share state)
        - ppid+cwd: Per-agent-per-project
        """
        scope = os.environ.get("HOOKIFY_STATE_SCOPE", "ppid")
        ppid = str(os.getppid())
        cwd_hash = hashlib.sha256(os.getcwd().encode()).hexdigest()[:12]

        if scope == "cwd":
            return cwd_hash
        elif scope == "ppid+cwd":
            return f"{ppid}-{cwd_hash}"
        else:  # default: ppid
            return ppid

    def _cleanup_old_state_files(self):
        """Remove state files older than STATE_TTL_HOURS."""
        try:
            cutoff = time.time() - (STATE_TTL_HOURS * 3600)
            for f in STATE_DIR.glob("claude-hookify-state-*.json"):
                try:
                    if f.stat().st_mtime < cutoff:
                        f.unlink()
                except (OSError, IOError):
                    pass  # Ignore cleanup errors
        except (OSError, IOError):
            pass  # Ignore if /tmp is inaccessible

    def _load_state(self) -> dict:
        """Load state from file, return empty if stale or missing."""
        if not self.state_file.exists():
            return {"created_at": datetime.now().isoformat(), "rules": {}}

        try:
            with open(self.state_file) as f:
                state = json.load(f)

            # Check if state is stale (>24h old)
            created_str = state.get("created_at", "1970-01-01T00:00:00")
            try:
                created = datetime.fromisoformat(created_str)
            except ValueError:
                created = datetime(1970, 1, 1)

            if datetime.now() - created > timedelta(hours=STATE_TTL_HOURS):
                return {"created_at": datetime.now().isoformat(), "rules": {}}

            return state
        except (json.JSONDecodeError, IOError, OSError):
            return {"created_at": datetime.now().isoformat(), "rules": {}}

    def should_warn(self, rule: "Rule") -> bool:
        """Check if warning should be shown based on rate limiting.

        Args:
            rule: Rule with warn_once and/or warn_interval settings

        Returns:
            True if warning should be shown, False if suppressed
        """
        # No rate limiting configured
        if not rule.warn_once and rule.warn_interval <= 0:
            return True

        rule_state = self.state.get("rules", {}).get(rule.name, {})
        warn_count = rule_state.get("warn_count", 0)

        if rule.warn_once:
            # Only warn if never warned before
            return warn_count == 0
        elif rule.warn_interval > 0:
            # Warn on 0, N, 2N, 3N, ...
            return warn_count % rule.warn_interval == 0

        return True

    def record_match(self, rule: "Rule"):
        """Record that a rule matched (regardless of whether warning was shown).

        This increments the counter so rate limiting works correctly.
        Call this for every match, not just when warning is shown.

        Args:
            rule: Rule that matched
        """
        if rule.name not in self.state.get("rules", {}):
            self.state.setdefault("rules", {})[rule.name] = {"warn_count": 0}

        self.state["rules"][rule.name]["warn_count"] += 1
        self.state["rules"][rule.name]["last_matched_at"] = datetime.now().isoformat()
        self._save_state()

    def _save_state(self):
        """Atomically write state to file."""
        try:
            tmp_file = self.state_file.with_suffix(".tmp")
            with open(tmp_file, "w") as f:
                json.dump(self.state, f, indent=2)
            tmp_file.rename(self.state_file)  # Atomic on POSIX
        except (IOError, OSError) as e:
            # Log but don't fail if state can't be saved
            import sys
            print(f"Warning: Could not save hookify state: {e}", file=sys.stderr)
