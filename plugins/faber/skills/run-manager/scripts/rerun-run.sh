#!/usr/bin/env bash
#
# rerun-run.sh - Create a new run based on a previous run
#
# Usage:
#   rerun-run.sh --run-id <original-run-id> [--autonomy <level>] [--phases <phases>]
#
# Description:
#   Creates a new run that references the original run.
#   The new run inherits work_id and target from the original.
#   Parameter overrides can be applied via flags.
#
# Arguments:
#   --run-id <run-id>     Original run identifier (format: org/project/uuid)
#   --autonomy <level>    Optional: Override autonomy level
#   --phases <phases>     Optional: Override phases (comma-separated)
#
# Returns:
#   JSON object with new run_id and rerun context
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH=".fractary/plugins/faber/runs"

# Parse arguments
ORIGINAL_RUN_ID=""
AUTONOMY_OVERRIDE=""
PHASES_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --run-id)
            ORIGINAL_RUN_ID="$2"
            shift 2
            ;;
        --autonomy)
            AUTONOMY_OVERRIDE="$2"
            shift 2
            ;;
        --phases)
            PHASES_OVERRIDE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Validate run_id
if [ -z "$ORIGINAL_RUN_ID" ]; then
    echo "Error: --run-id is required" >&2
    exit 1
fi

# Validate run_id format
if ! echo "$ORIGINAL_RUN_ID" | grep -qE '^[a-z0-9_-]+/[a-z0-9_-]+/[a-f0-9-]{36}$'; then
    echo "Error: Invalid run_id format. Expected: org/project/uuid" >&2
    exit 1
fi

# Check if original run directory exists
ORIGINAL_RUN_DIR="$BASE_PATH/$ORIGINAL_RUN_ID"
if [ ! -d "$ORIGINAL_RUN_DIR" ]; then
    cat <<EOF
{
  "status": "error",
  "operation": "rerun-run",
  "original_run_id": "$ORIGINAL_RUN_ID",
  "error": "Original run directory not found: $ORIGINAL_RUN_DIR"
}
EOF
    exit 1
fi

# Load original metadata
ORIGINAL_METADATA_FILE="$ORIGINAL_RUN_DIR/metadata.json"
if [ ! -f "$ORIGINAL_METADATA_FILE" ]; then
    cat <<EOF
{
  "status": "error",
  "operation": "rerun-run",
  "original_run_id": "$ORIGINAL_RUN_ID",
  "error": "Original metadata file not found: $ORIGINAL_METADATA_FILE"
}
EOF
    exit 1
fi

ORIGINAL_METADATA=$(cat "$ORIGINAL_METADATA_FILE")

# Extract org and project from original run_id
ORG=$(echo "$ORIGINAL_RUN_ID" | cut -d'/' -f1)
PROJECT=$(echo "$ORIGINAL_RUN_ID" | cut -d'/' -f2)

# Generate new run_id
NEW_UUID=$("$SCRIPT_DIR/generate-run-id.sh" --uuid-only 2>/dev/null || uuidgen | tr 'A-F' 'a-f')
NEW_RUN_ID="$ORG/$PROJECT/$NEW_UUID"

# Extract original values
ORIGINAL_WORK_ID=$(echo "$ORIGINAL_METADATA" | jq -r '.work_id // ""')
ORIGINAL_TARGET=$(echo "$ORIGINAL_METADATA" | jq -r '.target // ""')
ORIGINAL_WORKFLOW=$(echo "$ORIGINAL_METADATA" | jq -r '.workflow_id // "default"')
ORIGINAL_AUTONOMY=$(echo "$ORIGINAL_METADATA" | jq -r '.autonomy // "guarded"')
ORIGINAL_PHASES=$(echo "$ORIGINAL_METADATA" | jq -c '.phases // ["frame","architect","build","evaluate","release"]')

# Apply overrides
FINAL_AUTONOMY="${AUTONOMY_OVERRIDE:-$ORIGINAL_AUTONOMY}"
if [ -n "$PHASES_OVERRIDE" ]; then
    # Convert comma-separated to JSON array
    FINAL_PHASES=$(echo "$PHASES_OVERRIDE" | tr ',' '\n' | jq -R . | jq -s .)
else
    FINAL_PHASES="$ORIGINAL_PHASES"
fi

# Initialize the new run directory
"$SCRIPT_DIR/init-run-directory.sh" \
    --run-id "$NEW_RUN_ID" \
    --work-id "$ORIGINAL_WORK_ID" \
    --target "$ORIGINAL_TARGET" \
    --workflow "$ORIGINAL_WORKFLOW" \
    --autonomy "$FINAL_AUTONOMY" \
    --rerun-of "$ORIGINAL_RUN_ID" > /dev/null 2>&1 || {
        cat <<EOF
{
  "status": "error",
  "operation": "rerun-run",
  "original_run_id": "$ORIGINAL_RUN_ID",
  "new_run_id": "$NEW_RUN_ID",
  "error": "Failed to initialize new run directory"
}
EOF
        exit 1
    }

# Update metadata with phases
NEW_RUN_DIR="$BASE_PATH/$NEW_RUN_ID"
METADATA_FILE="$NEW_RUN_DIR/metadata.json"
if [ -f "$METADATA_FILE" ]; then
    TMP_METADATA=$(mktemp)
    jq --argjson phases "$FINAL_PHASES" '.phases = $phases' "$METADATA_FILE" > "$TMP_METADATA"
    mv "$TMP_METADATA" "$METADATA_FILE"
fi

# Emit workflow_rerun event
"$SCRIPT_DIR/emit-event.sh" \
    --run-id "$NEW_RUN_ID" \
    --type "workflow_rerun" \
    --message "Rerun of run $ORIGINAL_RUN_ID" \
    --data "{\"original_run_id\": \"$ORIGINAL_RUN_ID\", \"changes\": {\"autonomy\": \"$FINAL_AUTONOMY\", \"phases\": $FINAL_PHASES}}" > /dev/null 2>&1 || true

# Return success with new run context
cat <<EOF
{
  "status": "success",
  "operation": "rerun-run",
  "original_run_id": "$ORIGINAL_RUN_ID",
  "new_run_id": "$NEW_RUN_ID",
  "work_id": "$ORIGINAL_WORK_ID",
  "target": "$ORIGINAL_TARGET",
  "workflow_id": "$ORIGINAL_WORKFLOW",
  "autonomy": "$FINAL_AUTONOMY",
  "phases": $FINAL_PHASES,
  "relationships": {
    "rerun_of": "$ORIGINAL_RUN_ID"
  },
  "run_path": "$NEW_RUN_DIR"
}
EOF
exit 0
