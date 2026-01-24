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

# ============================================
# Dashboard Issue Management Functions
# ============================================

# Config version (set after cloning config repo)
CONFIG_VERSION=""

# Generate dashboard issue body
generate_dashboard_body() {
  local status="$1"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

  # Build exclusions section
  local exclusions_section=""
  if [ ${#EXCLUDE_CATEGORIES[@]} -gt 0 ] || [ ${#EXCLUDE_FILES[@]} -gt 0 ]; then
    exclusions_section="
## Exclusions

"
    if [ ${#EXCLUDE_CATEGORIES[@]} -gt 0 ]; then
      exclusions_section+="**Categories:** ${EXCLUDE_CATEGORIES[*]}
"
    fi
    if [ ${#EXCLUDE_FILES[@]} -gt 0 ]; then
      exclusions_section+="**Files:** ${EXCLUDE_FILES[*]}
"
    fi
  fi

  cat << EOF
# 🔄 Claude Config Sync Dashboard

This issue allows you to request a config sync from the central claude-config repository.

## Actions

- [ ] **Request sync now** - Check this box to trigger a sync

## Status

| Field | Value |
|-------|-------|
| Last sync | ${timestamp} |
| Config version | \`${CONFIG_VERSION}\` |
| Status | ${status} |
${exclusions_section}
## Configuration

To opt out of specific synced files, create \`.claude/.sync-config.yaml\`:

\`\`\`yaml
# Opt out of entire categories
exclude_categories:
  - commands  # Don't sync common-*.md commands

# Opt out of specific files
exclude_files:
  - "hookify.common-block-kubectl-describe-secrets.local.md"
\`\`\`

---
🤖 Managed by [sync-to-repo.sh](https://github.com/${CONFIG_REPO}/blob/main/sync-to-repo.sh)
EOF
}

# Create or update dashboard issue
create_or_update_dashboard() {
  local status="$1"
  local title="🔄 Claude Config Sync Dashboard"

  echo ""
  echo "📊 Managing dashboard issue..."

  # Check for existing dashboard issue
  local existing_number
  existing_number=$(gh issue list \
    --repo "$TARGET_REPO" \
    --search "\"${title}\" in:title" \
    --state open \
    --json number \
    --jq '.[0].number' 2>/dev/null || echo "")

  local body
  body=$(generate_dashboard_body "$status")

  if [ -n "$existing_number" ] && [ "$existing_number" != "null" ]; then
    echo "   Updating existing dashboard issue #${existing_number}..."
    if gh issue edit "$existing_number" \
      --repo "$TARGET_REPO" \
      --body "$body" 2>/dev/null; then
      echo "   ✅ Dashboard updated: https://github.com/${TARGET_REPO}/issues/${existing_number}"
    else
      echo "   ⚠️  Failed to update dashboard issue"
    fi
  else
    echo "   Creating new dashboard issue..."
    local issue_url
    if issue_url=$(gh issue create \
      --repo "$TARGET_REPO" \
      --title "$title" \
      --body "$body" 2>/dev/null); then
      echo "   ✅ Dashboard created: ${issue_url}"
    else
      echo "   ⚠️  Failed to create dashboard issue"
    fi
  fi
}

# ============================================

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

# Get config version (commit SHA) for dashboard
CONFIG_VERSION=$(git -C config rev-parse --short HEAD)

# Ensure target has .claude directory structure
mkdir -p target/.claude/agents target/.claude/rules target/.claude/hooks target/.claude/lib target/.claude/commands

# Load exclusions from target repo (if config exists)
SYNC_CONFIG="target/.claude/.sync-config.yaml"
if [ "$YQ_AVAILABLE" = true ] && [ -f "$SYNC_CONFIG" ]; then
  echo "📋 Found .sync-config.yaml - loading exclusions..."

  # Read exclude_categories array
  while IFS= read -r cat; do
    [ -n "$cat" ] && EXCLUDE_CATEGORIES+=("$cat")
  done < <(yq -r '.exclude_categories[]?' "$SYNC_CONFIG" 2>/dev/null)

  # Read exclude_files array
  while IFS= read -r file; do
    [ -n "$file" ] && EXCLUDE_FILES+=("$file")
  done < <(yq -r '.exclude_files[]?' "$SYNC_CONFIG" 2>/dev/null)

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
  create_or_update_dashboard "✅ Up to date"
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

git commit -m "chore(config): update Claude config

Updated configuration from ${CONFIG_REPO}."

# Push branch
echo "⬆️  Pushing branch to origin..."
git push -u origin "$BRANCH_NAME" --force-with-lease

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

# Update dashboard with sync status
create_or_update_dashboard "✅ Synced (PR: ${PR_URL})"
