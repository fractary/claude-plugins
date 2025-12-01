#!/bin/bash
# Handler: Linear Link Issues
# Creates a relationship between two issues

set -euo pipefail

# Check arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <issue_id> <related_issue_id> <relationship_type>" >&2
    exit 2
fi

ISSUE_ID="$1"
RELATED_ISSUE_ID="$2"
RELATIONSHIP_TYPE="$3"

# Check if LINEAR_API_KEY is set
if [ -z "${LINEAR_API_KEY:-}" ]; then
    echo "Error: LINEAR_API_KEY environment variable not set" >&2
    exit 11
fi

# Map relationship types to Linear's format
case "$RELATIONSHIP_TYPE" in
    "blocks"|"blocked_by")
        LINEAR_TYPE="blocks"
        ;;
    "relates_to"|"related")
        LINEAR_TYPE="related"
        ;;
    "duplicates"|"duplicate")
        LINEAR_TYPE="duplicate"
        ;;
    *)
        LINEAR_TYPE="$RELATIONSHIP_TYPE"
        ;;
esac

# GraphQL mutation to create issue relation
read -r -d '' LINK_MUTATION <<'EOF' || true
mutation CreateIssueRelation($issueId: String!, $relatedIssueId: String!, $type: IssueRelationType!) {
  issueRelationCreate(input: {
    issueId: $issueId,
    relatedIssueId: $relatedIssueId,
    type: $type
  }) {
    success
    issueRelation {
      id
      type
      issue {
        identifier
      }
      relatedIssue {
        identifier
      }
    }
  }
}
EOF

# Build GraphQL request
GRAPHQL_REQUEST=$(jq -n \
  --arg query "$LINK_MUTATION" \
  --arg issueId "$ISSUE_ID" \
  --arg relatedIssueId "$RELATED_ISSUE_ID" \
  --arg type "$LINEAR_TYPE" \
  '{query: $query, variables: {issueId: $issueId, relatedIssueId: $relatedIssueId, type: $type}}')

# Execute GraphQL request
RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$GRAPHQL_REQUEST")

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message')
    if echo "$ERROR_MSG" | grep -q "not found"; then
        echo "Error: Issue not found" >&2
        exit 10
    else
        echo "Error: Failed to link issues: $ERROR_MSG" >&2
        exit 1
    fi
fi

# Check success
SUCCESS=$(echo "$RESPONSE" | jq -r '.data.issueRelationCreate.success')
if [ "$SUCCESS" != "true" ]; then
    echo "Error: Failed to create issue relation" >&2
    exit 1
fi

# Output result
echo "$RESPONSE" | jq '.data.issueRelationCreate.issueRelation | {
  issue_id: .issue.identifier,
  related_issue_id: .relatedIssue.identifier,
  relationship: .type,
  message: "Issue \(.issue.identifier) \(.type) \(.relatedIssue.identifier)"
}'

exit 0
