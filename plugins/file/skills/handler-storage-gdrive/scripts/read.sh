#!/bin/bash
# Google Drive Storage Handler: Read
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
RCLONE_REMOTE="$1"
FOLDER_ID="$2"
REMOTE_PATH="$3"
MAX_BYTES="${4:-10485760}"  # 10MB default

# Check rclone is available
if ! command -v rclone >/dev/null 2>&1; then
    echo "Error: rclone not found. Install from https://rclone.org/install/" >&2
    exit 3
fi

# Check rclone remote is configured
if ! rclone listremotes | grep -q "^${RCLONE_REMOTE}:"; then
    echo "Error: rclone remote '$RCLONE_REMOTE' not configured" >&2
    exit 3
fi

# Build target path
if [[ "$FOLDER_ID" == "root" ]]; then
    TARGET="${RCLONE_REMOTE}:${REMOTE_PATH}"
else
    TARGET="${RCLONE_REMOTE}:{${FOLDER_ID}}/${REMOTE_PATH}"
fi

# Get file size first
FILE_INFO=$(rclone lsjson "$TARGET" 2>/dev/null)

if [[ $? -ne 0 ]] || [[ -z "$FILE_INFO" ]]; then
    echo "Error: File not found in Google Drive: $REMOTE_PATH" >&2
    exit 10
fi

SIZE=$(echo "$FILE_INFO" | jq -r '.[0].Size // 0')

# Warn if file exceeds limit
if (( SIZE > MAX_BYTES )); then
    echo "[Warning: File size $SIZE bytes exceeds max $MAX_BYTES bytes, truncating]" >&2
fi

# Stream file to stdout, truncate if needed
rclone cat "$TARGET" 2>/dev/null | head -c "$MAX_BYTES"

# Show truncation message if needed
if (( SIZE > MAX_BYTES )); then
    echo "" >&2
    echo "[Truncated. Full file size: $SIZE bytes. Use --max-bytes=$SIZE or download full file]" >&2
fi
