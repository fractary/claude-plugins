#!/bin/bash
# Document teardown in deployment history
set -e

ENV=$1
RESOURCE_COUNT=$2
COST_SAVINGS=$3

if [ -z "$ENV" ]; then
  echo "Error: Environment not specified"
  exit 1
fi

# Get user info
USER=$(git config user.name || echo "Unknown")
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Deployment history file
HISTORY_FILE="docs/infrastructure/deployments.md"

# Create docs directory if it doesn't exist
mkdir -p "$(dirname "$HISTORY_FILE")"

# Create file if it doesn't exist
if [ ! -f "$HISTORY_FILE" ]; then
  cat > "$HISTORY_FILE" <<'EOF'
# Infrastructure Deployment History

This file tracks all infrastructure deployments and teardowns.

---

EOF
fi

# Get state backup file (latest)
BACKUP_FILE=$(ls -t infrastructure/backups/terraform-state-${ENV}-*.tfstate 2>/dev/null | head -n 1)

# Append teardown entry
cat >> "$HISTORY_FILE" <<EOF

## Teardown - ${ENV} - ${TIMESTAMP}

**Destroyed by:** ${USER}
**Reason:** Manual teardown via /fractary-faber-cloud:teardown
**Resources removed:** ${RESOURCE_COUNT:-"Unknown"}
**Cost savings:** \$${COST_SAVINGS:-"Unknown"}/month
**State backup:** ${BACKUP_FILE:-"Not found"}

### Resources Destroyed:
EOF

# If state backup exists, extract resource list
if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
  jq -r '.resources[] | "- \(.type): \(.name)"' "$BACKUP_FILE" >> "$HISTORY_FILE"
else
  echo "- (Resource list not available)" >> "$HISTORY_FILE"
fi

cat >> "$HISTORY_FILE" <<EOF

---

EOF

echo "✓ Teardown documented in $HISTORY_FILE"
