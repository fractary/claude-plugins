#!/bin/bash
# Check if worktree exists for a given work_id
# Usage: check-worktree.sh <work_id>
# Returns: 0 if worktree exists and is valid, 1 otherwise
# Outputs: worktree path to stdout if exists

set -euo pipefail

WORK_ID="$1"
REGISTRY_FILE="${HOME}/.fractary/repo/worktrees.json"

# Ensure registry directory exists
mkdir -p "$(dirname "$REGISTRY_FILE")"

# Initialize registry if doesn't exist
if [ ! -f "$REGISTRY_FILE" ]; then
    echo '{}' > "$REGISTRY_FILE"
    exit 1
fi

# Check if work_id has existing worktree
EXISTING_WORKTREE=$(jq -r --arg work_id "$WORK_ID" '.[$work_id].worktree_path // empty' "$REGISTRY_FILE")

if [ -n "$EXISTING_WORKTREE" ]; then
    # Check if worktree still exists (path validation)
    if [ -d "$EXISTING_WORKTREE" ]; then
        echo "$EXISTING_WORKTREE"
        exit 0
    else
        # Path doesn't exist - remove stale entry
        jq --arg work_id "$WORK_ID" 'del(.[$work_id])' \
           "$REGISTRY_FILE" > "${REGISTRY_FILE}.tmp" && mv "${REGISTRY_FILE}.tmp" "$REGISTRY_FILE"
        exit 1
    fi
fi

# No worktree found
exit 1
