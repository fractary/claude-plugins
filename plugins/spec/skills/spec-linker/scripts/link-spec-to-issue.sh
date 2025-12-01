#!/usr/bin/env bash
#
# link-spec-to-issue.sh - Link spec to GitHub issue
#
# Usage: link-spec-to-issue.sh <issue_number> <spec_path> [phase]
#
# Same as spec-generator's link-to-issue.sh (shared functionality)

set -euo pipefail

ISSUE_NUMBER="${1:?Issue number required}"
SPEC_PATH="${2:?Spec path required}"
PHASE="${3:-}"

SPEC_FILENAME=$(basename "$SPEC_PATH")

# Build comment message
if [[ -n "$PHASE" ]]; then
    COMMENT_BODY="📋 Specification Created (Phase $PHASE)

Specification generated for this issue:
- [$SPEC_FILENAME]($SPEC_PATH)

This spec will guide implementation and be validated before archival."
else
    COMMENT_BODY="📋 Specification Created

Specification generated for this issue:
- [$SPEC_FILENAME]($SPEC_PATH)

This spec will guide implementation and be validated before archival."
fi

# Comment on issue
gh issue comment "$ISSUE_NUMBER" --body "$COMMENT_BODY" 2>/dev/null || {
    echo "Warning: Failed to comment on issue #$ISSUE_NUMBER" >&2
    exit 0  # Non-critical, don't fail
}

echo "Spec linked to issue #$ISSUE_NUMBER"
