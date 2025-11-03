#!/bin/bash
# Work Manager: GitHub Classify Issue
# Determines work type from issue labels and content

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_json>" >&2
    exit 2
fi

ISSUE_JSON="$1"

# Extract labels from issue JSON
labels=$(echo "$ISSUE_JSON" | jq -r '.labels // empty' | tr '[:upper:]' '[:lower:]')
title=$(echo "$ISSUE_JSON" | jq -r '.title // empty' | tr '[:upper:]' '[:lower:]')
body=$(echo "$ISSUE_JSON" | jq -r '.body // empty' | tr '[:upper:]' '[:lower:]')

# Classification logic based on labels
work_type=""

# Check for bug indicators
if echo "$labels" | grep -qE "bug|fix|error|crash|issue"; then
    work_type="/bug"
# Check for hotfix/patch indicators
elif echo "$labels" | grep -qE "hotfix|patch|critical|urgent"; then
    work_type="/patch"
# Check for chore/maintenance indicators
elif echo "$labels" | grep -qE "chore|maintenance|refactor|cleanup|debt"; then
    work_type="/chore"
# Check for feature indicators
elif echo "$labels" | grep -qE "feature|enhancement|improvement"; then
    work_type="/feature"
fi

# If no label match, check title and body
if [ -z "$work_type" ]; then
    if echo "$title $body" | grep -qE "\[bug\]|bug:|fix:"; then
        work_type="/bug"
    elif echo "$title $body" | grep -qE "\[hotfix\]|hotfix:|patch:"; then
        work_type="/patch"
    elif echo "$title $body" | grep -qE "\[chore\]|chore:|refactor:"; then
        work_type="/chore"
    elif echo "$title $body" | grep -qE "\[feature\]|feat:|feature:"; then
        work_type="/feature"
    fi
fi

# Default to feature if still unclear
if [ -z "$work_type" ]; then
    work_type="/feature"
fi

# Output work type
echo "$work_type"
exit 0
