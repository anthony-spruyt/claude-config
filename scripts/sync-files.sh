#!/bin/bash
set -euo pipefail
shopt -s nullglob

# sync-files.sh - Sync config files from source to target
# Usage: ./scripts/sync-files.sh <source_dir> <target_dir>
#
# Arguments:
#   source_dir - Directory containing the config source (e.g., _config_source/.claude)
#   target_dir - Directory containing the target repo (e.g., . for current dir)
#
# Outputs via GITHUB_OUTPUT (if available):
#   changed       - "true" if files changed, "false" otherwise
#   diff_stat     - Git diff --stat output
#   changed_files - Newline-separated list of changed files
#
# Exit codes:
#   0 - Success (changes detected or no changes)
#   1 - Error

if [ $# -lt 2 ]; then
  echo "Usage: $0 <source_dir> <target_dir>"
  echo "  source_dir: Directory containing config source (.claude directory)"
  echo "  target_dir: Directory containing target repo root"
  exit 1
fi

SOURCE_DIR="$1"
TARGET_DIR="$2"

# Validate directories
if [ ! -d "$SOURCE_DIR/.claude" ]; then
  echo "Error: $SOURCE_DIR/.claude does not exist"
  exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: $TARGET_DIR does not exist"
  exit 1
fi

# Check for yq (YAML parser) - needed for exclusion config
if command -v yq &> /dev/null; then
  YQ_AVAILABLE=true
else
  YQ_AVAILABLE=false
  echo "Warning: yq not found - exclusion config will be ignored"
fi

# Exclusion arrays
EXCLUDE_CATEGORIES=()
EXCLUDE_FILES=()

# Check if category is excluded
is_category_excluded() {
  local category="$1"
  for excluded in "${EXCLUDE_CATEGORIES[@]}"; do
    [ "$excluded" = "$category" ] && return 0
  done
  return 1
}

# Check if file is excluded (basename match)
is_file_excluded() {
  local filepath="$1"
  local basename="${filepath##*/}"
  for excluded in "${EXCLUDE_FILES[@]}"; do
    [ "$excluded" = "$basename" ] && return 0
  done
  return 1
}

# Ensure target has .claude directory structure
mkdir -p "$TARGET_DIR/.claude/agents" \
         "$TARGET_DIR/.claude/rules" \
         "$TARGET_DIR/.claude/hooks" \
         "$TARGET_DIR/.claude/lib" \
         "$TARGET_DIR/.claude/commands"

# Load exclusions from target repo (if config exists)
SYNC_CONFIG="$TARGET_DIR/.claude/.sync-config.yaml"
if [ "$YQ_AVAILABLE" = true ] && [ -f "$SYNC_CONFIG" ]; then
  echo "Loading exclusions from .sync-config.yaml..."

  # Read exclude_categories array
  while IFS= read -r cat; do
    [ -n "$cat" ] && EXCLUDE_CATEGORIES+=("$cat")
  done < <(yq -r '.exclude_categories[]?' "$SYNC_CONFIG" 2>/dev/null)

  # Read exclude_files array
  while IFS= read -r file; do
    [ -n "$file" ] && EXCLUDE_FILES+=("$file")
  done < <(yq -r '.exclude_files[]?' "$SYNC_CONFIG" 2>/dev/null)

  [ ${#EXCLUDE_CATEGORIES[@]} -gt 0 ] && echo "  Excluded categories: ${EXCLUDE_CATEGORIES[*]}"
  [ ${#EXCLUDE_FILES[@]} -gt 0 ] && echo "  Excluded files: ${EXCLUDE_FILES[*]}"
fi

echo "Syncing config files..."

# 1. Sync settings.json (unless excluded)
if ! is_category_excluded "settings"; then
  cp "$SOURCE_DIR/.claude/settings.json" "$TARGET_DIR/.claude/"
  echo "  Synced: settings.json"
fi

# 2. Sync hookify.common-*.local.md (delete removed, add new)
if ! is_category_excluded "hookify"; then
  # Delete files that no longer exist in source
  for f in "$TARGET_DIR"/.claude/hookify.common-*.local.md; do
    [ -e "$f" ] || continue
    basename="${f##*/}"
    [ -f "$SOURCE_DIR/.claude/$basename" ] || rm -f "$f"
  done
  # Copy files from source
  for f in "$SOURCE_DIR"/.claude/hookify.common-*.local.md; do
    [ -e "$f" ] || continue
    is_file_excluded "$f" && continue
    cp "$f" "$TARGET_DIR/.claude/"
  done
  echo "  Synced: hookify.common-*.local.md"
fi

# 3. Sync agents/common-*.md (delete removed, add new)
if ! is_category_excluded "agents"; then
  for f in "$TARGET_DIR"/.claude/agents/common-*.md; do
    [ -e "$f" ] || continue
    basename="${f##*/}"
    [ -f "$SOURCE_DIR/.claude/agents/$basename" ] || rm -f "$f"
  done
  for f in "$SOURCE_DIR"/.claude/agents/common-*.md; do
    [ -e "$f" ] || continue
    is_file_excluded "$f" && continue
    cp "$f" "$TARGET_DIR/.claude/agents/"
  done
  echo "  Synced: agents/common-*.md"
fi

# 4. Sync rules/common-*.md (delete removed, add new)
if ! is_category_excluded "rules"; then
  for f in "$TARGET_DIR"/.claude/rules/common-*.md; do
    [ -e "$f" ] || continue
    basename="${f##*/}"
    [ -f "$SOURCE_DIR/.claude/rules/$basename" ] || rm -f "$f"
  done
  for f in "$SOURCE_DIR"/.claude/rules/common-*.md; do
    [ -e "$f" ] || continue
    is_file_excluded "$f" && continue
    cp "$f" "$TARGET_DIR/.claude/rules/"
  done
  echo "  Synced: rules/common-*.md"
fi

# 5. Sync hooks/common-*.py (delete removed, add new)
if ! is_category_excluded "hooks"; then
  for f in "$TARGET_DIR"/.claude/hooks/common-*.py; do
    [ -e "$f" ] || continue
    basename="${f##*/}"
    [ -f "$SOURCE_DIR/.claude/hooks/$basename" ] || rm -f "$f"
  done
  for f in "$SOURCE_DIR"/.claude/hooks/common-*.py; do
    [ -e "$f" ] || continue
    is_file_excluded "$f" && continue
    cp "$f" "$TARGET_DIR/.claude/hooks/"
  done
  echo "  Synced: hooks/common-*.py"
fi

# 6. Sync lib/common_* directories (entire directories)
if ! is_category_excluded "lib"; then
  # Delete dirs that no longer exist in source
  for d in "$TARGET_DIR"/.claude/lib/common_*; do
    [ -d "$d" ] || continue
    basename="${d##*/}"
    [ -d "$SOURCE_DIR/.claude/lib/$basename" ] || rm -rf "$d"
  done
  # Copy dirs from source (delete target first to remove stale files)
  for d in "$SOURCE_DIR"/.claude/lib/common_*; do
    [ -d "$d" ] || continue
    is_file_excluded "$d" && continue
    basename="${d##*/}"
    rm -rf "$TARGET_DIR/.claude/lib/$basename"
    cp -r "$d" "$TARGET_DIR/.claude/lib/"
  done
  echo "  Synced: lib/common_*"
fi

# 7. Sync commands/common-*.md (delete removed, add new)
if ! is_category_excluded "commands"; then
  for f in "$TARGET_DIR"/.claude/commands/common-*.md; do
    [ -e "$f" ] || continue
    basename="${f##*/}"
    [ -f "$SOURCE_DIR/.claude/commands/$basename" ] || rm -f "$f"
  done
  for f in "$SOURCE_DIR"/.claude/commands/common-*.md; do
    [ -e "$f" ] || continue
    is_file_excluded "$f" && continue
    cp "$f" "$TARGET_DIR/.claude/commands/"
  done
  echo "  Synced: commands/common-*.md"
fi

# Check if anything changed
cd "$TARGET_DIR"
git add .claude/

if git diff --cached --quiet .claude/; then
  echo "No changes detected - already up to date"

  # Output to GITHUB_OUTPUT if available
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
      echo "changed=false"
      echo "diff_stat="
      echo "changed_files="
    } >> "$GITHUB_OUTPUT"
  fi
  exit 0
fi

# Capture diff information
DIFF_STAT=$(git diff --cached --stat .claude/)
CHANGED_FILES=$(git diff --cached --name-only .claude/)

echo ""
echo "Changes detected:"
echo "$DIFF_STAT"

# Output to GITHUB_OUTPUT if available
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  # Use heredoc delimiter for multiline values
  {
    echo "changed=true"
    echo "diff_stat<<EOF_DIFF_STAT"
    echo "$DIFF_STAT"
    echo "EOF_DIFF_STAT"
    echo "changed_files<<EOF_CHANGED_FILES"
    echo "$CHANGED_FILES"
    echo "EOF_CHANGED_FILES"
  } >> "$GITHUB_OUTPUT"
fi

exit 0
