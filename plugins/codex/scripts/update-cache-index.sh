#!/usr/bin/env bash
# Update cache index with new or modified entries
#
# Usage: ./update-cache-index.sh <uri> [options]
# Output: JSON with update result
#
# This is a convenience wrapper around lib/cache-manager.sh put command
#
# Options:
#   --content-file <file>   Read content from file
#   --source <source>       Source identifier (e.g., "github", "http", "sync")
#   --ttl <seconds>         Time to live in seconds
#   --synced-via <method>   Sync method (e.g., "sync-project", "on-demand")
#
# Example:
#   ./update-cache-index.sh "codex://fractary/project/docs/guide.md" \
#     --content-file /tmp/guide.md \
#     --source github \
#     --synced-via sync-project

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# Validate lib directory exists
if [[ ! -d "$LIB_DIR" ]]; then
  echo '{"error": "lib directory not found", "expected": "'"$LIB_DIR"'"}' >&2
  exit 1
fi

# Pass all arguments to cache-manager.sh put command
exec "$LIB_DIR/cache-manager.sh" put "$@"
