#!/usr/bin/env bash
#
# comment-on-issue.sh - Comment on GitHub issue with archive info
#
# Usage: comment-on-issue.sh <issue_number> <specs_json>
#
# Posts archive comment to GitHub issue

set -euo pipefail

ISSUE_NUMBER="${1:?Issue number required}"
SPECS_JSON="${2:?Specs JSON required}"

# Parse specs to build comment
ARCHIVED_DATE=$(date -u +"%Y-%m-%d %H:%M UTC")

# Build specs list
SPECS_LIST=$(echo "$SPECS_JSON" | jq -r '.[] | "- [\(.filename)](\(.cloud_url)) (\(.size_bytes / 1024 | round) KB)"')

# Check validation status
ALL_VALIDATED=$(echo "$SPECS_JSON" | jq 'all(.[]; .validated == true)')
VALIDATION_STATUS=$([ "$ALL_VALIDATED" = "true" ] && echo "All specs validated ✓" || echo "Some specs not fully validated")

# Build comment body
COMMENT_BODY="✅ Work Archived

This issue has been completed and archived!

**Specifications**:
$SPECS_LIST

**Archived**: $ARCHIVED_DATE
**Validation**: $VALIDATION_STATUS

These specifications are permanently stored in cloud archive for future reference."

# Post comment to issue
gh issue comment "$ISSUE_NUMBER" --body "$COMMENT_BODY" 2>/dev/null || {
    echo "Warning: Failed to comment on issue #$ISSUE_NUMBER" >&2
    exit 0  # Non-critical, don't fail
}

echo "Comment added to issue #$ISSUE_NUMBER"
