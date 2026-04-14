#!/usr/bin/env bash
# strip-from-upstream.sh — Rebuild a clean tree from upstream, keeping only manifest files.
#
# Usage: ./scripts/strip-from-upstream.sh <upstream_commit> <output_dir>
#   upstream_commit: git ref or hash from upstream to strip
#   output_dir:      where to write the stripped tree (e.g. /tmp/strip-output)
#
# This script:
# 1. Creates a temporary worktree from the given upstream commit
# 2. Removes all agents/ and skills/ contents
# 3. Restores only files listed in scripts/strip-manifest.json
# 4. Applies sed patches from scripts/patches/
# 5. Writes .stripped-version.json
# 6. Copies local_overrides/ on top (if any)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$SCRIPT_DIR/strip-manifest.json"
PATCHES_DIR="$SCRIPT_DIR/patches"
LOCAL_OVERRIDES_DIR="$SCRIPT_DIR/local_overrides"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <upstream_commit> <output_dir>"
  exit 1
fi

UPSTREAM_REF="$1"
OUTPUT_DIR="$2"

# Validate manifest exists
if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: Manifest not found at $MANIFEST"
  exit 1
fi

# Create temp worktree from upstream
WORKTREE=$(mktemp -d -t ce-strip-XXXXXX)
trap "git -C '$REPO_ROOT' worktree remove '$WORKTREE' --force 2>/dev/null; rm -rf '$WORKTREE'" EXIT

echo "Creating worktree from upstream ref $UPSTREAM_REF..."

# Parse the ref: handle both "upstream/main" and bare "main" forms
if [[ "$UPSTREAM_REF" == upstream/* ]]; then
  REMOTE="upstream"
  BRANCH="${UPSTREAM_REF#upstream/}"
else
  REMOTE="upstream"
  BRANCH="$UPSTREAM_REF"
fi

git -C "$REPO_ROOT" fetch "$REMOTE" "$BRANCH" --quiet 2>/dev/null || {
  echo "ERROR: Failed to fetch $REMOTE $BRANCH"
  exit 1
}
git -C "$REPO_ROOT" worktree add "$WORKTREE" "FETCH_HEAD" --quiet

PLUGIN_DIR="$WORKTREE/plugins/compound-engineering"

if [ ! -d "$PLUGIN_DIR" ]; then
  echo "ERROR: plugins/compound-engineering/ not found in upstream tree"
  exit 1
fi

# Step 1: Copy entire plugin dir to output, then strip
echo "Copying upstream plugin tree..."
mkdir -p "$OUTPUT_DIR"
cp -r "$PLUGIN_DIR"/* "$OUTPUT_DIR/"

# Step 2: Remove all agents/ and skills/ from the output
echo "Stripping agents/ and skills/..."
rm -rf "$OUTPUT_DIR/agents"
rm -rf "$OUTPUT_DIR/skills"

# Step 3: Restore only manifest files from the upstream worktree copy
echo "Restoring manifest files..."

restore_files() {
  local section="$1"
  local base_dir="$2"
  jq -r ".$section[]" "$MANIFEST" | while read -r path; do
    local src="$base_dir/$path"
    local dest="$OUTPUT_DIR/$path"
    if [ ! -f "$src" ]; then
      echo "  WARNING: Manifest file not found in upstream: $path"
      continue
    fi
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
  done
}

restore_files "agents" "$PLUGIN_DIR"
restore_files "skills" "$PLUGIN_DIR"
restore_files "plugin_metadata" "$PLUGIN_DIR"

# Step 3: Apply patches
echo "Applying patches..."
if [ -d "$PATCHES_DIR" ]; then
  for patch_file in "$PATCHES_DIR"/*.patch; do
    [ -f "$patch_file" ] || continue
    target="$(basename "$patch_file" .patch)"
    echo "  Applying patch: $target"
    case "$target" in
      ce-plan-no-review-refs)
        # Remove references to document-review skill and spec-flow-analyzer agent
        sed -i '/compound-engineering:workflow:spec-flow-analyzer/d' "$OUTPUT_DIR/skills/ce-plan/SKILL.md"
        # Remove the document-review cross-reference section
        sed -i '/^`document-review` and this confidence check/,+2d' "$OUTPUT_DIR/skills/ce-plan/SKILL.md"
        # Strip removed agent references from deepening-workflow reference file
        sed -i '/compound-engineering:review:/d' "$OUTPUT_DIR/skills/ce-plan/references/deepening-workflow.md"
        sed -i '/compound-engineering:workflow:/d' "$OUTPUT_DIR/skills/ce-plan/references/deepening-workflow.md"
        sed -i '/compound-engineering:document-review:/d' "$OUTPUT_DIR/skills/ce-plan/references/deepening-workflow.md"
        # Clean up empty lines left behind in deepening-workflow
        sed -i '/^$/N;/^\n$/d' "$OUTPUT_DIR/skills/ce-plan/references/deepening-workflow.md"
        ;;
      ce-compound-no-review-refs)
        SKILL_FILE="$OUTPUT_DIR/skills/ce-compound/SKILL.md"
        # Remove Phase 3 parallel_tasks block with review agent dispatches (lines 313-326)
        sed -i '/^### Phase 3: Optional Enhancement/,/^---$/{
          /^### Phase 3: Optional Enhancement/d
          /^---$/d
          /^$/d
          /<parallel_tasks>/,/<\/parallel_tasks>/d
          /^Based on problem type, optionally invoke/d
          /^- \*\*performance_issue\*\*/d
          /^- \*\*security_issue\*\*/d
          /^- \*\*database_issue\*\*/d
          /^- Any code-heavy issue/d
          /^  - Ruby\/Rails/d
          /^  - Python/d
          /^  - TypeScript\/JavaScript/d
          /^  - Other stacks/d
        }' "$SKILL_FILE"

        # Remove the "Code Quality & Review" and "Specific Domain Experts" sections
        sed -i '/^### Code Quality & Review/,/^### Enhancement & Research$/{
          /^### Code Quality & Review/d
          /^- \*\*compound-engineering:review:/d
          /^### Specific Domain Experts/d
          /^- \*\*compound-engineering:review:/d
          /^### Enhancement/d
        }' "$SKILL_FILE"

        # Clean up empty lines left behind
        sed -i '/^$/N;/^\n$/d' "$SKILL_FILE"
        ;;
    esac
  done
fi

# Step 4: Copy local overrides
echo "Applying local overrides..."
if [ -d "$LOCAL_OVERRIDES_DIR" ] && [ "$(ls -A "$LOCAL_OVERRIDES_DIR" 2>/dev/null)" ]; then
  cp -r "$LOCAL_OVERRIDES_DIR"/* "$OUTPUT_DIR/"
fi

# Step 5: Write version info
COMMIT_HASH=$(git -C "$REPO_ROOT" rev-parse "refs/remotes/$REMOTE/$BRANCH")
COMMIT_DATE=$(git -C "$REPO_ROOT" show -s --format=%ci "refs/remotes/$REMOTE/$BRANCH")
UPSTREAM_VERSION=$(jq -r '.version // "unknown"' "$PLUGIN_DIR/.claude-plugin/plugin.json" 2>/dev/null || echo "unknown")

cat > "$OUTPUT_DIR/.stripped-version.json" << EOF
{
  "upstream_version": "$UPSTREAM_VERSION",
  "upstream_commit": "$COMMIT_HASH",
  "upstream_commit_date": "$COMMIT_DATE",
  "strip_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "manifest": "scripts/strip-manifest.json"
}
EOF

echo ""
echo "Strip complete. Output: $OUTPUT_DIR"
echo "Upstream version: $UPSTREAM_VERSION"
echo "Upstream commit:  $COMMIT_HASH"

# Step 6: Smoke test
echo ""
echo "Running smoke test..."

ERRORS=0

# Check agents
EXPECTED_AGENTS=(
  "agents/research/learnings-researcher.md"
  "agents/research/session-historian.md"
  "agents/research/repo-research-analyst.md"
  "agents/research/issue-intelligence-analyst.md"
  "agents/research/slack-researcher.md"
  "agents/research/best-practices-researcher.md"
  "agents/research/framework-docs-researcher.md"
  "agents/research/git-history-analyzer.md"
)

for agent in "${EXPECTED_AGENTS[@]}"; do
  if [ ! -f "$OUTPUT_DIR/$agent" ]; then
    echo "  FAIL: Missing $agent"
    ERRORS=$((ERRORS + 1))
  fi
done

EXPECTED_SKILLS=(
  "skills/ce-compound/SKILL.md"
  "skills/ce-compound-refresh/SKILL.md"
  "skills/ce-sessions/SKILL.md"
  "skills/ce-plan/SKILL.md"
  "skills/ce-ideate/SKILL.md"
  "skills/ce-brainstorm/SKILL.md"
  "skills/ce-debug/SKILL.md"
)

for skill in "${EXPECTED_SKILLS[@]}"; do
  if [ ! -f "$OUTPUT_DIR/$skill" ]; then
    echo "  FAIL: Missing $skill"
    ERRORS=$((ERRORS + 1))
  fi
done

# Check no stray agent directories exist (only research/ should remain)
for dir in "$OUTPUT_DIR/agents"/*/; do
  dirname=$(basename "$dir")
  if [ "$dirname" != "research" ]; then
    echo "  FAIL: Unexpected agent directory: agents/$dirname/"
    ERRORS=$((ERRORS + 1))
  fi
done

# Check for references to removed agents
REMOVED_PATTERNS=(
  "compound-engineering:review:"
  "compound-engineering:document-review:"
  "compound-engineering:workflow:"
  "compound-engineering:design:"
  "compound-engineering:docs:"
)

for pattern in "${REMOVED_PATTERNS[@]}"; do
  matches=$(grep -rl "$pattern" "$OUTPUT_DIR/skills/" "$OUTPUT_DIR/agents/" 2>/dev/null || true)
  if [ -n "$matches" ]; then
    echo "  WARN: Found reference to removed component '$pattern' in: $matches"
  fi
done

if [ $ERRORS -eq 0 ]; then
  echo "  Smoke test passed."
else
  echo "  Smoke test FAILED: $ERRORS errors."
  exit 1
fi
