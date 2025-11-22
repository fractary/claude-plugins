#!/bin/bash
# Google Drive Storage Handler: Get URL
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
RCLONE_REMOTE="$1"
FOLDER_ID="$2"
REMOTE_PATH="$3"
EXPIRES_IN="${4:-87600}"  # Default to 10 years (Google Drive links don't expire)

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

# Check if file exists and get ID
FILE_ID=$(rclone lsjson "$TARGET" 2>/dev/null | jq -r '.[0].ID // empty')

if [[ -z "$FILE_ID" ]]; then
    echo "Error: File not found in Google Drive: $REMOTE_PATH" >&2
    exit 10
fi

# Generate shareable link using rclone
# Duration format: 87600h = 10 years (Google Drive links don't expire by default)
DURATION="${EXPIRES_IN}h"

URL=$(rclone link "$TARGET" --expire "$DURATION" 2>/dev/null || echo "")

if [[ -z "$URL" ]]; then
    # Fallback to standard Drive URL
    URL="https://drive.google.com/file/d/${FILE_ID}/view"
    jq -n \
        --arg url "$URL" \
        --arg file_id "$FILE_ID" \
        '{success: true, message: "Drive URL generated (sharing may require permissions)", url: $url, file_id: $file_id, type: "drive_url", note: "Link may require Drive permissions to access"}'
else
    jq -n \
        --arg url "$URL" \
        --arg file_id "$FILE_ID" \
        '{success: true, message: "Shareable link generated", url: $url, file_id: $file_id, type: "shareable", note: "Google Drive links do not expire by default"}'
fi
