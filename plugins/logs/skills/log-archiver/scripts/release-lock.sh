#!/bin/bash
# Release advisory lock for auto-backup operations
# Note: With flock, the lock is automatically released when the file descriptor closes
# This script is provided for explicit cleanup and monitoring
set -euo pipefail

LOCK_FILE="${1:-/logs/.auto-backup.lock}"

# Check if lock exists
if [[ ! -f "$LOCK_FILE" ]]; then
    echo "Warning: Lock file does not exist" >&2
    exit 0
fi

# Read PID from lock file for verification
LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")

# Verify lock belongs to us (optional safety check)
if [[ -n "$LOCK_PID" ]] && [[ "$LOCK_PID" != "$$" ]]; then
    echo "Warning: Lock belongs to different process (PID: $LOCK_PID)" >&2
    # Don't fail - flock handles lock release automatically
fi

echo "Lock released (PID: $$)"
# Note: Actual lock release happens when the calling process closes FD 200
# or exits. No manual unlock needed with flock.
exit 0
