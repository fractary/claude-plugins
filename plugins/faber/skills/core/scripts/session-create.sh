#!/bin/bash
# FABER Core: Session Creator
# Creates a new FABER workflow session

set -euo pipefail

# Check arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <work_id> <issue_id> <domain>" >&2
    exit 2
fi

WORK_ID="$1"
ISSUE_ID="$2"
DOMAIN="$3"

# Load configuration to get session storage path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JSON=$("$SCRIPT_DIR/config-loader.sh")

if [ $? -ne 0 ]; then
    echo "Error: Failed to load configuration" >&2
    exit 3
fi

# Get session storage path
SESSION_STORAGE=$(echo "$CONFIG_JSON" | jq -r '.session.session_storage // ".faber/sessions"')

# Create session directory if it doesn't exist
mkdir -p "$SESSION_STORAGE"

# Session file path
SESSION_FILE="$SESSION_STORAGE/${WORK_ID}.json"

# Check if session already exists
if [ -f "$SESSION_FILE" ]; then
    echo "Error: Session already exists: $WORK_ID" >&2
    echo "Use session-update.sh to update existing sessions" >&2
    exit 4
fi

# Create timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get project info from config
PROJECT_NAME=$(echo "$CONFIG_JSON" | jq -r '.project.name')
ISSUE_SYSTEM=$(echo "$CONFIG_JSON" | jq -r '.project.issue_system')
AUTONOMY=$(echo "$CONFIG_JSON" | jq -r '.defaults.autonomy')

# Create session JSON
SESSION_JSON=$(jq -n \
    --arg work_id "$WORK_ID" \
    --arg issue_id "$ISSUE_ID" \
    --arg domain "$DOMAIN" \
    --arg project "$PROJECT_NAME" \
    --arg issue_system "$ISSUE_SYSTEM" \
    --arg autonomy "$AUTONOMY" \
    --arg created "$TIMESTAMP" \
    --arg updated "$TIMESTAMP" \
    '{
        work_id: $work_id,
        issue_id: $issue_id,
        domain: $domain,
        project: $project,
        issue_system: $issue_system,
        autonomy: $autonomy,
        created_at: $created,
        updated_at: $updated,
        status: "active",
        current_stage: "initialized",
        stages: {
            frame: {status: "pending"},
            architect: {status: "pending"},
            build: {status: "pending"},
            evaluate: {status: "pending"},
            release: {status: "pending"}
        },
        metadata: {},
        history: [
            {
                stage: "initialized",
                status: "created",
                timestamp: $created
            }
        ]
    }'
)

# Write session file
echo "$SESSION_JSON" > "$SESSION_FILE"

if [ $? -ne 0 ]; then
    echo "Error: Failed to create session file: $SESSION_FILE" >&2
    exit 4
fi

# Output session JSON
echo "$SESSION_JSON"
exit 0
