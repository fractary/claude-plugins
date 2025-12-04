#!/usr/bin/env bash
#
# state-read.sh - Safely read FABER workflow state
#
# Usage:
#   state-read.sh [<state-file>] [<jq-query>]
#
# Examples:
#   state-read.sh                           # Read entire state
#   state-read.sh '.current_phase'          # Query specific field
#   state-read.sh state.json '.status'      # Custom file + query
#
# Features:
#   - Shared locking (flock -s) for read consistency during writes

set -euo pipefail

STATE_FILE="${1:-.fractary/plugins/faber/state.json}"
JQ_QUERY="${2:-.}"
LOCK_TIMEOUT=10  # seconds to wait for shared lock

# Shift if first arg is a file path
if [[ "$STATE_FILE" != .* ]] && [[ "$STATE_FILE" != /* ]] && [[ "$STATE_FILE" == *.json ]]; then
    JQ_QUERY="${2:-.}"
elif [[ "$STATE_FILE" == .* ]]; then
    # First arg is a query, use default file
    JQ_QUERY="$STATE_FILE"
    STATE_FILE=".fractary/plugins/faber/state.json"
fi

if [ ! -f "$STATE_FILE" ]; then
    echo "Error: State file not found: $STATE_FILE" >&2
    exit 1
fi

LOCK_FILE="${STATE_FILE}.lock"

# Acquire shared lock for consistent read
# Multiple readers can hold shared lock; exclusive lock blocks until all readers finish
exec 200>"$LOCK_FILE"
if ! flock -s -w "$LOCK_TIMEOUT" 200; then
    echo "Error: Could not acquire read lock on $STATE_FILE after ${LOCK_TIMEOUT}s" >&2
    exit 1
fi

# Read and query state with jq (under shared lock)
jq -r "$JQ_QUERY" "$STATE_FILE" 2>/dev/null || {
    echo "Error: Failed to read state file or invalid jq query" >&2
    exit 1
}
# Lock automatically released when fd 200 closes (script exit)
