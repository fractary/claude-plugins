#!/bin/bash
# Acquire advisory lock for auto-backup operations
# Prevents race conditions between concurrent archive operations
set -euo pipefail

LOCK_FILE="${1:-/logs/.auto-backup.lock}"
TIMEOUT="${2:-300}"  # 5 minutes default timeout

# Function to check if process is running
is_process_running() {
    local pid=$1
    kill -0 "$pid" 2>/dev/null
}

# Check if lock exists
if [[ -f "$LOCK_FILE" ]]; then
    # Read PID from lock file
    LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")

    if [[ -n "$LOCK_PID" ]] && is_process_running "$LOCK_PID"; then
        # Lock is held by running process
        echo "Auto-backup already running (PID: $LOCK_PID)" >&2
        exit 1
    else
        # Stale lock (process died)
        echo "Removing stale lock file (PID: $LOCK_PID)" >&2
        rm -f "$LOCK_FILE"
    fi
fi

# Create lock file with current PID
echo "$$" > "$LOCK_FILE"

# Verify lock was acquired (check for race condition)
ACQUIRED_PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
if [[ "$ACQUIRED_PID" != "$$" ]]; then
    echo "Failed to acquire lock (race condition detected)" >&2
    exit 1
fi

echo "Lock acquired (PID: $$)"
exit 0
