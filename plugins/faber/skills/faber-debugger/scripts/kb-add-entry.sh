#!/usr/bin/env bash
#
# kb-add-entry.sh - Add or update an entry in the knowledge base index
#
# Usage:
#   kb-add-entry.sh --id <kb_id> --path <relative_path> [options]
#
# Options:
#   --id <kb_id>           Knowledge base entry ID (e.g., faber-debug-048)
#   --path <path>          Relative path within KB (e.g., build/faber-debug-048-type.md)
#   --category <cat>       Category (workflow|build|test|deploy|general)
#   --issue-pattern <pat>  Brief pattern description
#   --keywords <list>      Comma-separated keywords
#   --patterns <list>      Comma-separated error patterns
#   --status <status>      Entry status (unverified|verified|deprecated)
#   --update               Update existing entry instead of creating new
#
# Examples:
#   kb-add-entry.sh --id faber-debug-048 --path build/faber-debug-048-type.md \
#     --category build --keywords "type error,annotation" --status unverified
#
# Output: JSON confirmation of the operation

set -euo pipefail

# Path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default knowledge base location
KB_PATH="${KB_PATH:-.fractary/plugins/faber/debugger/knowledge-base}"
INDEX_FILE="$KB_PATH/index.json"
LOCK_FILE="$INDEX_FILE.lock"
LOCK_TIMEOUT=10

# Defaults
KB_ID=""
ENTRY_PATH=""
CATEGORY="general"
ISSUE_PATTERN=""
KEYWORDS=""
PATTERNS=""
STATUS="unverified"
UPDATE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --id)
            KB_ID="${2:?KB ID required}"
            shift 2
            ;;
        --path)
            ENTRY_PATH="${2:?Path required}"
            shift 2
            ;;
        --category)
            CATEGORY="$2"
            shift 2
            ;;
        --issue-pattern)
            ISSUE_PATTERN="$2"
            shift 2
            ;;
        --keywords)
            KEYWORDS="$2"
            shift 2
            ;;
        --patterns)
            PATTERNS="$2"
            shift 2
            ;;
        --status)
            STATUS="$2"
            shift 2
            ;;
        --update)
            UPDATE=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$KB_ID" ]; then
    echo '{"status": "error", "message": "--id is required"}' >&2
    exit 1
fi

if [ -z "$ENTRY_PATH" ]; then
    echo '{"status": "error", "message": "--path is required"}' >&2
    exit 1
fi

# Validate category
case "$CATEGORY" in
    workflow|build|test|deploy|general) ;;
    *)
        echo "{\"status\": \"error\", \"message\": \"Invalid category: $CATEGORY\"}" >&2
        exit 1
        ;;
esac

# Validate status
case "$STATUS" in
    unverified|verified|deprecated) ;;
    *)
        echo "{\"status\": \"error\", \"message\": \"Invalid status: $STATUS\"}" >&2
        exit 1
        ;;
esac

# Ensure KB directory exists
mkdir -p "$KB_PATH"

# Initialize index if it doesn't exist
if [ ! -f "$INDEX_FILE" ]; then
    echo '{"version": "1.0", "entries": {}, "last_updated": ""}' > "$INDEX_FILE"
fi

# Convert comma-separated lists to JSON arrays
keywords_json="[]"
if [ -n "$KEYWORDS" ]; then
    keywords_json=$(echo "$KEYWORDS" | tr ',' '\n' | jq -R . | jq -s .)
fi

patterns_json="[]"
if [ -n "$PATTERNS" ]; then
    patterns_json=$(echo "$PATTERNS" | tr ',' '\n' | jq -R . | jq -s .)
fi

# Acquire exclusive lock for write
exec 200>"$LOCK_FILE"
if ! flock -w "$LOCK_TIMEOUT" 200; then
    echo '{"status": "error", "message": "Could not acquire lock on index file"}' >&2
    exit 1
fi

# Read current index
INDEX_CONTENT=$(cat "$INDEX_FILE")

# Check if entry exists
ENTRY_EXISTS=$(echo "$INDEX_CONTENT" | jq --arg id "$KB_ID" '.entries[$id] != null')

if [ "$ENTRY_EXISTS" = "true" ] && [ "$UPDATE" = "false" ]; then
    echo "{\"status\": \"error\", \"message\": \"Entry $KB_ID already exists. Use --update to modify.\"}" >&2
    exit 1
fi

if [ "$ENTRY_EXISTS" = "false" ] && [ "$UPDATE" = "true" ]; then
    echo "{\"status\": \"error\", \"message\": \"Entry $KB_ID not found. Cannot update.\"}" >&2
    exit 1
fi

# Get current date
CURRENT_DATE=$(date +%Y-%m-%d)

# Create entry object
ENTRY_OBJ=$(jq -n \
    --arg path "$ENTRY_PATH" \
    --arg category "$CATEGORY" \
    --arg issue_pattern "$ISSUE_PATTERN" \
    --argjson keywords "$keywords_json" \
    --argjson patterns "$patterns_json" \
    --arg status "$STATUS" \
    --arg created "$CURRENT_DATE" \
    --arg last_used "$CURRENT_DATE" \
    '{
        path: $path,
        category: $category,
        issue_pattern: $issue_pattern,
        keywords: $keywords,
        patterns: $patterns,
        status: $status,
        created: $created,
        last_used: $last_used,
        usage_count: 1
    }')

# For updates, preserve certain fields
if [ "$UPDATE" = "true" ]; then
    EXISTING=$(echo "$INDEX_CONTENT" | jq --arg id "$KB_ID" '.entries[$id]')
    ORIGINAL_CREATED=$(echo "$EXISTING" | jq -r '.created // ""')
    USAGE_COUNT=$(echo "$EXISTING" | jq -r '.usage_count // 0')

    ENTRY_OBJ=$(echo "$ENTRY_OBJ" | jq \
        --arg created "$ORIGINAL_CREATED" \
        --argjson usage_count "$((USAGE_COUNT + 1))" \
        '.created = $created | .usage_count = $usage_count')
fi

# Update index
UPDATED_INDEX=$(echo "$INDEX_CONTENT" | jq \
    --arg id "$KB_ID" \
    --argjson entry "$ENTRY_OBJ" \
    --arg updated "$CURRENT_DATE" \
    '.entries[$id] = $entry | .last_updated = $updated')

# Write updated index
echo "$UPDATED_INDEX" > "$INDEX_FILE"

# Release lock
flock -u 200

# Success output
ACTION="created"
if [ "$UPDATE" = "true" ]; then
    ACTION="updated"
fi

jq -n \
    --arg status "success" \
    --arg message "Entry $ACTION successfully" \
    --arg action "$ACTION" \
    --arg kb_id "$KB_ID" \
    --arg path "$ENTRY_PATH" \
    --arg category "$CATEGORY" \
    --arg entry_status "$STATUS" \
    '{
        status: $status,
        message: $message,
        details: {
            action: $action,
            kb_id: $kb_id,
            path: $path,
            category: $category,
            entry_status: $entry_status
        }
    }'
