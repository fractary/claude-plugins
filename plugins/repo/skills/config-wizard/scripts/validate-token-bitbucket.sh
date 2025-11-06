#!/usr/bin/env bash
#
# validate-token-bitbucket.sh - Validates Bitbucket authentication
#
# Usage: validate-token-bitbucket.sh
#
# Environment:
#   BITBUCKET_TOKEN: Bitbucket App Password
#   BITBUCKET_USERNAME: Bitbucket username
#
# Outputs (JSON):
# {
#   "valid": true|false,
#   "user": "username"
# }
#
# Exit codes:
#   0: Token is valid
#   11: Token validation failed

set -euo pipefail

VALID=false
USER=""

# Bitbucket requires both username and token
if [ -n "${BITBUCKET_USERNAME:-}" ] && [ -n "${BITBUCKET_TOKEN:-}" ]; then
    RESPONSE=$(curl -s -u "$BITBUCKET_USERNAME:$BITBUCKET_TOKEN" \
        https://api.bitbucket.org/2.0/user 2>/dev/null || echo "{}")

    if echo "$RESPONSE" | jq -e '.username' >/dev/null 2>&1; then
        VALID=true
        USER=$(echo "$RESPONSE" | jq -r '.username')
    fi
fi

# Output JSON using jq --arg for safety
if [ "$VALID" = true ]; then
    jq -n \
        --argjson valid true \
        --arg user "$USER" \
        --argjson cli_available false \
        '{
            valid: $valid,
            user: $user,
            cli_available: $cli_available
        }'
    exit 0
else
    jq -n \
        --argjson valid false \
        --arg error "Bitbucket authentication failed. Requires BITBUCKET_USERNAME and BITBUCKET_TOKEN." \
        --argjson cli_available false \
        '{
            valid: $valid,
            error: $error,
            cli_available: $cli_available
        }'
    exit 11
fi
