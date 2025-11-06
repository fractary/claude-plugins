#!/usr/bin/env bash
#
# detect-environment.sh - Detects git repository, remote, platform, and auth method
#
# Usage: detect-environment.sh
#
# Outputs (JSON):
# {
#   "in_git_repo": true|false,
#   "remote_url": "git@github.com:owner/repo.git",
#   "platform": "github|gitlab|bitbucket|unknown",
#   "auth_method": "SSH|HTTPS|unknown"
# }
#
# Exit codes:
#   0: Success
#   3: Not in git repository

set -euo pipefail

# Check if in git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    jq -n \
        --arg error "Not in a git repository" \
        '{in_git_repo: false, error: $error}'
    exit 3
fi

# Get remote URL
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")

# Detect platform from remote
PLATFORM="unknown"
if echo "$REMOTE_URL" | grep -q "github"; then
    PLATFORM="github"
elif echo "$REMOTE_URL" | grep -q "gitlab"; then
    PLATFORM="gitlab"
elif echo "$REMOTE_URL" | grep -q "bitbucket"; then
    PLATFORM="bitbucket"
fi

# Detect auth method
AUTH_METHOD="unknown"
if echo "$REMOTE_URL" | grep -q "^git@\|^ssh://"; then
    AUTH_METHOD="SSH"
elif echo "$REMOTE_URL" | grep -q "^https://"; then
    AUTH_METHOD="HTTPS"
fi

# Output JSON using jq --arg for safety
jq -n \
    --argjson in_git_repo true \
    --arg remote_url "$REMOTE_URL" \
    --arg platform "$PLATFORM" \
    --arg auth_method "$AUTH_METHOD" \
    '{
        in_git_repo: $in_git_repo,
        remote_url: $remote_url,
        platform: $platform,
        auth_method: $auth_method
    }'
