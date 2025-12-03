#!/usr/bin/env bash
# emit-event.sh - Emit a workflow event to fractary-logs
#
# Usage:
#   emit-event.sh --event-type <type> --workflow-id <id> --payload '<json>'
#
# Arguments:
#   --event-type   One of: workflow_start, phase_start, step_start, step_complete,
#                  artifact_create, phase_complete, workflow_complete
#   --workflow-id  Unique workflow identifier (auto-generated if not provided with --work-id)
#   --work-id      Work item ID for auto-generating workflow_id (optional)
#   --payload      JSON object with event-specific data
#
# Environment:
#   FRACTARY_ENV   Environment name (defaults to "development")
#
# Output:
#   Writes event JSON to .fractary/logs/workflow/ directory
#   Returns JSON with status, event_type, workflow_id, timestamp, log_path

set -euo pipefail

# Valid event types
VALID_EVENT_TYPES="workflow_start phase_start step_start step_complete artifact_create phase_complete workflow_complete"

# Parse arguments
EVENT_TYPE=""
WORKFLOW_ID=""
WORK_ID=""
PAYLOAD="{}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --event-type)
      EVENT_TYPE="$2"
      shift 2
      ;;
    --workflow-id)
      WORKFLOW_ID="$2"
      shift 2
      ;;
    --work-id)
      WORK_ID="$2"
      shift 2
      ;;
    --payload)
      PAYLOAD="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Validate event_type
if [[ -z "$EVENT_TYPE" ]]; then
  echo "Error: --event-type is required" >&2
  exit 1
fi

if ! echo "$VALID_EVENT_TYPES" | grep -qw "$EVENT_TYPE"; then
  echo "Error: Invalid event_type: '$EVENT_TYPE'" >&2
  echo "Valid types: $VALID_EVENT_TYPES" >&2
  exit 1
fi

# Validate payload is valid JSON
if ! echo "$PAYLOAD" | jq empty 2>/dev/null; then
  echo "Error: Invalid JSON payload" >&2
  exit 1
fi

# Generate timestamp with high precision for unique filenames
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP_FILENAME=$(date -u +"%Y%m%dT%H%M%S%3N")  # Includes milliseconds for uniqueness

# Generate workflow_id if not provided
if [[ -z "$WORKFLOW_ID" ]]; then
  WORK_ID_PART="${WORK_ID:-unknown}"
  TIMESTAMP_PART=$(date -u +"%Y%m%dT%H%M%SZ")
  WORKFLOW_ID="workflow-${WORK_ID_PART}-${TIMESTAMP_PART}"
fi

# Detect project from git or PWD
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  PROJECT=$(basename "$(git rev-parse --show-toplevel)")
else
  PROJECT=$(basename "$PWD")
fi

# Detect environment
ENVIRONMENT="${FRACTARY_ENV:-development}"

# Build full event object
EVENT=$(jq -n \
  --arg event_type "$EVENT_TYPE" \
  --arg workflow_id "$WORKFLOW_ID" \
  --arg timestamp "$TIMESTAMP" \
  --arg project "$PROJECT" \
  --arg environment "$ENVIRONMENT" \
  --argjson payload "$PAYLOAD" \
  '{
    event_type: $event_type,
    workflow_id: $workflow_id,
    timestamp: $timestamp,
    project: $project,
    environment: $environment,
    payload: $payload
  }')

# Determine log directory
LOG_DIR=".fractary/logs/workflow"
mkdir -p "$LOG_DIR"

# Generate unique filename: workflow_id-event_type-timestamp.json
# The timestamp includes milliseconds to prevent collisions when multiple
# events of the same type are emitted within the same workflow
FILENAME="${WORKFLOW_ID}-${EVENT_TYPE}-${TIMESTAMP_FILENAME}.json"
LOG_PATH="${LOG_DIR}/${FILENAME}"

# Write event to file (atomic write via temp file)
TEMP_FILE=$(mktemp)
echo "$EVENT" > "$TEMP_FILE"
mv "$TEMP_FILE" "$LOG_PATH"

# Return result
jq -n \
  --arg status "success" \
  --arg event_type "$EVENT_TYPE" \
  --arg workflow_id "$WORKFLOW_ID" \
  --arg timestamp "$TIMESTAMP" \
  --arg log_path "$LOG_PATH" \
  '{
    status: $status,
    event_type: $event_type,
    workflow_id: $workflow_id,
    timestamp: $timestamp,
    log_path: $log_path
  }'
