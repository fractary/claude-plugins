#!/bin/bash
# Search archived logs via index
set -euo pipefail

QUERY="${1:?Query required}"
ISSUE_FILTER="${2:-}"
CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration not found at $CONFIG_FILE" >&2
    exit 1
fi

LOG_DIR=$(jq -r '.storage.local_path // "/logs"' "$CONFIG_FILE")
INDEX_FILE="$LOG_DIR/.archive-index.json"

# Check if index exists
if [[ ! -f "$INDEX_FILE" ]]; then
    echo "Archive index not found. No cloud logs to search."
    exit 0
fi

# Search index metadata first (fast check)
MATCHING_ISSUES=()

if [[ -n "$ISSUE_FILTER" ]]; then
    # Search specific issue
    MATCHING_ISSUES+=("$ISSUE_FILTER")
else
    # Search all archived issues for query in title or metadata
    while IFS= read -r issue; do
        MATCHING_ISSUES+=("$issue")
    done < <(jq -r --arg query "$QUERY" \
        '.archives[] |
         select(
           (.issue_title | test($query; "i")) or
           (.issue_number | test($query; "i"))
         ) |
         .issue_number' \
        "$INDEX_FILE" 2>/dev/null || true)
fi

if [[ ${#MATCHING_ISSUES[@]} -eq 0 ]]; then
    echo "No matches in archive index metadata"
    exit 0
fi

echo "Found ${#MATCHING_ISSUES[@]} potentially matching archived issues"
echo "Searching archived log contents..."
echo

# For each matching issue, get log URLs and search content
MATCHES=0
for ISSUE in "${MATCHING_ISSUES[@]}"; do
    # Get log URLs for this issue
    LOGS=$(jq -r --arg issue "$ISSUE" \
        '.archives[] |
         select(.issue_number == $issue) |
         .logs[] |
         "\(.cloud_url)|\(.filename)|\(.type)"' \
        "$INDEX_FILE" 2>/dev/null || true)

    if [[ -z "$LOGS" ]]; then
        continue
    fi

    # For each log, attempt to read and search
    # Note: This is a placeholder for fractary-file integration
    # In actual implementation, this would use file-manager agent to read from cloud
    while IFS='|' read -r URL FILENAME TYPE; do
        echo "# Would search $FILENAME in cloud storage at $URL" >&2

        # TODO: Actual implementation should:
        # 1. Use fractary-file agent to read content from cloud URL
        # 2. Search the content for query
        # 3. Extract matches with context
        # 4. Format and display results

        # For now, just indicate the file would be searched
        echo "[Archived] $FILENAME (Issue #$ISSUE, Type: $TYPE)"
        echo "  Cloud URL: $URL"
        echo "  Content search not yet implemented - requires fractary-file integration"
        echo

        ((MATCHES++))
    done <<< "$LOGS"
done

if [[ $MATCHES -eq 0 ]]; then
    echo "No matches found in archived logs"
else
    echo "Found $MATCHES archived log files matching criteria"
fi
