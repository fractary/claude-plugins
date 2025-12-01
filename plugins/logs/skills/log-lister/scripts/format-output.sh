#!/usr/bin/env bash
# Format log list output
# Usage: format-output.sh {format} {logs_json}
# Returns: Formatted output to stdout

set -euo pipefail

FORMAT="${1:-table}"
LOGS_JSON="${2:-[]}"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required for output formatting" >&2
  exit 1
fi

# Validate JSON
if ! echo "$LOGS_JSON" | jq empty 2>/dev/null; then
  echo "ERROR: Invalid JSON input" >&2
  exit 1
fi

LOG_COUNT=$(echo "$LOGS_JSON" | jq 'length')

case "$FORMAT" in
  table)
    # Table format with aligned columns
    echo "TYPE        TITLE                                STATUS      DATE         "
    echo "─────────────────────────────────────────────────────────────────────────────"

    echo "$LOGS_JSON" | jq -r '.[] | [
      .log_type,
      (.title | .[0:40]),
      .status,
      (.date | .[0:10])
    ] | @tsv' | while IFS=$'\t' read -r type title status date; do
      printf "%-11s %-40s %-11s %-12s\n" "$type" "$title" "$status" "$date"
    done

    echo ""
    echo "Total: $LOG_COUNT logs"
    ;;

  json)
    # JSON format (pass through with metadata wrapper)
    cat <<EOF
{
  "logs": $LOGS_JSON,
  "metadata": {
    "total": $LOG_COUNT,
    "format": "json"
  }
}
EOF
    ;;

  summary)
    # Summary format with statistics
    echo "Log Summary"
    echo "───────────────────────────────────────"
    echo "Total logs: $LOG_COUNT"
    echo ""

    # By type
    echo "By type:"
    echo "$LOGS_JSON" | jq -r '
      group_by(.log_type) |
      map({
        type: .[0].log_type,
        count: length,
        statuses: [.[].status] | group_by(.) | map({status: .[0], count: length})
      }) |
      .[] |
      "  - \(.type): \(.count) logs (\(.statuses | map("\(.count) \(.status)") | join(", ")))"
    '

    echo ""

    # By status
    echo "By status:"
    echo "$LOGS_JSON" | jq -r '
      group_by(.status) |
      map({status: .[0].status, count: length}) |
      .[] |
      "  - \(.status): \(.count)"
    '
    ;;

  detailed)
    # Detailed format with full frontmatter preview
    echo "$LOGS_JSON" | jq -r '.[] | "
═══════════════════════════════════════
Type: \(.log_type)
ID: \(.log_id)
Title: \(.title)
Status: \(.status)
Date: \(.date)
Path: \(.path)
"'
    echo "═══════════════════════════════════════"
    echo "Total: $LOG_COUNT logs"
    ;;

  *)
    echo "ERROR: Unknown format '$FORMAT'" >&2
    echo "Valid formats: table, json, summary, detailed" >&2
    exit 1
    ;;
esac
