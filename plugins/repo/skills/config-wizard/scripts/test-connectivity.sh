#!/usr/bin/env bash
#
# test-connectivity.sh - Tests SSH and API connectivity for a platform
#
# Usage: test-connectivity.sh --platform <platform> [--auth-method <method>]
#
# Arguments:
#   --platform <name>: github|gitlab|bitbucket
#   --auth-method <method>: SSH|HTTPS (optional)
#
# Outputs (JSON):
# {
#   "ssh_connected": true|false,
#   "api_connected": true|false,
#   "cli_available": true|false
# }
#
# Exit codes:
#   0: Success
#   12: Network/connectivity error

set -euo pipefail

PLATFORM=""
AUTH_METHOD=""

# SSH connection timeout (seconds)
SSH_TIMEOUT=10

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --auth-method)
            AUTH_METHOD="$2"
            shift 2
            ;;
        *)
            jq -n --arg err "Unknown argument: $1" '{error: $err}'
            exit 2
            ;;
    esac
done

# Validate platform
if [ -z "$PLATFORM" ]; then
    jq -n '{error: "Missing required argument: --platform"}'
    exit 2
fi

SSH_CONNECTED=false
API_CONNECTED=false
CLI_AVAILABLE=false

# Test SSH connectivity (if SSH method) with timeout
if [ "$AUTH_METHOD" = "SSH" ]; then
    case "$PLATFORM" in
        github)
            # Use timeout and ConnectTimeout for SSH test
            if timeout "${SSH_TIMEOUT}s" ssh -T -o ConnectTimeout=5 -o StrictHostKeyChecking=no git@github.com 2>&1 | grep -q "successfully authenticated"; then
                SSH_CONNECTED=true
            fi
            ;;
        gitlab)
            if timeout "${SSH_TIMEOUT}s" ssh -T -o ConnectTimeout=5 -o StrictHostKeyChecking=no git@gitlab.com 2>&1 | grep -q "Welcome to GitLab"; then
                SSH_CONNECTED=true
            fi
            ;;
        bitbucket)
            if timeout "${SSH_TIMEOUT}s" ssh -T -o ConnectTimeout=5 -o StrictHostKeyChecking=no git@bitbucket.org 2>&1 | grep -q "authenticated"; then
                SSH_CONNECTED=true
            fi
            ;;
    esac
fi

# Test API connectivity and CLI availability
case "$PLATFORM" in
    github)
        if command -v gh >/dev/null 2>&1; then
            CLI_AVAILABLE=true
            if gh auth status >/dev/null 2>&1; then
                API_CONNECTED=true
            fi
        fi
        ;;
    gitlab)
        if command -v glab >/dev/null 2>&1; then
            CLI_AVAILABLE=true
            if glab auth status >/dev/null 2>&1; then
                API_CONNECTED=true
            fi
        fi
        ;;
    bitbucket)
        CLI_AVAILABLE=false
        # Test API with curl if credentials available
        if [ -n "${BITBUCKET_USERNAME:-}" ] && [ -n "${BITBUCKET_TOKEN:-}" ]; then
            if curl -s -u "$BITBUCKET_USERNAME:$BITBUCKET_TOKEN" \
                https://api.bitbucket.org/2.0/user | jq -e '.username' >/dev/null 2>&1; then
                API_CONNECTED=true
            fi
        fi
        ;;
esac

# Output JSON using jq --arg for safety
jq -n \
    --argjson ssh_connected "$SSH_CONNECTED" \
    --argjson api_connected "$API_CONNECTED" \
    --argjson cli_available "$CLI_AVAILABLE" \
    '{
        ssh_connected: $ssh_connected,
        api_connected: $api_connected,
        cli_available: $cli_available
    }'
