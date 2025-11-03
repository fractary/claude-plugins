#!/bin/bash
# Work Common: Jira Authentication Helper
# Generates Basic Auth header for Jira API requests
# Usage: source ./jira-auth.sh (exports AUTH_HEADER variable)

# This script is meant to be sourced, not executed directly
# It validates environment variables and creates auth header

# Check required environment variables
if [ -z "${JIRA_EMAIL:-}" ]; then
    echo "Error: JIRA_EMAIL environment variable not set" >&2
    echo "  Set it with: export JIRA_EMAIL=user@example.com" >&2
    return 1 2>/dev/null || exit 1
fi

if [ -z "${JIRA_TOKEN:-}" ]; then
    echo "Error: JIRA_TOKEN environment variable not set" >&2
    echo "  Generate token at: https://id.atlassian.com/manage-profile/security/api-tokens" >&2
    echo "  Set it with: export JIRA_TOKEN=your_api_token_here" >&2
    return 1 2>/dev/null || exit 1
fi

if [ -z "${JIRA_URL:-}" ]; then
    echo "Error: JIRA_URL environment variable not set" >&2
    echo "  Set it with: export JIRA_URL=https://yourcompany.atlassian.net" >&2
    return 1 2>/dev/null || exit 1
fi

# Generate Basic Auth header
# Format: Base64(email:token)
export AUTH_HEADER=$(echo -n "$JIRA_EMAIL:$JIRA_TOKEN" | base64 -w 0 2>/dev/null || echo -n "$JIRA_EMAIL:$JIRA_TOKEN" | base64)

# Verify base64 encoding succeeded
if [ -z "$AUTH_HEADER" ]; then
    echo "Error: Failed to generate authentication header" >&2
    return 1 2>/dev/null || exit 1
fi

# Export for use in curl commands
export JIRA_AUTH_HEADER="Authorization: Basic $AUTH_HEADER"

# Function to make authenticated Jira API request
jira_api() {
    local method="${1:-GET}"
    local endpoint="$2"
    local data="${3:-}"

    # Remove leading slash from endpoint if present
    endpoint="${endpoint#/}"

    # Build curl command
    local curl_cmd=(
        curl -s -X "$method"
        -H "$JIRA_AUTH_HEADER"
        -H "Content-Type: application/json"
    )

    # Add data if provided
    if [ -n "$data" ]; then
        curl_cmd+=(-d "$data")
    fi

    # Execute request
    "${curl_cmd[@]}" "$JIRA_URL/$endpoint"
}

# Export function for use in scripts
export -f jira_api

# Success message (only if running directly, not when sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "Jira authentication configured successfully" >&2
    echo "  JIRA_URL: $JIRA_URL" >&2
    echo "  JIRA_EMAIL: $JIRA_EMAIL" >&2
    echo "  Use jira_api function for authenticated requests" >&2
fi
