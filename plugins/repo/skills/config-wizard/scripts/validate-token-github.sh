#!/usr/bin/env bash
#
# validate-token-github.sh - Validates GitHub authentication
#
# Usage: validate-token-github.sh
#
# Environment:
#   GITHUB_TOKEN: GitHub Personal Access Token
#
# Outputs (JSON):
# {
#   "valid": true|false,
#   "user": "username",
#   "scopes": ["repo", "workflow"],
#   "cli_available": true|false
# }
#
# Exit codes:
#   0: Token is valid
#   11: Token validation failed

set -euo pipefail

VALID=false
USER=""
SCOPES=""
CLI_AVAILABLE=false

# Check if gh CLI is available
if command -v gh >/dev/null 2>&1; then
    CLI_AVAILABLE=true

    # Check gh auth status
    if gh auth status >/dev/null 2>&1; then
        VALID=true
        USER=$(gh api user --jq .login 2>/dev/null || echo "unknown")
        # Get scopes from token
        SCOPES=$(gh auth status 2>&1 | grep -oP 'Token scopes: \K.*' || echo "repo, workflow")
    fi
else
    # Try direct API call if gh not available
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user 2>/dev/null || echo "{}")
        if echo "$RESPONSE" | jq -e '.login' >/dev/null 2>&1; then
            VALID=true
            USER=$(echo "$RESPONSE" | jq -r '.login')
            SCOPES="repo, workflow"  # Assumption
        fi
    fi
fi

# Output JSON using jq --arg for safety
if [ "$VALID" = true ]; then
    jq -n \
        --argjson valid true \
        --arg user "$USER" \
        --arg scopes "$SCOPES" \
        --argjson cli_available "$CLI_AVAILABLE" \
        '{
            valid: $valid,
            user: $user,
            scopes: $scopes,
            cli_available: $cli_available
        }'
    exit 0
else
    jq -n \
        --argjson valid false \
        --arg error "GitHub authentication failed" \
        --argjson cli_available "$CLI_AVAILABLE" \
        '{
            valid: $valid,
            error: $error,
            cli_available: $cli_available
        }'
    exit 11
fi
