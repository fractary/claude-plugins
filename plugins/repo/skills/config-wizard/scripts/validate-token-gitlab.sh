#!/usr/bin/env bash
#
# validate-token-gitlab.sh - Validates GitLab authentication
#
# Usage: validate-token-gitlab.sh
#
# Environment:
#   GITLAB_TOKEN: GitLab Personal Access Token
#
# Outputs (JSON):
# {
#   "valid": true|false,
#   "user": "username",
#   "cli_available": true|false
# }
#
# Exit codes:
#   0: Token is valid
#   11: Token validation failed

set -euo pipefail

VALID=false
USER=""
CLI_AVAILABLE=false

# Check if glab CLI is available
if command -v glab >/dev/null 2>&1; then
    CLI_AVAILABLE=true

    # Check glab auth status
    if glab auth status >/dev/null 2>&1; then
        VALID=true
        USER=$(glab api user --jq .username 2>/dev/null || echo "unknown")
    fi
else
    # Try direct API call if glab not available
    if [ -n "${GITLAB_TOKEN:-}" ]; then
        RESPONSE=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" https://gitlab.com/api/v4/user 2>/dev/null || echo "{}")
        if echo "$RESPONSE" | jq -e '.username' >/dev/null 2>&1; then
            VALID=true
            USER=$(echo "$RESPONSE" | jq -r '.username')
        fi
    fi
fi

# Output JSON using jq --arg for safety
if [ "$VALID" = true ]; then
    jq -n \
        --argjson valid true \
        --arg user "$USER" \
        --argjson cli_available "$CLI_AVAILABLE" \
        '{
            valid: $valid,
            user: $user,
            cli_available: $cli_available
        }'
    exit 0
else
    jq -n \
        --argjson valid false \
        --arg error "GitLab authentication failed" \
        --argjson cli_available "$CLI_AVAILABLE" \
        '{
            valid: $valid,
            error: $error,
            cli_available: $cli_available
        }'
    exit 11
fi
