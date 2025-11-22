#!/bin/bash
# Handler: Jira Classify Issue
# Determines FABER work type from Jira issue type and labels

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_json>" >&2
    echo "  Classifies issue as /bug, /feature, /chore, or /patch" >&2
    exit 2
fi

ISSUE_JSON="$1"

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found. Install it for JSON processing" >&2
    exit 3
fi

# Extract issue type and labels from JSON
ISSUE_TYPE=$(echo "$ISSUE_JSON" | jq -r '.issueType // .fields.issuetype.name // "Unknown"' | tr '[:upper:]' '[:lower:]')
LABELS=$(echo "$ISSUE_JSON" | jq -r '.labels // ""' | tr '[:upper:]' '[:lower:]')

# Load configuration (if available) for custom mappings
# For MVP, use default mappings. Can be enhanced to read from config.
CONFIG_FILE=".fractary/plugins/work/config.json"

if [ -f "$CONFIG_FILE" ]; then
    # Load custom classification from config
    FEATURE_TYPES=$(jq -r '.handlers["work-tracker"].jira.classification.feature[]?' "$CONFIG_FILE" 2>/dev/null | tr '\n' '|' | sed 's/|$//')
    BUG_TYPES=$(jq -r '.handlers["work-tracker"].jira.classification.bug[]?' "$CONFIG_FILE" 2>/dev/null | tr '\n' '|' | sed 's/|$//')
    CHORE_TYPES=$(jq -r '.handlers["work-tracker"].jira.classification.chore[]?' "$CONFIG_FILE" 2>/dev/null | tr '\n' '|' | sed 's/|$//')
    PATCH_TYPES=$(jq -r '.handlers["work-tracker"].jira.classification.patch[]?' "$CONFIG_FILE" 2>/dev/null | tr '\n' '|' | sed 's/|$//')
else
    # Default mappings
    FEATURE_TYPES="story|feature|enhancement|epic"
    BUG_TYPES="bug|defect|error"
    CHORE_TYPES="task|improvement|maintenance|documentation|test"
    PATCH_TYPES="hotfix|urgent|critical|security"
fi

# Classification logic with priority
WORK_TYPE=""

# Priority 1: Check labels for patch indicators (highest urgency)
if echo "$LABELS" | grep -qiE "$PATCH_TYPES"; then
    WORK_TYPE="/patch"

# Priority 2: Check issue type for patch
elif echo "$ISSUE_TYPE" | grep -qiE "$PATCH_TYPES"; then
    WORK_TYPE="/patch"

# Priority 3: Check labels for bug
elif echo "$LABELS" | grep -qiE "$BUG_TYPES"; then
    WORK_TYPE="/bug"

# Priority 4: Check issue type for bug
elif echo "$ISSUE_TYPE" | grep -qiE "$BUG_TYPES"; then
    WORK_TYPE="/bug"

# Priority 5: Check labels for feature
elif echo "$LABELS" | grep -qiE "$FEATURE_TYPES"; then
    WORK_TYPE="/feature"

# Priority 6: Check issue type for feature
elif echo "$ISSUE_TYPE" | grep -qiE "$FEATURE_TYPES"; then
    WORK_TYPE="/feature"

# Priority 7: Check labels for chore
elif echo "$LABELS" | grep -qiE "$CHORE_TYPES"; then
    WORK_TYPE="/chore"

# Priority 8: Check issue type for chore
elif echo "$ISSUE_TYPE" | grep -qiE "$CHORE_TYPES"; then
    WORK_TYPE="/chore"

# Default: Treat as chore if no match
else
    WORK_TYPE="/chore"
fi

# Output classification
echo "$WORK_TYPE"
exit 0
