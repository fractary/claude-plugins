#!/usr/bin/env bash
#
# fetch-issue.sh - Fetch issue details from GitHub
#
# Usage: fetch-issue.sh <issue_number>
#
# Outputs JSON with issue details

set -euo pipefail

ISSUE_NUMBER="${1:?Issue number required}"

# Fetch issue data from GitHub
gh issue view "$ISSUE_NUMBER" \
  --json title,body,labels,assignees,url,state,number,createdAt \
  2>/dev/null || {
    echo '{"error": "Issue not found", "issue_number": "'"$ISSUE_NUMBER"'"}' >&2
    exit 1
  }
