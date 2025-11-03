#!/bin/bash
# Handler: GitHub Link Issues
# Create relationship between two issues via comment references

set -euo pipefail

# Parse arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_id> <related_issue_id> [relationship_type]" >&2
    exit 2
fi

ISSUE_ID="$1"
RELATED_ISSUE_ID="$2"
RELATIONSHIP_TYPE="${3:-relates_to}"

# Validate required parameters
if [ -z "$ISSUE_ID" ]; then
    echo "Error: issue_id is required" >&2
    exit 2
fi

if [ -z "$RELATED_ISSUE_ID" ]; then
    echo "Error: related_issue_id is required" >&2
    exit 2
fi

# Check for self-reference
if [ "$ISSUE_ID" = "$RELATED_ISSUE_ID" ]; then
    echo "Error: Cannot link issue to itself" >&2
    echo "  issue_id and related_issue_id must be different" >&2
    exit 3
fi

# Validate relationship type
case "$RELATIONSHIP_TYPE" in
    relates_to|blocks|blocked_by|duplicates)
        # Valid relationship type
        ;;
    *)
        echo "Error: Invalid relationship_type: $RELATIONSHIP_TYPE" >&2
        echo "  Must be one of: relates_to, blocks, blocked_by, duplicates" >&2
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

# Verify source issue exists
if ! gh issue view "$ISSUE_ID" --json number >/dev/null 2>&1; then
    echo "Error: Issue #$ISSUE_ID not found" >&2
    echo "  Verify issue exists in the repository" >&2
    exit 10
fi

# Verify related issue exists
if ! gh issue view "$RELATED_ISSUE_ID" --json number >/dev/null 2>&1; then
    echo "Error: Issue #$RELATED_ISSUE_ID not found" >&2
    echo "  Verify issue exists in the repository" >&2
    exit 10
fi

# Create appropriate comments based on relationship type
MESSAGE=""

case "$RELATIONSHIP_TYPE" in
    relates_to)
        # Simple bidirectional relationship - comment on source only
        if ! gh issue comment "$ISSUE_ID" --body "Related to #$RELATED_ISSUE_ID" 2>&1; then
            echo "Error: Failed to create relationship comment" >&2
            exit 1
        fi
        MESSAGE="Issue #$ISSUE_ID relates to #$RELATED_ISSUE_ID"
        ;;

    blocks)
        # Source blocks target - comment on both
        if ! gh issue comment "$ISSUE_ID" --body "Blocks #$RELATED_ISSUE_ID" 2>&1; then
            echo "Error: Failed to create 'blocks' comment on #$ISSUE_ID" >&2
            exit 1
        fi
        if ! gh issue comment "$RELATED_ISSUE_ID" --body "Blocked by #$ISSUE_ID" 2>&1; then
            echo "Error: Failed to create 'blocked by' comment on #$RELATED_ISSUE_ID" >&2
            exit 1
        fi
        MESSAGE="Issue #$ISSUE_ID blocks #$RELATED_ISSUE_ID"
        ;;

    blocked_by)
        # Source blocked by target - comment on both (inverse of blocks)
        if ! gh issue comment "$ISSUE_ID" --body "Blocked by #$RELATED_ISSUE_ID" 2>&1; then
            echo "Error: Failed to create 'blocked by' comment on #$ISSUE_ID" >&2
            exit 1
        fi
        if ! gh issue comment "$RELATED_ISSUE_ID" --body "Blocks #$ISSUE_ID" 2>&1; then
            echo "Error: Failed to create 'blocks' comment on #$RELATED_ISSUE_ID" >&2
            exit 1
        fi
        MESSAGE="Issue #$ISSUE_ID blocked by #$RELATED_ISSUE_ID"
        ;;

    duplicates)
        # Source duplicates target - comment on source only
        if ! gh issue comment "$ISSUE_ID" --body "Duplicate of #$RELATED_ISSUE_ID" 2>&1; then
            echo "Error: Failed to create duplicate comment" >&2
            exit 1
        fi
        MESSAGE="Issue #$ISSUE_ID duplicates #$RELATED_ISSUE_ID"
        ;;
esac

# Output success JSON
cat <<EOF
{
  "issue_id": "$ISSUE_ID",
  "related_issue_id": "$RELATED_ISSUE_ID",
  "relationship": "$RELATIONSHIP_TYPE",
  "link_method": "comment",
  "message": "$MESSAGE",
  "platform": "github"
}
EOF

exit 0
