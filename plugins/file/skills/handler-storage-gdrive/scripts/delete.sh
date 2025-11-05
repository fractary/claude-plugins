#!/bin/bash
# Google Drive Storage Handler: Delete
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
RCLONE_REMOTE="$1"
FOLDER_ID="$2"
REMOTE_PATH="$3"

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

# Delete file
if ! rclone delete "$TARGET" 2>&1; then
    echo "Error: Failed to delete file from Google Drive" >&2
    exit 12
fi

# Return JSON result
jq -n \
    --arg path "$REMOTE_PATH" \
    '{success: true, message: "File deleted from Google Drive successfully", remote_path: $path}'
