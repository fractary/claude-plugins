#!/usr/bin/env bash
# Read cache index and check entry status
#
# Usage:
#   ./read-cache-index.sh check <uri>           Check if URI is cached and fresh
#   ./read-cache-index.sh list [options]        List cache entries
#   ./read-cache-index.sh stats                 Show cache statistics
#
# Output: JSON with cache information
#
# This is a convenience wrapper around lib/cache-manager.sh
#
# List options:
#   --org <org>        Filter by organization
#   --project <project> Filter by project
#   --stale            Show only stale entries
#
# Examples:
#   ./read-cache-index.sh check "codex://fractary/project/docs/guide.md"
#   ./read-cache-index.sh list --org fractary
#   ./read-cache-index.sh stats

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# Validate lib directory exists
if [[ ! -d "$LIB_DIR" ]]; then
  echo '{"error": "lib directory not found", "expected": "'"$LIB_DIR"'"}' >&2
  exit 1
fi

command="${1:-help}"

case "$command" in
  check)
    shift
    exec "$LIB_DIR/cache-manager.sh" check "$@"
    ;;
  list)
    shift
    exec "$LIB_DIR/cache-manager.sh" list "$@"
    ;;
  stats)
    exec "$LIB_DIR/cache-manager.sh" stats
    ;;
  help|--help|-h)
    echo "Usage: read-cache-index.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  check <uri>          Check if URI is cached and fresh"
    echo "  list [options]       List cache entries"
    echo "  stats                Show cache statistics"
    echo ""
    echo "List options:"
    echo "  --org <org>          Filter by organization"
    echo "  --project <project>  Filter by project"
    echo "  --stale              Show only stale entries"
    ;;
  *)
    echo '{"error": "Unknown command: '"$command"'", "usage": "read-cache-index.sh check|list|stats"}' >&2
    exit 1
    ;;
esac
