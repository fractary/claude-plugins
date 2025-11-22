#!/bin/bash
# Repo Manager: GitHub Generate Branch Name
# Generates semantic branch name from work metadata

set -euo pipefail

# Check arguments
if [ $# -lt 4 ]; then
    echo "Usage: $0 <work_id> <issue_id> <work_type> <title>" >&2
    exit 2
fi

WORK_ID="$1"
ISSUE_ID="$2"
WORK_TYPE="$3"
TITLE="$4"

# Determine branch prefix from work type
case "$WORK_TYPE" in
    /feature|feature)
        PREFIX="feat"
        ;;
    /bug|bug)
        PREFIX="fix"
        ;;
    /chore|chore)
        PREFIX="chore"
        ;;
    /patch|patch|hotfix)
        PREFIX="hotfix"
        ;;
    *)
        PREFIX="feat"
        ;;
esac

# Create slug from title
# - Convert to lowercase
# - Replace spaces with hyphens
# - Remove special characters
# - Limit to 50 characters
SLUG=$(echo "$TITLE" | \
    tr '[:upper:]' '[:lower:]' | \
    sed 's/[^a-z0-9 -]//g' | \
    sed 's/ \+/-/g' | \
    sed 's/^-\+//' | \
    sed 's/-\+$//' | \
    cut -c1-50)

# Generate branch name: prefix/issue_id-slug
BRANCH_NAME="${PREFIX}/${ISSUE_ID}-${SLUG}"

# Output branch name
echo "$BRANCH_NAME"
exit 0
