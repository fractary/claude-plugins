#!/bin/bash
# Local Storage Handler: Read
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
BASE_PATH="$1"
REMOTE_PATH="$2"
MAX_BYTES="${3:-10485760}"  # 10MB default

# Construct file path
FILE_PATH="$BASE_PATH/$REMOTE_PATH"

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
    echo "Error: File not found: $FILE_PATH" >&2
    exit 10
fi

# Get file size
if SIZE=$(stat -c%s "$FILE_PATH" 2>/dev/null); then
    :
elif SIZE=$(stat -f%z "$FILE_PATH" 2>/dev/null); then
    :
else
    echo "Error: Cannot determine file size" >&2
    exit 1
fi

# Warn if file exceeds limit
if (( SIZE > MAX_BYTES )); then
    echo "[Warning: File size $SIZE bytes exceeds max $MAX_BYTES bytes, truncating]" >&2
fi

# Stream file contents to stdout (truncated if exceeds max)
head -c "$MAX_BYTES" "$FILE_PATH"

# Show truncation message if needed
if (( SIZE > MAX_BYTES )); then
    echo "" >&2
    echo "[Truncated. Full file size: $SIZE bytes. Use --max-bytes=$SIZE or download full file]" >&2
fi
