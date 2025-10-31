#!/bin/bash
# FABER Core: Session Updater
# Updates an existing FABER workflow session

set -euo pipefail

# Check arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <session_id> <stage> <status> [data_json]" >&2
    exit 2
fi

SESSION_ID="$1"
STAGE="$2"
STATUS="$3"
DATA_JSON="${4:-{}}"

# Validate stage
case "$STAGE" in
    frame|architect|build|evaluate|release) ;;
    *)
        echo "Error: Invalid stage '$STAGE'. Must be one of: frame, architect, build, evaluate, release" >&2
        exit 2
        ;;
esac

# Validate status
case "$STATUS" in
    started|in_progress|completed|failed|pending) ;;
    *)
        echo "Error: Invalid status '$STATUS'. Must be one of: started, in_progress, completed, failed, pending" >&2
        exit 2
        ;;
esac

# Load configuration to get session storage path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JSON=$("$SCRIPT_DIR/config-loader.sh")

if [ $? -ne 0 ]; then
    echo "Error: Failed to load configuration" >&2
    exit 3
fi

# Get session storage path
SESSION_STORAGE=$(echo "$CONFIG_JSON" | jq -r '.session.session_storage // ".faber/sessions"')
SESSION_FILE="$SESSION_STORAGE/${SESSION_ID}.json"

# Check if session exists
if [ ! -f "$SESSION_FILE" ]; then
    echo "Error: Session not found: $SESSION_ID" >&2
    echo "Use session-create.sh to create a new session" >&2
    exit 4
fi

# Load existing session
EXISTING_SESSION=$(cat "$SESSION_FILE")

# Create timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Update session with new stage status
UPDATED_SESSION=$(echo "$EXISTING_SESSION" | jq \
    --arg stage "$STAGE" \
    --arg status "$STATUS" \
    --arg timestamp "$TIMESTAMP" \
    --argjson data "$DATA_JSON" \
    '
    .updated_at = $timestamp |
    .current_stage = $stage |
    .stages[$stage].status = $status |
    .stages[$stage].updated_at = $timestamp |
    .stages[$stage].data = ($data // {}) |
    .history += [{
        stage: $stage,
        status: $status,
        timestamp: $timestamp,
        data: ($data // {})
    }] |
    # Update overall session status based on stage statuses
    if (.stages.release.status == "completed") then
        .status = "completed"
    elif (.stages.frame.status == "failed" or .stages.architect.status == "failed" or .stages.build.status == "failed" or .stages.evaluate.status == "failed" or .stages.release.status == "failed") then
        .status = "failed"
    else
        .status = "active"
    end
    '
)

# Write updated session
echo "$UPDATED_SESSION" > "$SESSION_FILE"

if [ $? -ne 0 ]; then
    echo "Error: Failed to update session file: $SESSION_FILE" >&2
    exit 4
fi

# Output updated session JSON
echo "$UPDATED_SESSION"
exit 0
