#!/bin/bash

# Read Git Status Cache
# This script reads the cached git status and outputs requested fields
# Part of fractary-repo plugin - provides fast status access without git queries
# Falls back to live git query if cache is stale or missing

set -euo pipefail

# Configuration
CACHE_DIR="${HOME}/.fractary/repo"
CACHE_FILE="${CACHE_DIR}/status.cache"
MAX_AGE_SECONDS=30  # Normal staleness threshold (not used for auto-refresh)

# Emergency refresh threshold: 300 seconds (5 minutes)
# Rationale: Hooks (UserPromptSubmit, Stop) keep cache fresh under normal operation.
# If cache exceeds 5 minutes, hooks likely failed due to:
#   - Hook disabled/removed by user
#   - Hook execution errors (permissions, missing deps)
#   - System issues (disk full, process limits)
# 5 minutes chosen as balance between:
#   - Long enough to avoid false positives during normal multi-minute operations
#   - Short enough to prevent stale data causing confusion
#   - Typical session length (most coding sessions have activity within 5 min)
CRITICAL_AGE_SECONDS=300

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to get cache age in seconds
get_cache_age() {
    if [ ! -f "${CACHE_FILE}" ]; then
        echo "999999"  # Very old if doesn't exist
        return
    fi

    # Get cache file modification time
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        CACHE_MTIME=$(stat -f %m "${CACHE_FILE}" 2>/dev/null || echo "0")
    else
        # Linux
        CACHE_MTIME=$(stat -c %Y "${CACHE_FILE}" 2>/dev/null || echo "0")
    fi

    # Get current time
    CURRENT_TIME=$(date +%s)

    # Calculate age
    AGE=$((CURRENT_TIME - CACHE_MTIME))
    echo "$AGE"
}

# Function to check if cache is stale
is_cache_stale() {
    local age=$(get_cache_age)
    if [ "$age" -gt "$MAX_AGE_SECONDS" ]; then
        return 0  # Stale
    fi
    return 1  # Fresh
}

# Function to check if cache is critically stale (emergency recovery)
is_cache_critically_stale() {
    local age=$(get_cache_age)
    if [ "$age" -gt "$CRITICAL_AGE_SECONDS" ]; then
        return 0  # Critically stale
    fi
    return 1  # Not critically stale
}

# Function to update cache if needed
# Auto-refresh is MOSTLY disabled to prevent git lock conflicts during normal operations
# Cache is kept fresh by hooks (UserPromptSubmit, Stop) in normal circumstances
# However, if cache becomes critically stale (>5 min), attempt emergency recovery
ensure_fresh_cache() {
    # Check if cache is critically stale (hooks may have failed)
    if is_cache_critically_stale; then
        # Emergency recovery: cache is > 5 minutes old, hooks likely failed
        echo -e "${YELLOW}⚠️  Warning: Cache is very stale (>5 min), attempting emergency refresh...${NC}" >&2
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if "${SCRIPT_DIR}/update-status-cache.sh" --quiet 2>/dev/null; then
            echo -e "${YELLOW}✓ Cache refreshed${NC}" >&2
        else
            echo -e "${YELLOW}⚠️  Could not refresh cache (may be locked)${NC}" >&2
        fi
    fi
    # Normal staleness (30s-5min): no action, rely on hooks
    return 0
}

# Function to read field from JSON cache
read_cache_field() {
    local field="$1"

    if [ ! -f "${CACHE_FILE}" ]; then
        echo "0"
        return 1
    fi

    # Use grep/sed for simple JSON parsing (no jq dependency)
    local value=$(grep "\"${field}\"" "${CACHE_FILE}" | sed -E 's/.*: *([^,}]*).*/\1/' | tr -d '"' | tr -d ' ')

    if [ -z "$value" ]; then
        echo "0"
        return 1
    fi

    echo "$value"
    return 0
}

# Main logic
main() {
    # Ensure cache exists and is fresh
    ensure_fresh_cache

    # If no arguments, output entire cache
    if [ $# -eq 0 ]; then
        if [ -f "${CACHE_FILE}" ]; then
            cat "${CACHE_FILE}"
        else
            echo -e "${RED}❌ Cache file not found${NC}" >&2
            exit 1
        fi
        exit 0
    fi

    # Output requested fields
    local first=true
    for field in "$@"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo -n " "
        fi

        case "$field" in
            timestamp|repo_path|branch)
                read_cache_field "$field"
                ;;
            uncommitted_changes|uncommitted|changes)
                read_cache_field "uncommitted_changes"
                ;;
            untracked_files|untracked)
                read_cache_field "untracked_files"
                ;;
            commits_ahead|ahead)
                read_cache_field "commits_ahead"
                ;;
            commits_behind|behind)
                read_cache_field "commits_behind"
                ;;
            has_conflicts|conflicts)
                read_cache_field "has_conflicts"
                ;;
            stash_count|stash)
                read_cache_field "stash_count"
                ;;
            clean)
                read_cache_field "clean"
                ;;
            *)
                echo -e "${RED}❌ Unknown field: ${field}${NC}" >&2
                echo "Valid fields: timestamp, repo_path, branch, uncommitted_changes, untracked_files, commits_ahead, commits_behind, has_conflicts, stash_count, clean" >&2
                exit 1
                ;;
        esac
    done

    echo  # Final newline
}

# Run main
main "$@"
