#!/usr/bin/env bash
#
# update-issue-comment.sh - Update issue with archive links
#
# Usage: update-issue-comment.sh <issue_number> <archive_json>
#
# Posts archive comment with cloud URLs

set -euo pipefail

ISSUE_NUMBER="${1:?Issue number required}"
ARCHIVE_JSON="${2:?Archive JSON required}"

# Build comment from archive data
SPECS=$(echo "$ARCHIVE_JSON" | jq -r '.specs[] | "- [\(.filename)](\(.public_url)) (\(.size_bytes / 1024 | round) KB)"')
ARCHIVED_AT=$(echo "$ARCHIVE_JSON" | jq -r '.archived_at')

COMMENT_BODY="✅ Work Archived

This issue has been completed and archived!

**Specifications**:
$SPECS

**Archived**: $(date -d "$ARCHIVED_AT" +"%Y-%m-%d %H:%M UTC" 2>/dev/null || echo "$ARCHIVED_AT")

These specifications are permanently stored in cloud archive for future reference."

# Post comment
gh issue comment "$ISSUE_NUMBER" --body "$COMMENT_BODY" 2>/dev/null || {
    echo "Warning: Failed to comment on issue #$ISSUE_NUMBER" >&2
    exit 0  # Non-critical
}

echo "Archive links added to issue #$ISSUE_NUMBER"
