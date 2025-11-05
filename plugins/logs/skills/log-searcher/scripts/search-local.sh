#!/bin/bash
# Search local logs with grep
set -euo pipefail

QUERY="${1:?Query required}"
LOG_TYPE="${2:-all}"
MAX_RESULTS="${3:-100}"
CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration not found at $CONFIG_FILE" >&2
    exit 1
fi

LOG_DIR=$(jq -r '.storage.local_path // "/logs"' "$CONFIG_FILE")

# Determine search paths based on type filter
SEARCH_PATHS=()
case "$LOG_TYPE" in
    session)
        SEARCH_PATHS+=("$LOG_DIR/sessions")
        ;;
    build)
        SEARCH_PATHS+=("$LOG_DIR/builds")
        ;;
    deployment)
        SEARCH_PATHS+=("$LOG_DIR/deployments")
        ;;
    debug)
        SEARCH_PATHS+=("$LOG_DIR/debug")
        ;;
    all|*)
        SEARCH_PATHS+=("$LOG_DIR")
        ;;
esac

# Exclude archive index from search
EXCLUDE_PATTERN="--exclude=.archive-index.json"

# Search with context (3 lines before and after)
# -r: recursive
# -i: case insensitive
# -n: line numbers
# -C 3: 3 lines context
# --color=never: no color codes in output

RESULTS=()
for SEARCH_PATH in "${SEARCH_PATHS[@]}"; do
    if [[ -d "$SEARCH_PATH" ]]; then
        # Search and capture results
        while IFS= read -r line; do
            RESULTS+=("$line")
            if [[ ${#RESULTS[@]} -ge $MAX_RESULTS ]]; then
                break 2
            fi
        done < <(grep -r -i -n -C 3 --color=never "$EXCLUDE_PATTERN" "$QUERY" "$SEARCH_PATH" 2>/dev/null || true)
    fi
done

# Output results
if [[ ${#RESULTS[@]} -eq 0 ]]; then
    echo "No matches found in local logs"
    exit 0
fi

# Format results
echo "Found ${#RESULTS[@]} matches in local logs:"
echo
printf '%s\n' "${RESULTS[@]}"
