#!/bin/bash
# Work Manager: GitHub Fetch Issue
# Fetches issue details from GitHub using gh CLI

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_id>" >&2
    exit 2
fi

ISSUE_ID="$1"

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found. Install it from https://cli.github.com" >&2
    exit 3
fi

# Check if GITHUB_TOKEN is set
if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "Warning: GITHUB_TOKEN not set, using gh CLI authentication" >&2
fi

# Fetch issue using gh CLI (including comments for full context)
issue_json=$(gh issue view "$ISSUE_ID" --json number,title,body,state,labels,author,createdAt,updatedAt,url,comments 2>&1)

if [ $? -ne 0 ]; then
    if echo "$issue_json" | grep -q "Could not resolve to an Issue"; then
        echo "Error: Issue #$ISSUE_ID not found" >&2
        exit 10
    elif echo "$issue_json" | grep -q "authentication"; then
        echo "Error: GitHub authentication failed" >&2
        exit 11
    else
        echo "Error: Failed to fetch issue #$ISSUE_ID" >&2
        echo "$issue_json" >&2
        exit 1
    fi
fi

# Extract and format labels as comma-separated string
labels=$(echo "$issue_json" | jq -r '.labels[]?.name // empty' | tr '\n' ',' | sed 's/,$//')

# Reformat to include labels as string
output_json=$(echo "$issue_json" | jq --arg labels "$labels" '. + {labels: $labels}')

# Output formatted JSON
echo "$output_json"
exit 0
