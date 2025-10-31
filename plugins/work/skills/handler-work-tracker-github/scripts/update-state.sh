#!/bin/bash
# Handler: GitHub Update State
# Updates issue state by mapping universal states to GitHub implementation

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_id> <target_state>" >&2
    echo "  target_state: open | in_progress | in_review | done | closed" >&2
    exit 2
fi

ISSUE_ID="$1"
TARGET_STATE="$2"

# Validate issue ID
if [ -z "$ISSUE_ID" ]; then
    echo "Error: ISSUE_ID required" >&2
    exit 2
fi

# Validate target state
case "$TARGET_STATE" in
    open|in_progress|in_review|done|closed) ;;
    *)
        echo "Error: Invalid target state '$TARGET_STATE'" >&2
        echo "  Valid states: open, in_progress, in_review, done, closed" >&2
        exit 3
        ;;
esac

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

# Check if issue exists
if ! gh issue view "$ISSUE_ID" --json number >/dev/null 2>&1; then
    echo "Error: Issue #$ISSUE_ID not found" >&2
    exit 10
fi

# Get current state
current_gh_state=$(gh issue view "$ISSUE_ID" --json state -q '.state' 2>/dev/null)

# Define state label mappings
LABEL_IN_PROGRESS="in-progress"
LABEL_IN_REVIEW="in-review"

# Execute state transition based on target state
case "$TARGET_STATE" in
    open)
        # Ensure issue is OPEN, remove progress labels
        if [ "$current_gh_state" = "CLOSED" ]; then
            gh issue reopen "$ISSUE_ID" 2>/dev/null || true
        fi
        # Remove progress labels if present
        gh issue edit "$ISSUE_ID" --remove-label "$LABEL_IN_PROGRESS" 2>/dev/null || true
        gh issue edit "$ISSUE_ID" --remove-label "$LABEL_IN_REVIEW" 2>/dev/null || true
        ;;

    in_progress)
        # Ensure issue is OPEN with in-progress label
        if [ "$current_gh_state" = "CLOSED" ]; then
            gh issue reopen "$ISSUE_ID" 2>/dev/null || true
        fi
        # Add in-progress label, remove in-review if present
        gh issue edit "$ISSUE_ID" --add-label "$LABEL_IN_PROGRESS" 2>/dev/null || true
        gh issue edit "$ISSUE_ID" --remove-label "$LABEL_IN_REVIEW" 2>/dev/null || true
        ;;

    in_review)
        # Ensure issue is OPEN with in-review label
        if [ "$current_gh_state" = "CLOSED" ]; then
            gh issue reopen "$ISSUE_ID" 2>/dev/null || true
        fi
        # Add in-review label, remove in-progress if present
        gh issue edit "$ISSUE_ID" --add-label "$LABEL_IN_REVIEW" 2>/dev/null || true
        gh issue edit "$ISSUE_ID" --remove-label "$LABEL_IN_PROGRESS" 2>/dev/null || true
        ;;

    done|closed)
        # Close the issue, remove progress labels
        if [ "$current_gh_state" = "OPEN" ]; then
            gh issue edit "$ISSUE_ID" --remove-label "$LABEL_IN_PROGRESS" 2>/dev/null || true
            gh issue edit "$ISSUE_ID" --remove-label "$LABEL_IN_REVIEW" 2>/dev/null || true
            gh issue close "$ISSUE_ID" 2>/dev/null || true
        fi
        ;;
esac

# Fetch updated issue state
issue_json=$(gh issue view "$ISSUE_ID" --json number,state,labels,updatedAt,url 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch updated issue state" >&2
    exit 1
fi

# Parse current GitHub state and labels
gh_state=$(echo "$issue_json" | jq -r '.state | ascii_downcase')
labels=$(echo "$issue_json" | jq -r '.labels[]?.name // empty' | tr '\n' ',' | sed 's/,$//')

# Map GitHub state + labels back to universal state
actual_state=""
if [ "$gh_state" = "closed" ]; then
    actual_state="closed"
elif echo "$labels" | grep -qi "$LABEL_IN_REVIEW"; then
    actual_state="in_review"
elif echo "$labels" | grep -qi "$LABEL_IN_PROGRESS"; then
    actual_state="in_progress"
else
    actual_state="open"
fi

# Output normalized JSON
echo "$issue_json" | jq -c --arg target_state "$actual_state" '{
  id: .number | tostring,
  identifier: ("#" + (.number | tostring)),
  state: $target_state,
  actual_state: $target_state,
  updatedAt: .updatedAt,
  url: .url,
  platform: "github"
}'

exit 0
