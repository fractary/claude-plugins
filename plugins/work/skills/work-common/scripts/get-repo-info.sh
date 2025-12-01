#!/bin/bash
# Work Common: Get Repository Info
# Extracts owner and repo from work plugin configuration
# Supports both v2.0 schema and legacy schema formats
#
# Usage: get-repo-info.sh
# Output: JSON object with owner and repo fields
# Example: {"owner": "fractary", "repo": "claude-plugins"}

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration using config-loader
CONFIG_JSON=$("$SCRIPT_DIR/config-loader.sh" 2>&1)
if [ $? -ne 0 ]; then
    echo "Error: Failed to load configuration" >&2
    echo "$CONFIG_JSON" >&2
    exit 3
fi

# Get active platform
ACTIVE_PLATFORM=$(echo "$CONFIG_JSON" | jq -r '.handlers["work-tracker"].active')

if [ "$ACTIVE_PLATFORM" != "github" ]; then
    echo "Error: This script only supports GitHub platform (active: $ACTIVE_PLATFORM)" >&2
    exit 3
fi

# Try to extract from v2.0 schema (handlers.work-tracker.github.owner/repo)
OWNER=$(echo "$CONFIG_JSON" | jq -r '.handlers["work-tracker"].github.owner // empty')
REPO=$(echo "$CONFIG_JSON" | jq -r '.handlers["work-tracker"].github.repo // empty')

# If not found, try legacy schema (platforms.github.config.owner/repo)
if [ -z "$OWNER" ] || [ -z "$REPO" ]; then
    OWNER=$(echo "$CONFIG_JSON" | jq -r '.platforms.github.config.owner // empty')
    REPO=$(echo "$CONFIG_JSON" | jq -r '.platforms.github.config.repo // empty')
fi

# If still not found, try project.repository field (format: "owner/repo")
if [ -z "$OWNER" ] || [ -z "$REPO" ]; then
    REPO_STRING=$(echo "$CONFIG_JSON" | jq -r '.project.repository // empty')
    if [ -n "$REPO_STRING" ] && [[ "$REPO_STRING" == *"/"* ]]; then
        OWNER="${REPO_STRING%%/*}"
        REPO="${REPO_STRING##*/}"
    fi
fi

# Validate we found owner and repo
if [ -z "$OWNER" ] || [ -z "$REPO" ] || [ "$OWNER" = "null" ] || [ "$REPO" = "null" ]; then
    echo "Error: Could not extract owner/repo from configuration" >&2
    echo "  Checked paths:" >&2
    echo "    - .handlers[\"work-tracker\"].github.owner/repo" >&2
    echo "    - .platforms.github.config.owner/repo" >&2
    echo "    - .project.repository" >&2
    exit 3
fi

# Output JSON with owner and repo
jq -n \
    --arg owner "$OWNER" \
    --arg repo "$REPO" \
    '{owner: $owner, repo: $repo}'

exit 0
