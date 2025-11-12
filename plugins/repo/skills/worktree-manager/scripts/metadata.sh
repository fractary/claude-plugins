#!/usr/bin/env bash
#
# metadata.sh - Manage worktree metadata in .fractary/plugins/repo/worktrees.json
#
# Usage: metadata.sh <operation> [args...]
#
# Operations:
#   add <branch> <path> <work_id>  - Add worktree entry
#   remove <branch>                 - Remove worktree entry
#   list                           - List all entries
#   get <branch>                   - Get entry for branch
#   init                          - Initialize metadata file
#
# Exit codes:
#   0 - Success
#   1 - Error
#   2 - Invalid arguments

set -euo pipefail

METADATA_DIR=".fractary/plugins/repo"
METADATA_FILE="$METADATA_DIR/worktrees.json"

# Initialize metadata file if it doesn't exist
init_metadata() {
  mkdir -p "$METADATA_DIR"
  if [ ! -f "$METADATA_FILE" ]; then
    echo '{"worktrees":[]}' > "$METADATA_FILE"
  fi
}

# Add worktree entry
add_entry() {
  local BRANCH="$1"
  local PATH="$2"
  local WORK_ID="${3:-}"

  init_metadata

  # Create timestamp
  local CREATED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Read current metadata
  local CURRENT=$(cat "$METADATA_FILE")

  # Add new entry using jq
  local UPDATED=$(echo "$CURRENT" | jq --arg branch "$BRANCH" \
    --arg path "$PATH" \
    --arg work_id "$WORK_ID" \
    --arg created "$CREATED" \
    '.worktrees += [{
      "path": $path,
      "branch": $branch,
      "work_id": $work_id,
      "created": $created,
      "status": "active"
    }]')

  echo "$UPDATED" > "$METADATA_FILE"
  echo "Added metadata entry for $BRANCH" >&2
}

# Remove worktree entry
remove_entry() {
  local BRANCH="$1"

  if [ ! -f "$METADATA_FILE" ]; then
    echo "Warning: Metadata file does not exist" >&2
    return 0
  fi

  # Read current metadata
  local CURRENT=$(cat "$METADATA_FILE")

  # Remove entry using jq
  local UPDATED=$(echo "$CURRENT" | jq --arg branch "$BRANCH" \
    '.worktrees = [.worktrees[] | select(.branch != $branch)]')

  echo "$UPDATED" > "$METADATA_FILE"
  echo "Removed metadata entry for $BRANCH" >&2
}

# List all entries
list_entries() {
  if [ ! -f "$METADATA_FILE" ]; then
    echo '{"worktrees":[]}'
    return 0
  fi

  cat "$METADATA_FILE"
}

# Get entry for specific branch
get_entry() {
  local BRANCH="$1"

  if [ ! -f "$METADATA_FILE" ]; then
    echo "null"
    return 0
  fi

  cat "$METADATA_FILE" | jq --arg branch "$BRANCH" \
    '.worktrees[] | select(.branch == $branch)'
}

# Main operation dispatcher
OPERATION="${1:-}"

case "$OPERATION" in
  init)
    init_metadata
    ;;
  add)
    if [ $# -lt 3 ]; then
      echo "Error: add requires branch, path, and optional work_id" >&2
      exit 2
    fi
    add_entry "$2" "$3" "${4:-}"
    ;;
  remove)
    if [ $# -lt 2 ]; then
      echo "Error: remove requires branch" >&2
      exit 2
    fi
    remove_entry "$2"
    ;;
  list)
    list_entries
    ;;
  get)
    if [ $# -lt 2 ]; then
      echo "Error: get requires branch" >&2
      exit 2
    fi
    get_entry "$2"
    ;;
  *)
    echo "Error: Unknown operation: $OPERATION" >&2
    echo "Valid operations: init, add, remove, list, get" >&2
    exit 2
    ;;
esac

exit 0
