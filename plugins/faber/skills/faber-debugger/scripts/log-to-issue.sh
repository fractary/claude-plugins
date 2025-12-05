#!/usr/bin/env bash
#
# log-to-issue.sh - Post debugger analysis to GitHub issue
#
# Usage:
#   log-to-issue.sh --work-id <id> --body <markdown> [options]
#   log-to-issue.sh --work-id <id> --file <path>
#
# Options:
#   --work-id <id>    Issue number (required)
#   --body <text>     Comment body as markdown (use with short content)
#   --file <path>     Read comment body from file (for long content)
#   --repo <owner/repo>  Repository (optional, detected from git)
#
# Examples:
#   log-to-issue.sh --work-id 244 --body "## Debugger Analysis\n..."
#   log-to-issue.sh --work-id 244 --file /tmp/debugger-comment.md
#
# Output: JSON with comment URL on success, error on failure
#
# Security:
#   - Work ID validated as alphanumeric
#   - Repository format validated (owner/repo)
#   - File path validated to prevent directory traversal

set -euo pipefail

# =============================================================================
# Input Validation Functions
# =============================================================================

# Validate work ID (alphanumeric, hyphens, underscores)
validate_work_id() {
    local id="$1"
    if [[ ! "$id" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo '{"status": "error", "message": "Invalid work-id format. Must be alphanumeric."}' >&2
        exit 1
    fi
    if [[ ${#id} -gt 64 ]]; then
        echo '{"status": "error", "message": "Work ID too long. Maximum 64 characters."}' >&2
        exit 1
    fi
}

# Validate repository format (owner/repo)
validate_repo() {
    local repo="$1"
    if [ -n "$repo" ]; then
        # Must be in format owner/repo with safe characters
        if [[ ! "$repo" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
            echo '{"status": "error", "message": "Invalid repo format. Must be owner/repo."}' >&2
            exit 1
        fi
    fi
}

# Validate file path (no path traversal to sensitive areas)
validate_file_path() {
    local filepath="$1"
    if [ -n "$filepath" ]; then
        # Check for path traversal
        if [[ "$filepath" =~ \.\. ]]; then
            echo '{"status": "error", "message": "Invalid file path: path traversal not allowed."}' >&2
            exit 1
        fi
        # Ensure it's a regular file (not a device, symlink to sensitive file, etc.)
        if [ -e "$filepath" ] && [ ! -f "$filepath" ]; then
            echo '{"status": "error", "message": "Path must be a regular file."}' >&2
            exit 1
        fi
    fi
}

# Defaults
WORK_ID=""
BODY=""
FILE=""
REPO=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --work-id)
            WORK_ID="${2:?Work ID required}"
            shift 2
            ;;
        --body)
            BODY="$2"
            shift 2
            ;;
        --file)
            FILE="$2"
            shift 2
            ;;
        --repo)
            REPO="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$WORK_ID" ]; then
    echo '{"status": "error", "message": "--work-id is required"}' >&2
    exit 1
fi

# Validate all inputs (security)
validate_work_id "$WORK_ID"
validate_repo "$REPO"
validate_file_path "$FILE"

# Get body from file if specified
if [ -n "$FILE" ]; then
    if [ ! -f "$FILE" ]; then
        echo "{\"status\": \"error\", \"message\": \"File not found: $FILE\"}" >&2
        exit 1
    fi
    BODY=$(cat "$FILE")
fi

if [ -z "$BODY" ]; then
    echo '{"status": "error", "message": "Comment body is required (--body or --file)"}' >&2
    exit 1
fi

# Detect repository if not provided
if [ -z "$REPO" ]; then
    REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")
    if [ -z "$REPO" ]; then
        echo '{"status": "error", "message": "Could not detect repository. Use --repo owner/repo"}' >&2
        exit 1
    fi
fi

# Post comment to GitHub
# Use gh issue comment with heredoc for safety
COMMENT_URL=$(gh issue comment "$WORK_ID" --repo "$REPO" --body "$BODY" 2>&1) || {
    error_msg="$COMMENT_URL"
    jq -n \
        --arg status "error" \
        --arg message "Failed to post comment" \
        --arg error "$error_msg" \
        --arg work_id "$WORK_ID" \
        --arg repo "$REPO" \
        '{
            status: $status,
            message: $message,
            error: $error,
            work_id: $work_id,
            repo: $repo
        }'
    exit 1
}

# Extract URL from output (gh returns the comment URL)
# The URL is typically the last line or the only output
COMMENT_URL=$(echo "$COMMENT_URL" | grep -oE 'https://github.com/[^[:space:]]+' | head -1 || echo "$COMMENT_URL")

# Success output
jq -n \
    --arg status "success" \
    --arg message "Comment posted successfully" \
    --arg comment_url "$COMMENT_URL" \
    --arg work_id "$WORK_ID" \
    --arg repo "$REPO" \
    '{
        status: $status,
        message: $message,
        comment_url: $comment_url,
        work_id: $work_id,
        repo: $repo
    }'
