#!/bin/bash
# Google Drive Storage Handler: Upload
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
RCLONE_REMOTE="$1"
FOLDER_ID="$2"
LOCAL_PATH="$3"
REMOTE_PATH="$4"

# Validate local file exists
if [[ ! -f "$LOCAL_PATH" ]]; then
    echo "Error: Local file not found: $LOCAL_PATH" >&2
    exit 10
fi

# Check rclone is available
if ! command -v rclone >/dev/null 2>&1; then
    echo "Error: rclone not found. Install from https://rclone.org/install/" >&2
    exit 3
fi

# Check rclone remote is configured
if ! rclone listremotes | grep -q "^${RCLONE_REMOTE}:"; then
    echo "Error: rclone remote '$RCLONE_REMOTE' not configured" >&2
    echo "  Run: rclone config" >&2
    echo "  See: plugins/file/skills/handler-storage-gdrive/docs/oauth-setup-guide.md" >&2
    exit 3
fi

# Build target path
if [[ "$FOLDER_ID" == "root" ]]; then
    TARGET="${RCLONE_REMOTE}:${REMOTE_PATH}"
else
    TARGET="${RCLONE_REMOTE}:{${FOLDER_ID}}/${REMOTE_PATH}"
fi

# Upload file
if ! rclone copy "$LOCAL_PATH" "$(dirname "$TARGET")" \
    --progress \
    2>&1 | grep -v "^Transferred:" || true; then
    echo "Error: Failed to upload file to Google Drive" >&2
    exit 12
fi

# Calculate metadata
if SIZE=$(stat -c%s "$LOCAL_PATH" 2>/dev/null); then
    :
elif SIZE=$(stat -f%z "$LOCAL_PATH" 2>/dev/null); then
    :
else
    SIZE="0"
fi

if command -v sha256sum >/dev/null 2>&1; then
    CHECKSUM=$(sha256sum "$LOCAL_PATH" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
    CHECKSUM=$(shasum -a 256 "$LOCAL_PATH" | awk '{print $1}')
else
    CHECKSUM="unavailable"
fi

# Try to get Drive file ID and generate link
FILE_ID=$(rclone lsjson "$TARGET" 2>/dev/null | jq -r '.[0].ID // empty' || echo "")

if [[ -n "$FILE_ID" ]]; then
    URL="https://drive.google.com/file/d/${FILE_ID}/view"
else
    URL="gdrive:${REMOTE_PATH}"
fi

# Return JSON result
jq -n \
    --arg url "$URL" \
    --arg size "$SIZE" \
    --arg checksum "$CHECKSUM" \
    --arg file_id "$FILE_ID" \
    '{success: true, message: "File uploaded to Google Drive successfully", url: $url, size_bytes: ($size | tonumber), checksum: $checksum, file_id: $file_id}'
