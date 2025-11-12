#!/usr/bin/env bash
#
# cleanup.sh - Clean up merged and stale worktrees
#
# Usage: cleanup.sh [--merged] [--stale] [--dry-run] [--days N]
#
# Arguments:
#   --merged   - Remove worktrees for branches merged to main
#   --stale    - Remove worktrees inactive for N days (default: 30)
#   --dry-run  - Show what would be removed without removing
#   --days N   - Number of days for stale detection (default: 30)
#
# Exit codes:
#   0 - Success
#   1 - Git error

set -euo pipefail

# Parse arguments
REMOVE_MERGED=false
REMOVE_STALE=false
DRY_RUN=false
STALE_DAYS=30

while [[ $# -gt 0 ]]; do
  case $1 in
    --merged)
      REMOVE_MERGED=true
      shift
      ;;
    --stale)
      REMOVE_STALE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --days)
      STALE_DAYS="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not a Git repository" >&2
  exit 1
fi

# Get main branch name
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# Track cleanup statistics
REMOVED_MERGED=0
REMOVED_STALE=0
SKIPPED_DIRTY=0
REMOVED_BRANCHES=()

# Get all worktrees except main repository
WORKTREES=$(git worktree list --porcelain | awk '
  /^worktree / { path=$2; getline; if (/^branch /) { print path"|"$2 } }
' | grep -v "refs/heads/$MAIN_BRANCH" || true)

if [ -z "$WORKTREES" ]; then
  echo "{\"status\": \"success\", \"removed_merged\": 0, \"removed_stale\": 0, \"skipped_dirty\": 0, \"branches\": []}"
  exit 0
fi

# Process each worktree
while IFS='|' read -r WORKTREE_PATH BRANCH_REF; do
  BRANCH_NAME="${BRANCH_REF#refs/heads/}"

  # Check if branch is merged
  IS_MERGED=false
  if [ "$REMOVE_MERGED" = true ]; then
    if git branch --merged "$MAIN_BRANCH" | grep -q "^[* ]*$BRANCH_NAME$"; then
      IS_MERGED=true
    fi
  fi

  # Check if worktree is stale
  IS_STALE=false
  if [ "$REMOVE_STALE" = true ] && [ -d "$WORKTREE_PATH" ]; then
    LAST_MODIFIED=$(find "$WORKTREE_PATH" -type f -exec stat -c %Y {} \; 2>/dev/null | sort -n | tail -1 || echo "0")
    CURRENT_TIME=$(date +%s)
    DAYS_OLD=$(( (CURRENT_TIME - LAST_MODIFIED) / 86400 ))
    if [ "$DAYS_OLD" -gt "$STALE_DAYS" ]; then
      IS_STALE=true
    fi
  fi

  # Skip if not a cleanup candidate
  if [ "$IS_MERGED" = false ] && [ "$IS_STALE" = false ]; then
    continue
  fi

  # Check for uncommitted changes
  HAS_CHANGES=false
  if [ -d "$WORKTREE_PATH" ]; then
    cd "$WORKTREE_PATH"
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
      HAS_CHANGES=true
      SKIPPED_DIRTY=$((SKIPPED_DIRTY + 1))
      echo "Skipping $BRANCH_NAME (uncommitted changes)" >&2
      cd - > /dev/null
      continue
    fi
    cd - > /dev/null
  fi

  # Remove worktree
  REASON="unknown"
  if [ "$IS_MERGED" = true ]; then
    REASON="merged"
  elif [ "$IS_STALE" = true ]; then
    REASON="stale"
  fi

  if [ "$DRY_RUN" = true ]; then
    echo "Would remove: $BRANCH_NAME ($REASON)" >&2
  else
    echo "Removing: $BRANCH_NAME ($REASON)" >&2
    if git worktree remove "$WORKTREE_PATH" 2>&1; then
      REMOVED_BRANCHES+=("$BRANCH_NAME")
      if [ "$IS_MERGED" = true ]; then
        REMOVED_MERGED=$((REMOVED_MERGED + 1))
      fi
      if [ "$IS_STALE" = true ]; then
        REMOVED_STALE=$((REMOVED_STALE + 1))
      fi
    else
      echo "Warning: Failed to remove worktree for $BRANCH_NAME" >&2
      SKIPPED_DIRTY=$((SKIPPED_DIRTY + 1))
    fi
  fi

done <<< "$WORKTREES"

# Output results as JSON
BRANCHES_JSON=$(printf '%s\n' "${REMOVED_BRANCHES[@]}" | jq -R . | jq -s . 2>/dev/null || echo "[]")

cat <<EOF
{
  "status": "success",
  "removed_merged": $REMOVED_MERGED,
  "removed_stale": $REMOVED_STALE,
  "skipped_dirty": $SKIPPED_DIRTY,
  "dry_run": $DRY_RUN,
  "branches": $BRANCHES_JSON
}
EOF

exit 0
