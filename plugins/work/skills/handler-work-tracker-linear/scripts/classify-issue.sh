#!/bin/bash
# Handler: Linear Classify Issue
# Determines FABER work type from Linear issue labels

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_json>" >&2
    exit 2
fi

ISSUE_JSON="$1"

# Extract labels from issue JSON
LABELS=$(echo "$ISSUE_JSON" | jq -r '.labels[]?' | tr '[:upper:]' '[:lower:]' | tr '\n' ' ')

# Default classification
WORK_TYPE="/chore"
CONFIDENCE="low"
REASON="No matching classification labels found"

# Classification logic based on labels
if echo "$LABELS" | grep -qE '\b(bug|defect|fix|crash|error)\b'; then
    # Check if it's a hotfix/patch
    if echo "$LABELS" | grep -qE '\b(hotfix|patch|urgent|critical|blocker)\b'; then
        WORK_TYPE="/patch"
        CONFIDENCE="high"
        REASON="Contains bug-related label and urgency label"
    else
        WORK_TYPE="/bug"
        CONFIDENCE="high"
        REASON="Contains bug-related label"
    fi
elif echo "$LABELS" | grep -qE '\b(feature|enhancement|story|epic|improvement|new)\b'; then
    WORK_TYPE="/feature"
    CONFIDENCE="high"
    REASON="Contains feature-related label"
elif echo "$LABELS" | grep -qE '\b(chore|maintenance|refactor|tech-debt|docs|documentation|test)\b'; then
    WORK_TYPE="/chore"
    CONFIDENCE="high"
    REASON="Contains chore-related label"
elif echo "$LABELS" | grep -qE '\b(hotfix|patch|urgent|critical)\b'; then
    WORK_TYPE="/patch"
    CONFIDENCE="medium"
    REASON="Contains urgency label (assuming urgent fix)"
fi

# Check title if confidence is still low
if [ "$CONFIDENCE" = "low" ]; then
    TITLE=$(echo "$ISSUE_JSON" | jq -r '.title?' | tr '[:upper:]' '[:lower:]')
    if echo "$TITLE" | grep -qE '\b(fix|bug|crash|error)\b'; then
        WORK_TYPE="/bug"
        CONFIDENCE="medium"
        REASON="Title contains bug-related keywords"
    elif echo "$TITLE" | grep -qE '\b(add|new|feature|implement)\b'; then
        WORK_TYPE="/feature"
        CONFIDENCE="medium"
        REASON="Title contains feature-related keywords"
    fi
fi

# Output classification result
echo "$WORK_TYPE"
exit 0
