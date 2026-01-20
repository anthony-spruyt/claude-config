#!/bin/bash
set -euo pipefail
shopt -s nullglob

# Usage: ./sync-to-repo.sh USER/target-repo [config-repo] [config-branch]
#
# Environment:
#   GH_TOKEN or GITHUB_TOKEN - GitHub token (required)

if [ $# -lt 1 ]; then
  echo "Usage: $0 USER/target-repo [config-repo] [config-branch]"
  exit 1
fi

TARGET_REPO="$1"
CONFIG_REPO="${2:-USER/claude-config}"
CONFIG_BRANCH="${3:-main}"
WORK_DIR=$(mktemp -d)
BRANCH_NAME="chore/update-claude-config"

# Check for yq (YAML parser) - needed for exclusion config
if command -v yq &> /dev/null; then
  YQ_AVAILABLE=true
else
  YQ_AVAILABLE=false
fi

# Exclusion arrays (populated after cloning target repo)
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

# Cleanup on exit
trap 'rm -rf "$WORK_DIR"' EXIT

echo "🔧 Syncing config to ${TARGET_REPO}..."
echo "📦 Config source: ${CONFIG_REPO}@${CONFIG_BRANCH}"
echo "💼 Working directory: ${WORK_DIR}"

cd "$WORK_DIR"

# Clone both repos using HTTPS with token authentication
echo "📥 Cloning repositories..."
git clone --depth 1 --branch "$CONFIG_BRANCH" --single-branch \
  "https://x-access-token:${GH_TOKEN}@github.com/${CONFIG_REPO}.git" config
git clone --depth 1 \
  "https://x-access-token:${GH_TOKEN}@github.com/${TARGET_REPO}.git" target

# Ensure target has .claude directory structure
mkdir -p target/.claude/agents target/.claude/rules target/.claude/hooks target/.claude/lib target/.claude/commands

# Load exclusions from target repo (if config exists)
SYNC_CONFIG="target/.claude/.sync-config.yaml"
if [ "$YQ_AVAILABLE" = true ] && [ -f "$SYNC_CONFIG" ]; then
  echo "📋 Found .sync-config.yaml - loading exclusions..."

  # Read exclude_categories array
  while IFS= read -r cat; do
    [ -n "$cat" ] && EXCLUDE_CATEGORIES+=("$cat")
  done < <(yq -r '.exclude_categories[]? // empty' "$SYNC_CONFIG" 2>/dev/null)

  # Read exclude_files array
  while IFS= read -r file; do
    [ -n "$file" ] && EXCLUDE_FILES+=("$file")
  done < <(yq -r '.exclude_files[]? // empty' "$SYNC_CONFIG" 2>/dev/null)

  [ ${#EXCLUDE_CATEGORIES[@]} -gt 0 ] && echo "   Excluded categories: ${EXCLUDE_CATEGORIES[*]}"
  [ ${#EXCLUDE_FILES[@]} -gt 0 ] && echo "   Excluded files: ${EXCLUDE_FILES[*]}"
fi

# Sync files with "common-" prefix (our watermark for central config files)
# This allows repos to have their own files without being overwritten
echo "📋 Syncing common config files..."

# 1. Sync settings.json (unless excluded)
if ! is_category_excluded "settings"; then
  cp config/.claude/settings.json target/.claude/
fi

# 2. Sync hookify.common-*.local.md (delete removed, add new)
if ! is_category_excluded "hookify"; then
  for f in target/.claude/hookify.common-*.local.md; do
    [ -e "$f" ] || continue
    basename="${f##*/}"
    [ -f "config/.claude/$basename" ] || rm -f "$f"
  done
  for f in config/.claude/hookify.common-*.local.md; do
    [ -e "$f" ] || continue
    is_file_excluded "$f" && continue
    cp "$f" target/.claude/
  done
fi

# 3. Sync agents/common-*.md (delete removed, add new)
if ! is_category_excluded "agents"; then
  for f in target/.claude/agents/common-*.md; do
    [ -e "$f" ] || continue
    basename="${f##*/}"
    [ -f "config/.claude/agents/$basename" ] || rm -f "$f"
  done
  for f in config/.claude/agents/common-*.md; do
    [ -e "$f" ] || continue
    is_file_excluded "$f" && continue
    cp "$f" target/.claude/agents/
  done
fi

# 4. Sync rules/common-*.md (delete removed, add new)
if ! is_category_excluded "rules"; then
  for f in target/.claude/rules/common-*.md; do
    [ -e "$f" ] || continue
    basename="${f##*/}"
    [ -f "config/.claude/rules/$basename" ] || rm -f "$f"
  done
  for f in config/.claude/rules/common-*.md; do
    [ -e "$f" ] || continue
    is_file_excluded "$f" && continue
    cp "$f" target/.claude/rules/
  done
fi

# 5. Sync hooks/common-*.py (delete removed, add new)
if ! is_category_excluded "hooks"; then
  for f in target/.claude/hooks/common-*.py; do
    [ -e "$f" ] || continue
    basename="${f##*/}"
    [ -f "config/.claude/hooks/$basename" ] || rm -f "$f"
  done
  for f in config/.claude/hooks/common-*.py; do
    [ -e "$f" ] || continue
    is_file_excluded "$f" && continue
    cp "$f" target/.claude/hooks/
  done
fi

# 6. Sync lib/common_* directories (entire directories)
if ! is_category_excluded "lib"; then
  # Delete dirs that no longer exist in config
  for d in target/.claude/lib/common_*; do
    [ -d "$d" ] || continue
    basename="${d##*/}"
    [ -d "config/.claude/lib/$basename" ] || rm -rf "$d"
  done
  # Copy dirs from config (delete target first to remove stale files)
  for d in config/.claude/lib/common_*; do
    [ -d "$d" ] || continue
    is_file_excluded "$d" && continue
    basename="${d##*/}"
    rm -rf "target/.claude/lib/$basename"
    cp -r "$d" target/.claude/lib/
  done
fi

# 7. Sync commands/common-*.md (delete removed, add new)
# Commands use common- prefix in filename but can have different invocation name via 'name' field
if ! is_category_excluded "commands"; then
  for f in target/.claude/commands/common-*.md; do
    [ -e "$f" ] || continue
    basename="${f##*/}"
    [ -f "config/.claude/commands/$basename" ] || rm -f "$f"
  done
  for f in config/.claude/commands/common-*.md; do
    [ -e "$f" ] || continue
    is_file_excluded "$f" && continue
    cp "$f" target/.claude/commands/
  done
fi

# Check if anything changed (including new untracked files)
cd target
git add .claude/
if git diff --cached --quiet .claude/; then
  echo "✅ No changes detected - already up to date"
  exit 0
fi

# Show what changed
echo ""
echo "📊 Changes detected:"
git diff --cached --stat .claude/
echo ""

# Create or update branch (files already staged from check above)
echo "🌿 Creating branch: ${BRANCH_NAME}"

# Delete remote branch if it exists (to get a clean state)
git push origin --delete "$BRANCH_NAME" 2>/dev/null || true

git checkout -b "$BRANCH_NAME"

git commit -S -m "chore(config): update Claude config

Updated configuration from ${CONFIG_REPO}."

# Push branch
echo "⬆️  Pushing branch to origin..."
git push -u origin "$BRANCH_NAME"

# Check if PR already exists
EXISTING_PR=$(gh pr list --head "$BRANCH_NAME" --json number --jq '.[0].number' 2>/dev/null || echo "")

if [ -n "$EXISTING_PR" ]; then
  echo "📝 PR #${EXISTING_PR} already exists - it will show the updated changes"
  PR_URL="https://github.com/${TARGET_REPO}/pull/${EXISTING_PR}"
else
  # Create PR
  echo "🔀 Creating pull request..."
  PR_URL=$(gh pr create \
    --head "$BRANCH_NAME" \
    --title "chore(config): update Claude config" \
    --body "## 🛡️ Config Update

**Source:** [${CONFIG_REPO}](https://github.com/${CONFIG_REPO})
**Branch:** \`${CONFIG_BRANCH}\`

### 📊 Changes

\`\`\`
$(git diff --stat HEAD~1 .claude/)
\`\`\`

### 📝 Files Updated

\`\`\`
$(git diff --name-only HEAD~1 .claude/)
\`\`\`

### ✅ Review Checklist

- [ ] Review hookify rule changes
- [ ] Check settings.json permissions
- [ ] Verify no project-specific configs overwritten
- [ ] Test rules don't break development workflow

---

🤖 Auto-generated by [sync-to-repo.sh](https://github.com/${CONFIG_REPO}/blob/main/sync-to-repo.sh)")
fi

# Try to enable automerge (will fail silently if not available)
echo "🔄 Attempting to enable automerge..."
if gh pr merge "$PR_URL" --auto --squash --delete-branch 2>/dev/null; then
  echo "✅ Automerge enabled - PR will merge when requirements are met"
else
  echo "ℹ️  Automerge not available (repo may not have it enabled)"
fi

echo ""
echo "✅ Done! Pull request:"
echo "   ${PR_URL}"
