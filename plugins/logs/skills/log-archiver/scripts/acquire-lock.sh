#!/bin/bash
# Acquire advisory lock for auto-backup operations using flock
# Prevents race conditions between concurrent archive operations
set -euo pipefail

LOCK_FILE="${1:-/logs/.auto-backup.lock}"
TIMEOUT="${2:-5}"  # 5 seconds default timeout (non-blocking)

# Ensure lock file exists (touch is safe if it already exists)
touch "$LOCK_FILE" 2>/dev/null || {
    echo "Error: Cannot create lock file: $LOCK_FILE" >&2
    exit 1
}

# Try to acquire exclusive lock with timeout
# -x: exclusive lock
# -n: non-blocking (fail immediately if locked)
# -w: wait timeout in seconds
if flock -x -w "$TIMEOUT" 200; then
    # Lock acquired successfully
    # Write PID to lock file for monitoring/debugging
    echo "$$" >&200
    echo "Lock acquired (PID: $$)"
    exit 0
else
    # Lock is held by another process
    echo "Auto-backup already running (lock held)" >&2
    exit 1
fi 200>"$LOCK_FILE"
