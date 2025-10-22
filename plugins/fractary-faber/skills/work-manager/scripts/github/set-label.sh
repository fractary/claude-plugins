#!/bin/bash
# Work Manager: GitHub Set Label
# Adds or removes labels on a GitHub issue

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_id> <label> [action]" >&2
    echo "  action: add (default) | remove" >&2
    exit 2
fi

ISSUE_ID="$1"
LABEL="$2"
ACTION="${3:-add}"

# Validate action
case "$ACTION" in
    add|remove) ;;
    *)
        echo "Error: Invalid action '$ACTION'. Must be 'add' or 'remove'" >&2
        exit 2
        ;;
esac

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found. Install it from https://cli.github.com" >&2
    exit 3
fi

# Add or remove label using gh CLI
if [ "$ACTION" = "add" ]; then
    result=$(gh issue edit "$ISSUE_ID" --add-label "$LABEL" 2>&1)
else
    result=$(gh issue edit "$ISSUE_ID" --remove-label "$LABEL" 2>&1)
fi

if [ $? -ne 0 ]; then
    if echo "$result" | grep -q "Could not resolve to an Issue"; then
        echo "Error: Issue #$ISSUE_ID not found" >&2
        exit 10
    elif echo "$result" | grep -q "authentication"; then
        echo "Error: GitHub authentication failed" >&2
        exit 11
    else
        echo "Error: Failed to $ACTION label on issue #$ISSUE_ID" >&2
        echo "$result" >&2
        exit 1
    fi
fi

# Output success message
echo "Label '$LABEL' ${ACTION}ed on issue #$ISSUE_ID"
exit 0
