#!/usr/bin/env bash
#
# init.sh - Initialize repository plugin configuration
#
# Usage: init.sh [--platform <name>] [--force]
#
# Arguments:
#   --platform <name>: github|gitlab|bitbucket (auto-detected if omitted)
#   --force: Overwrite existing config without prompting
#
# Environment:
#   GITHUB_TOKEN, GITLAB_TOKEN, or BITBUCKET_TOKEN: Platform API token
#
# Outputs (JSON):
# {
#   "status": "success|failure|exists",
#   "config_path": "/path/to/config.json",
#   "platform": "github|gitlab|bitbucket",
#   "message": "Human-readable message"
# }
#
# Exit codes:
#   0: Success
#   1: General error
#   10: Config already exists (without --force)

set -euo pipefail

# Default values
PLATFORM=""
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

CONFIG_PATH=".fractary/plugins/repo/config.json"

# Check if config already exists
if [ -f "$CONFIG_PATH" ] && [ "$FORCE" = false ]; then
    jq -n \
        --arg status "exists" \
        --arg config_path "$CONFIG_PATH" \
        --arg message "Configuration already exists. Use --force to overwrite." \
        '{status: $status, config_path: $config_path, message: $message}'
    exit 10
fi

# Auto-detect platform from git remote if not specified
if [ -z "$PLATFORM" ]; then
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
    if echo "$REMOTE_URL" | grep -qi "github"; then
        PLATFORM="github"
    elif echo "$REMOTE_URL" | grep -qi "gitlab"; then
        PLATFORM="gitlab"
    elif echo "$REMOTE_URL" | grep -qi "bitbucket"; then
        PLATFORM="bitbucket"
    else
        PLATFORM="github"  # Default
    fi
fi

# Validate platform
if [[ ! "$PLATFORM" =~ ^(github|gitlab|bitbucket)$ ]]; then
    jq -n \
        --arg status "failure" \
        --arg message "Invalid platform: $PLATFORM. Must be github, gitlab, or bitbucket." \
        '{status: $status, message: $message}'
    exit 1
fi

# Determine token variable name
case "$PLATFORM" in
    github)   TOKEN_VAR="\$GITHUB_TOKEN" ;;
    gitlab)   TOKEN_VAR="\$GITLAB_TOKEN" ;;
    bitbucket) TOKEN_VAR="\$BITBUCKET_TOKEN" ;;
esac

# Create directory
mkdir -p "$(dirname "$CONFIG_PATH")"

# Create config file
jq -n \
    --arg platform "$PLATFORM" \
    --arg token_var "$TOKEN_VAR" \
    '{
        handlers: {
            source_control: {
                active: $platform,
                ($platform): {
                    token: $token_var
                }
            }
        },
        defaults: {
            default_branch: "main",
            protected_branches: ["main", "master", "production"],
            merge_strategy: "no-ff",
            push_sync_strategy: "auto-merge"
        }
    }' > "$CONFIG_PATH"

# Set permissions
chmod 600 "$CONFIG_PATH"

# Verify and output result
if [ -f "$CONFIG_PATH" ]; then
    jq -n \
        --arg status "success" \
        --arg config_path "$CONFIG_PATH" \
        --arg platform "$PLATFORM" \
        --arg message "Configuration created successfully." \
        '{status: $status, config_path: $config_path, platform: $platform, message: $message}'
    exit 0
else
    jq -n \
        --arg status "failure" \
        --arg message "Failed to create configuration file." \
        '{status: $status, message: $message}'
    exit 1
fi
