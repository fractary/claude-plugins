#!/bin/bash
# Register or update worktree in registry
# Usage: register-worktree.sh <work_id> <worktree_path> <branch_name>
# Returns: 0 on success, 1 on failure

set -euo pipefail

WORK_ID="$1"
WORKTREE_PATH="$2"
BRANCH_NAME="$3"
REGISTRY_FILE="${HOME}/.fractary/repo/worktrees.json"

# Ensure registry directory exists
mkdir -p "$(dirname "$REGISTRY_FILE")"

# Initialize registry if doesn't exist
if [ ! -f "$REGISTRY_FILE" ]; then
    echo '{}' > "$REGISTRY_FILE"
fi

# Get repository root
REPO_ROOT=$(git rev-parse --show-toplevel)

# Register or update worktree entry
jq --arg work_id "$WORK_ID" \
   --arg worktree_path "$WORKTREE_PATH" \
   --arg branch "$BRANCH_NAME" \
   --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg last_used "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg repo_root "$REPO_ROOT" \
   '.[$work_id] = {
      "worktree_path": $worktree_path,
      "branch": $branch,
      "created": (if .[$work_id].created then .[$work_id].created else $created end),
      "last_used": $last_used,
      "repo_root": $repo_root
   }' \
   "$REGISTRY_FILE" > "${REGISTRY_FILE}.tmp" && mv "${REGISTRY_FILE}.tmp" "$REGISTRY_FILE"

echo "✅ Worktree registered: $WORKTREE_PATH"
exit 0
