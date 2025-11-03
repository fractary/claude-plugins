#!/bin/bash
# Work Manager: GitHub Set Labels
# Sets exact labels on a GitHub issue (replaces all existing labels)

set -euo pipefail

# Check arguments - minimum 1 required (issue_id), labels can be empty
if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_id> [label1,label2,...]" >&2
    exit 2
fi

ISSUE_ID="$1"
LABELS="${2:-}"  # Empty string means remove all labels

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

# First, get current labels
current_labels=$(gh issue view "$ISSUE_ID" --json labels 2>&1)

if [ $? -ne 0 ]; then
    if echo "$current_labels" | grep -q "Could not resolve to an Issue"; then
        echo "Error: Issue #$ISSUE_ID not found" >&2
        exit 10
    elif echo "$current_labels" | grep -q "authentication"; then
        echo "Error: GitHub authentication failed" >&2
        exit 11
    else
        echo "Error: Failed to fetch issue #$ISSUE_ID" >&2
        echo "$current_labels" >&2
        exit 1
    fi
fi

# Remove all current labels
current_label_names=$(echo "$current_labels" | jq -r '.labels[].name')
if [ -n "$current_label_names" ]; then
    while IFS= read -r label; do
        if [ -n "$label" ]; then
            gh issue edit "$ISSUE_ID" --remove-label "$label" >/dev/null 2>&1 || true
        fi
    done <<< "$current_label_names"
fi

# Add new labels if provided
if [ -n "$LABELS" ]; then
    # Convert comma-separated string to individual labels
    IFS=',' read -ra LABEL_ARRAY <<< "$LABELS"
    for label in "${LABEL_ARRAY[@]}"; do
        label_trimmed="$(echo "$label" | xargs)"  # Trim whitespace
        if [ -n "$label_trimmed" ]; then
            result=$(gh issue edit "$ISSUE_ID" --add-label "$label_trimmed" 2>&1)
            if [ $? -ne 0 ]; then
                echo "Error: Failed to add label '$label_trimmed'" >&2
                echo "$result" >&2
                exit 1
            fi
        fi
    done
fi

# Output success message with final label list
echo "Labels set on issue #$ISSUE_ID: $LABELS"
exit 0
