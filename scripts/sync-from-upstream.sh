#!/usr/bin/env bash
# sync-from-upstream.sh — Fetch upstream, run strip, prepare diff for review.
#
# Usage: ./scripts/sync-from-upstream.sh
#
# This script:
# 1. Fetches latest upstream/main
# 2. Compares with last stripped version
# 3. If changes exist, runs strip and prepares diff (does NOT auto-commit)
# 4. Outputs summary of what changed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_DIR="$REPO_ROOT/plugins/compound-engineering"

echo "Fetching upstream..."
git -C "$REPO_ROOT" fetch upstream main --quiet

# Get current upstream HEAD
UPSTREAM_HEAD=$(git -C "$REPO_ROOT" rev-parse upstream/main)
UPSTREAM_VERSION=$(git -C "$REPO_ROOT" show "upstream/main:plugins/compound-engineering/.claude-plugin/plugin.json" 2>/dev/null | jq -r '.version // "unknown"')

# Check if we have a previous stripped version
if [ -f "$PLUGIN_DIR/.stripped-version.json" ]; then
  PREV_COMMIT=$(jq -r '.upstream_commit' "$PLUGIN_DIR/.stripped-version.json")
  PREV_VERSION=$(jq -r '.upstream_version' "$PLUGIN_DIR/.stripped-version.json")
else
  PREV_COMMIT=""
  PREV_VERSION=""
fi

echo "Upstream version: $UPSTREAM_VERSION (commit: $UPSTREAM_HEAD)"
if [ -n "$PREV_COMMIT" ]; then
  echo "Previous version: $PREV_VERSION (commit: $PREV_COMMIT)"
fi

# Check if anything changed
if [ "$UPSTREAM_HEAD" = "$PREV_COMMIT" ]; then
  echo ""
  echo "Already up to date. No changes needed."
  exit 0
fi

# Check if any manifest-relevant files changed
if [ -n "$PREV_COMMIT" ]; then
  CHANGED_FILES=$(git -C "$REPO_ROOT" diff --name-only "$PREV_COMMIT" "upstream/main" -- "plugins/compound-engineering/" 2>/dev/null || true)

  if [ -z "$CHANGED_FILES" ]; then
    echo ""
    echo "Upstream has new commits, but no changes to plugins/compound-engineering/."
    echo "Skipping strip."
    exit 0
  fi

  echo ""
  echo "Changed files in upstream:"
  echo "$CHANGED_FILES" | sed 's|^plugins/compound-engineering/|  |'
fi

# Run strip
echo ""
echo "Running strip..."
STRIP_OUTPUT=$(mktemp -d -t ce-strip-output-XXXXXX)
trap "rm -rf '$STRIP_OUTPUT'" EXIT

"$SCRIPT_DIR/strip-from-upstream.sh" "upstream/main" "$STRIP_OUTPUT"

# Show diff summary
echo ""
echo "=== Changes to be applied ==="

# Compare with current files
if [ -d "$PLUGIN_DIR/agents" ] || [ -d "$PLUGIN_DIR/skills" ]; then
  echo ""
  echo "Files added:"
  diff -rq "$PLUGIN_DIR" "$STRIP_OUTPUT" 2>/dev/null | grep "Only in $STRIP_OUTPUT" | sed 's|.*/||' || echo "  (none)"

  echo ""
  echo "Files removed:"
  diff -rq "$PLUGIN_DIR" "$STRIP_OUTPUT" 2>/dev/null | grep "Only in $PLUGIN_DIR" | sed 's|.*/||' || echo "  (none)"

  echo ""
  echo "Files modified:"
  diff -rq "$PLUGIN_DIR" "$STRIP_OUTPUT" 2>/dev/null | grep "differ" | sed 's|.*/||' || echo "  (none)"
fi

echo ""
echo "To apply these changes, run:"
echo "  cp -r $STRIP_OUTPUT/* $PLUGIN_DIR/"
echo "  # then review and commit"
echo ""
echo "Strip output preserved at: $STRIP_OUTPUT"
echo "(Trap will clean up on exit — copy output before exiting if needed)"
