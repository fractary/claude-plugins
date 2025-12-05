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
#
# Security:
#   - All inputs are validated for format
#   - Uses flock with retry logic and stale lock detection
#   - Proper cleanup on exit via trap

set -euo pipefail

# Path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default knowledge base location
KB_PATH="${KB_PATH:-.fractary/plugins/faber/debugger/knowledge-base}"
INDEX_FILE="$KB_PATH/index.json"
LOCK_FILE="$INDEX_FILE.lock"

# Lock configuration
LOCK_TIMEOUT=10
LOCK_RETRY_MAX=5
LOCK_RETRY_DELAY=1
LOCK_STALE_SECONDS=300  # 5 minutes - locks older than this are considered stale

# =============================================================================
# Input Validation Functions
# =============================================================================

# Validate KB ID format (alphanumeric, hyphens, must start with letter)
validate_kb_id() {
    local id="$1"
    if [[ ! "$id" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        echo '{"status": "error", "message": "Invalid KB ID format. Must start with letter and contain only alphanumeric, hyphens, or underscores."}' >&2
        exit 1
    fi
    # Check length limits
    if [[ ${#id} -gt 64 ]]; then
        echo '{"status": "error", "message": "KB ID too long. Maximum 64 characters."}' >&2
        exit 1
    fi
}

# Validate path format (no path traversal, reasonable characters)
validate_path() {
    local path="$1"
    # Check for path traversal attempts
    if [[ "$path" =~ \.\. ]] || [[ "$path" =~ ^/ ]]; then
        echo '{"status": "error", "message": "Invalid path. No absolute paths or path traversal allowed."}' >&2
        exit 1
    fi
    # Check for valid path characters
    if [[ ! "$path" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
        echo '{"status": "error", "message": "Invalid path characters. Use only alphanumeric, slashes, dots, hyphens, underscores."}' >&2
        exit 1
    fi
}

# Validate comma-separated list (no shell metacharacters)
validate_list() {
    local list="$1"
    local name="$2"
    # Allow alphanumeric, spaces, commas, hyphens, underscores
    if [[ -n "$list" ]] && [[ ! "$list" =~ ^[a-zA-Z0-9\ ,_-]+$ ]]; then
        echo "{\"status\": \"error\", \"message\": \"Invalid characters in $name. Use only alphanumeric, spaces, commas, hyphens, underscores.\"}" >&2
        exit 1
    fi
}

# =============================================================================
# Lock Management Functions
# =============================================================================

# File descriptor for lock
LOCK_FD=200

# Cleanup function - called on exit
cleanup() {
    # Release lock if held
    if [ -n "${LOCK_ACQUIRED:-}" ]; then
        flock -u "$LOCK_FD" 2>/dev/null || true
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Check if lock file is stale (older than LOCK_STALE_SECONDS)
is_lock_stale() {
    if [ ! -f "$LOCK_FILE" ]; then
        return 1  # No lock file, not stale
    fi

    local lock_age
    local current_time
    current_time=$(date +%s)
    lock_mtime=$(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo "$current_time")
    lock_age=$((current_time - lock_mtime))

    if [ "$lock_age" -gt "$LOCK_STALE_SECONDS" ]; then
        return 0  # Lock is stale
    fi
    return 1  # Lock is fresh
}

# Acquire lock with retry logic and exponential backoff
acquire_lock() {
    local attempt=0
    local delay=$LOCK_RETRY_DELAY

    while [ $attempt -lt $LOCK_RETRY_MAX ]; do
        attempt=$((attempt + 1))

        # Check for stale lock before attempting
        if is_lock_stale; then
            echo "{\"warning\": \"Removing stale lock file (age > ${LOCK_STALE_SECONDS}s)\"}" >&2
            rm -f "$LOCK_FILE"
        fi

        # Open file descriptor for lock
        exec 200>"$LOCK_FILE"

        # Try to acquire lock
        if flock -w "$LOCK_TIMEOUT" "$LOCK_FD" 2>/dev/null; then
            # Update lock file timestamp to indicate it's active
            touch "$LOCK_FILE"
            LOCK_ACQUIRED=1
            return 0
        fi

        # Lock failed - retry with exponential backoff
        if [ $attempt -lt $LOCK_RETRY_MAX ]; then
            echo "{\"warning\": \"Lock attempt $attempt failed, retrying in ${delay}s...\"}" >&2
            sleep "$delay"
            delay=$((delay * 2))  # Exponential backoff
            if [ $delay -gt 30 ]; then
                delay=30  # Cap at 30 seconds
            fi
        fi
    done

    echo '{"status": "error", "message": "Could not acquire lock after multiple attempts. Another process may be holding it."}' >&2
    return 1
}

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

# Validate input formats (security)
validate_kb_id "$KB_ID"
validate_path "$ENTRY_PATH"
validate_list "$KEYWORDS" "keywords"
validate_list "$PATTERNS" "patterns"

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

# Acquire exclusive lock for write (with retry and stale detection)
if ! acquire_lock; then
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

# Lock is automatically released by cleanup trap on exit

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
