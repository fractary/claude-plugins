#!/bin/bash
# Work Manager: GitHub List Labels
# Lists all labels on a GitHub issue

set -euo pipefail

# Check arguments - minimum 1 required (issue_id)
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

# Check authentication
if ! gh auth status >/dev/null 2>&1; then
    echo "Error: GitHub authentication failed. Run 'gh auth login'" >&2
    exit 11
fi

# Fetch labels using gh CLI
result=$(gh issue view "$ISSUE_ID" --json labels 2>&1)

if [ $? -ne 0 ]; then
    if echo "$result" | grep -q "Could not resolve to an Issue"; then
        echo "Error: Issue #$ISSUE_ID not found" >&2
        exit 10
    elif echo "$result" | grep -q "authentication"; then
        echo "Error: GitHub authentication failed" >&2
        exit 11
    else
        echo "Error: Failed to fetch labels for issue #$ISSUE_ID" >&2
        echo "$result" >&2
        exit 1
    fi
fi

# Parse and format labels using jq
labels=$(echo "$result" | jq '.labels | map({
    name: .name,
    color: .color,
    description: .description
})')

# Output the labels array
echo "$labels"
exit 0
