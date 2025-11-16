#!/usr/bin/env bash
# Discover and filter log files
# Usage: discover-logs.sh {log_type_filter} {status_filter} {date_from} {date_to}
# Returns: JSON array of log metadata

set -euo pipefail

LOG_TYPE_FILTER="${1:-all}"
STATUS_FILTER="${2:-}"
DATE_FROM="${3:-}"
DATE_TO="${4:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LOGS_DIR="${FRACTARY_LOGS_DIR:-.fractary/logs}"

# Check if logs directory exists
if [[ ! -d "$LOGS_DIR" ]]; then
  echo "[]"  # Return empty array
  exit 0
fi

# Find log files
if [[ "$LOG_TYPE_FILTER" != "all" ]]; then
  # Filter by specific type
  LOG_FILES=$(find "$LOGS_DIR/$LOG_TYPE_FILTER" -name "*.md" -type f 2>/dev/null || true)
else
  # All types
  LOG_FILES=$(find "$LOGS_DIR" -name "*.md" -type f 2>/dev/null || true)
fi

if [[ -z "$LOG_FILES" ]]; then
  echo "[]"
  exit 0
fi

# Parse frontmatter and build JSON array
declare -a LOGS_JSON=()

while IFS= read -r log_path; do
  # Extract frontmatter (between first two --- markers)
  FRONTMATTER=$(awk '/^---$/{if(++n==2)exit;next}n==1' "$log_path" 2>/dev/null || true)

  if [[ -z "$FRONTMATTER" ]]; then
    # Skip logs without frontmatter
    continue
  fi

  # Parse frontmatter fields (basic YAML parsing)
  LOG_TYPE=$(echo "$FRONTMATTER" | grep '^log_type:' | sed 's/log_type:[[:space:]]*//' | tr -d '"' || echo "")
  TITLE=$(echo "$FRONTMATTER" | grep '^title:' | sed 's/title:[[:space:]]*//' | tr -d '"' || echo "")
  STATUS=$(echo "$FRONTMATTER" | grep '^status:' | sed 's/status:[[:space:]]*//' | tr -d '"' || echo "")
  DATE=$(echo "$FRONTMATTER" | grep '^date:' | sed 's/date:[[:space:]]*//' | tr -d '"' || echo "")

  # Apply status filter
  if [[ -n "$STATUS_FILTER" ]] && [[ "$STATUS" != "$STATUS_FILTER" ]]; then
    continue
  fi

  # Apply date filters
  if [[ -n "$DATE_FROM" ]] && [[ "$DATE" < "$DATE_FROM" ]]; then
    continue
  fi

  if [[ -n "$DATE_TO" ]] && [[ "$DATE" > "$DATE_TO" ]]; then
    continue
  fi

  # Extract log ID (filename without extension)
  LOG_ID=$(basename "$log_path" .md)

  # Build JSON object
  LOG_JSON=$(cat <<EOF
{
  "path": "$log_path",
  "log_type": "$LOG_TYPE",
  "log_id": "$LOG_ID",
  "title": "$TITLE",
  "status": "$STATUS",
  "date": "$DATE"
}
EOF
)

  LOGS_JSON+=("$LOG_JSON")
done <<< "$LOG_FILES"

# Output JSON array
if [[ ${#LOGS_JSON[@]} -eq 0 ]]; then
  echo "[]"
else
  printf '%s\n' "${LOGS_JSON[@]}" | jq -s '.'
fi
