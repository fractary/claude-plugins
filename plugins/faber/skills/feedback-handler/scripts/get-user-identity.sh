#!/usr/bin/env bash
#
# get-user-identity.sh - Get current user identity for feedback attribution
#
# Usage:
#   get-user-identity.sh [--source <cli|issue>] [--issue-author <username>]
#
# Output: JSON object with user identity
#
# Exit Codes:
#   0 - Success
#   1 - Error getting identity

set -euo pipefail

# Parse arguments
SOURCE="cli"
ISSUE_AUTHOR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --source)
            SOURCE="$2"
            shift 2
            ;;
        --issue-author)
            ISSUE_AUTHOR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Get timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ "$SOURCE" == "issue" ]] && [[ -n "$ISSUE_AUTHOR" ]]; then
    # Issue comment - use provided author
    jq -n \
        --arg user "$ISSUE_AUTHOR" \
        --arg source "issue_comment" \
        --arg timestamp "$TIMESTAMP" \
        '{
            user: $user,
            source: $source,
            timestamp: $timestamp,
            method: "issue_comment_author"
        }'
else
    # CLI - get from git config or environment
    USERNAME=""
    EMAIL=""
    METHOD="unknown"

    # Try git config first
    if command -v git &>/dev/null; then
        USERNAME=$(git config user.name 2>/dev/null || true)
        EMAIL=$(git config user.email 2>/dev/null || true)
        if [[ -n "$USERNAME" ]]; then
            METHOD="git_config"
        fi
    fi

    # Fallback to environment
    if [[ -z "$USERNAME" ]]; then
        USERNAME="${USER:-${LOGNAME:-unknown}}"
        METHOD="environment"
    fi

    # Build identity object
    if [[ -n "$EMAIL" ]]; then
        jq -n \
            --arg user "$USERNAME" \
            --arg email "$EMAIL" \
            --arg source "cli" \
            --arg timestamp "$TIMESTAMP" \
            --arg method "$METHOD" \
            '{
                user: $user,
                email: $email,
                source: $source,
                timestamp: $timestamp,
                method: $method
            }'
    else
        jq -n \
            --arg user "$USERNAME" \
            --arg source "cli" \
            --arg timestamp "$TIMESTAMP" \
            --arg method "$METHOD" \
            '{
                user: $user,
                source: $source,
                timestamp: $timestamp,
                method: $method
            }'
    fi
fi

exit 0
