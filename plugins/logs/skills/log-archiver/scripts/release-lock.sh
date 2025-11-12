#!/bin/bash
# Release advisory lock for auto-backup operations
set -euo pipefail

LOCK_FILE="${1:-/logs/.auto-backup.lock}"

# Check if lock exists
if [[ ! -f "$LOCK_FILE" ]]; then
    echo "Warning: Lock file does not exist" >&2
    exit 0
fi

# Read PID from lock file
LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")

# Only remove lock if it belongs to us
if [[ "$LOCK_PID" == "$$" ]]; then
    rm -f "$LOCK_FILE"
    echo "Lock released (PID: $$)"
else
    echo "Warning: Lock belongs to different process (PID: $LOCK_PID)" >&2
    exit 1
fi

exit 0
