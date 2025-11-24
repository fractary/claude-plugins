#!/usr/bin/env bash
#
# analyze-migration.sh
# Analyze migration files for destructive operations and safety risks
#
# Usage:
#   analyze-migration.sh <migration_file>
#
# Arguments:
#   migration_file - Path to migration SQL file
#
# Output:
#   JSON with analysis results
#
# Example:
#   ./analyze-migration.sh prisma/migrations/20250124140000_drop_tables/migration.sql
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
if [ $# -lt 1 ]; then
    echo '{"status":"error","error":"Usage: analyze-migration.sh <migration_file>"}'
    exit 1
fi

MIGRATION_FILE="$1"

# Verify file exists
if [ ! -f "$MIGRATION_FILE" ]; then
    echo "{\"status\":\"error\",\"error\":\"Migration file not found: $MIGRATION_FILE\"}"
    exit 1
fi

# Initialize analysis results
RISK_LEVEL="low"
DESTRUCTIVE_OPS=()
IS_SAFE=true

# Analyze for critical patterns (block)
if grep -qiE "DROP\s+DATABASE" "$MIGRATION_FILE"; then
    RISK_LEVEL="critical"
    IS_SAFE=false
    DESTRUCTIVE_OPS+=('{"type":"DROP_DATABASE","severity":"critical","line":'$(grep -niE "DROP\s+DATABASE" "$MIGRATION_FILE" | cut -d: -f1 | head -1)',"sql":"'$(grep -iE "DROP\s+DATABASE" "$MIGRATION_FILE" | head -1 | sed 's/"/\\"/g')'"}')
fi

if grep -qiE "DROP\s+SCHEMA" "$MIGRATION_FILE"; then
    RISK_LEVEL="critical"
    IS_SAFE=false
    DESTRUCTIVE_OPS+=('{"type":"DROP_SCHEMA","severity":"critical","line":'$(grep -niE "DROP\s+SCHEMA" "$MIGRATION_FILE" | cut -d: -f1 | head -1)',"sql":"'$(grep -iE "DROP\s+SCHEMA" "$MIGRATION_FILE" | head -1 | sed 's/"/\\"/g')'"}')
fi

# Analyze for high-risk patterns
if grep -qiE "DROP\s+TABLE" "$MIGRATION_FILE"; then
    if [ "$RISK_LEVEL" != "critical" ]; then
        RISK_LEVEL="high"
    fi
    IS_SAFE=false

    # Extract all DROP TABLE statements
    while IFS= read -r line; do
        LINE_NUM=$(echo "$line" | cut -d: -f1)
        SQL=$(echo "$line" | cut -d: -f2- | xargs)
        TABLE=$(echo "$SQL" | grep -oiE "DROP\s+TABLE\s+[IF\s+EXISTS\s+]*[\"\`]?([a-zA-Z_][a-zA-Z0-9_]*)[\"\`]?" | awk '{print $NF}' | tr -d '"`')
        # Use jq to safely construct JSON and avoid injection vulnerabilities
        OP_JSON=$(jq -n \
            --arg type "DROP_TABLE" \
            --arg severity "high" \
            --arg table "$TABLE" \
            --argjson line "$LINE_NUM" \
            --arg sql "$SQL" \
            '{type: $type, severity: $severity, table: $table, line: $line, sql: $sql}')
        DESTRUCTIVE_OPS+=("$OP_JSON")
    done < <(grep -niE "DROP\s+TABLE" "$MIGRATION_FILE")
fi

if grep -qiE "TRUNCATE\s+(TABLE\s+)?" "$MIGRATION_FILE"; then
    if [ "$RISK_LEVEL" != "critical" ]; then
        RISK_LEVEL="high"
    fi
    IS_SAFE=false

    while IFS= read -r line; do
        LINE_NUM=$(echo "$line" | cut -d: -f1)
        SQL=$(echo "$line" | cut -d: -f2- | xargs)
        TABLE=$(echo "$SQL" | grep -oiE "TRUNCATE\s+(TABLE\s+)?[\"\`]?([a-zA-Z_][a-zA-Z0-9_]*)[\"\`]?" | awk '{print $NF}' | tr -d '"`')
        # Use jq to safely construct JSON and avoid injection vulnerabilities
        OP_JSON=$(jq -n \
            --arg type "TRUNCATE" \
            --arg severity "high" \
            --arg table "$TABLE" \
            --argjson line "$LINE_NUM" \
            --arg sql "$SQL" \
            '{type: $type, severity: $severity, table: $table, line: $line, sql: $sql}')
        DESTRUCTIVE_OPS+=("$OP_JSON")
    done < <(grep -niE "TRUNCATE\s+(TABLE\s+)?" "$MIGRATION_FILE")
fi

# Check for DELETE statements
if grep -qiE "DELETE\s+FROM" "$MIGRATION_FILE"; then
    # Check if DELETE has WHERE clause
    if grep -qiE "DELETE\s+FROM.*WHERE" "$MIGRATION_FILE"; then
        # DELETE with WHERE - medium risk
        if [ "$RISK_LEVEL" = "low" ]; then
            RISK_LEVEL="medium"
        fi
    else
        # DELETE without WHERE - high risk (deletes all rows)
        if [ "$RISK_LEVEL" != "critical" ]; then
            RISK_LEVEL="high"
        fi
        IS_SAFE=false
    fi

    while IFS= read -r line; do
        LINE_NUM=$(echo "$line" | cut -d: -f1)
        SQL=$(echo "$line" | cut -d: -f2- | xargs)
        TABLE=$(echo "$SQL" | grep -oiE "DELETE\s+FROM\s+[\"\`]?([a-zA-Z_][a-zA-Z0-9_]*)[\"\`]?" | awk '{print $NF}' | tr -d '"`')

        if echo "$SQL" | grep -qiE "WHERE"; then
            SEVERITY="medium"
        else
            SEVERITY="high"
        fi

        # Use jq to safely construct JSON and avoid injection vulnerabilities
        OP_JSON=$(jq -n \
            --arg type "DELETE" \
            --arg severity "$SEVERITY" \
            --arg table "$TABLE" \
            --argjson line "$LINE_NUM" \
            --arg sql "$SQL" \
            '{type: $type, severity: $severity, table: $table, line: $line, sql: $sql}')
        DESTRUCTIVE_OPS+=("$OP_JSON")
    done < <(grep -niE "DELETE\s+FROM" "$MIGRATION_FILE")
fi

# Check for DROP COLUMN
if grep -qiE "DROP\s+COLUMN" "$MIGRATION_FILE"; then
    if [ "$RISK_LEVEL" = "low" ]; then
        RISK_LEVEL="medium"
    fi
    IS_SAFE=false

    while IFS= read -r line; do
        LINE_NUM=$(echo "$line" | cut -d: -f1)
        SQL=$(echo "$line" | cut -d: -f2- | xargs)
        COLUMN=$(echo "$SQL" | grep -oiE "DROP\s+COLUMN\s+[\"\`]?([a-zA-Z_][a-zA-Z0-9_]*)[\"\`]?" | awk '{print $NF}' | tr -d '"`')
        # Use jq to safely construct JSON and avoid injection vulnerabilities
        OP_JSON=$(jq -n \
            --arg type "DROP_COLUMN" \
            --arg severity "medium" \
            --arg column "$COLUMN" \
            --argjson line "$LINE_NUM" \
            --arg sql "$SQL" \
            '{type: $type, severity: $severity, column: $column, line: $line, sql: $sql}')
        DESTRUCTIVE_OPS+=("$OP_JSON")
    done < <(grep -niE "DROP\s+COLUMN" "$MIGRATION_FILE")
fi

# Check for ALTER TABLE (schema changes)
if grep -qiE "ALTER\s+TABLE" "$MIGRATION_FILE"; then
    # Only flag if not already higher risk
    if [ "$RISK_LEVEL" = "low" ]; then
        RISK_LEVEL="medium"
    fi
fi

# Build JSON array of destructive operations using jq for safe construction
if [ ${#DESTRUCTIVE_OPS[@]} -eq 0 ]; then
    DESTRUCTIVE_OPS_JSON="[]"
else
    # Use jq to properly construct JSON array from individual JSON objects
    DESTRUCTIVE_OPS_JSON=$(printf '%s\n' "${DESTRUCTIVE_OPS[@]}" | jq -s '.')
fi

# Determine approval requirements
if [ "$RISK_LEVEL" = "critical" ]; then
    APPROVAL="blocked"
    CAN_PROCEED="false"
elif [ "$RISK_LEVEL" = "high" ]; then
    APPROVAL="enhanced"
    CAN_PROCEED="with_confirmation"
elif [ "$RISK_LEVEL" = "medium" ]; then
    APPROVAL="standard"
    CAN_PROCEED="true"
else
    APPROVAL="none"
    CAN_PROCEED="true"
fi

# Output JSON results
cat <<EOF
{
  "status": "success",
  "migration_file": "$MIGRATION_FILE",
  "analysis": {
    "risk_level": "$RISK_LEVEL",
    "is_safe": $IS_SAFE,
    "destructive_operations_count": ${#DESTRUCTIVE_OPS[@]},
    "destructive_operations": $DESTRUCTIVE_OPS_JSON,
    "approval_required": "$APPROVAL",
    "can_proceed": "$CAN_PROCEED"
  }
}
EOF

exit 0
