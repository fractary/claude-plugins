#!/bin/bash
# Updates audit file with new permission changes
# Usage: update-audit.sh <env> <actions> <reason>

set -e

ENV=$1
ACTIONS=$2
REASON=$3

if [ -z "$ENV" ] || [ -z "$ACTIONS" ] || [ -z "$REASON" ]; then
  echo "Usage: update-audit.sh <env> <actions> <reason>"
  echo "  env: Environment (test, staging, prod)"
  echo "  actions: Comma-separated list of IAM actions"
  echo "  reason: Reason for permission change"
  exit 1
fi

AUDIT_FILE="infrastructure/iam-policies/${ENV}-deploy-permissions.json"

# Check if audit file exists
if [ ! -f "$AUDIT_FILE" ]; then
  echo "ERROR: Audit file not found: $AUDIT_FILE"
  echo "Please initialize audit file first."
  exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo "ERROR: jq is required but not installed."
  echo "Install with: sudo apt-get install jq"
  exit 1
fi

# Current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Split actions into array
IFS=',' read -ra ACTION_ARRAY <<< "$ACTIONS"

# Create audit trail entry
AUDIT_ENTRY=$(cat <<EOF
{
  "timestamp": "$TIMESTAMP",
  "operation": "add_permission",
  "description": "$REASON",
  "added_actions": $(printf '%s\n' "${ACTION_ARRAY[@]}" | jq -R . | jq -s .),
  "reason": "$REASON"
}
EOF
)

# Update audit file
# 1. Add entry to audit_trail array
# 2. Update last_updated timestamp
# 3. Merge new actions into permissions Statement
TMP_FILE="${AUDIT_FILE}.tmp"

jq --argjson entry "$AUDIT_ENTRY" \
   --arg timestamp "$TIMESTAMP" \
   '.last_updated = $timestamp |
    .audit_trail += [$entry]' \
   "$AUDIT_FILE" > "$TMP_FILE"

# For each action, add to permissions if not already present
for action in "${ACTION_ARRAY[@]}"; do
  jq --arg action "$action" '
    .permissions.Statement[0].Action |=
    if (type == "array") then
      if (. | index($action)) then . else . + [$action] end
    elif . == $action then .
    else [$action, .]
    end' "$TMP_FILE" > "${TMP_FILE}.2"
  mv "${TMP_FILE}.2" "$TMP_FILE"
done

mv "$TMP_FILE" "$AUDIT_FILE"

echo "✅ Audit file updated successfully"
echo "   File: $AUDIT_FILE"
echo "   Actions added: ${ACTIONS}"
echo "   Timestamp: $TIMESTAMP"
echo ""
echo "Audit trail entry:"
echo "$AUDIT_ENTRY" | jq '.'
