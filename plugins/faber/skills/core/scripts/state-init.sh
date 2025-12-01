#!/usr/bin/env bash
#
# state-init.sh - Initialize FABER workflow state
#
# Usage:
#   state-init.sh <work-id> [workflow-id] [<state-file>]

set -euo pipefail

WORK_ID="${1:?Work ID required}"
WORKFLOW_ID="${2:-default}"
STATE_FILE="${3:-.fractary/plugins/faber/state.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create initial state
INITIAL_STATE=$(cat <<EOF
{
  "work_id": "$WORK_ID",
  "workflow_version": "2.0",
  "status": "in_progress",
  "current_phase": "frame",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "phases": {
    "frame": {"status": "pending"},
    "architect": {"status": "pending"},
    "build": {"status": "pending"},
    "evaluate": {"status": "pending"},
    "release": {"status": "pending"}
  },
  "artifacts": {},
  "retries": {},
  "errors": []
}
EOF
)

# Write state atomically
echo "$INITIAL_STATE" | "$SCRIPT_DIR/state-write.sh" "$STATE_FILE"

echo "✓ State initialized for work item: $WORK_ID"
exit 0
