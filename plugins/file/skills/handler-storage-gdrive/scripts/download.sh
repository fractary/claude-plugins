#!/bin/bash
# Google Drive Storage Handler: Download
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
RCLONE_REMOTE="$1"
FOLDER_ID="$2"
REMOTE_PATH="$3"
LOCAL_PATH="$4"

# Check rclone is available
if ! command -v rclone >/dev/null 2>&1; then
    echo "Error: rclone not found. Install from https://rclone.org/install/" >&2
    exit 3
fi

# Check rclone remote is configured
if ! rclone listremotes | grep -q "^${RCLONE_REMOTE}:"; then
    echo "Error: rclone remote '$RCLONE_REMOTE' not configured" >&2
    echo "  Run: rclone config" >&2
    exit 3
fi

# Build source path
if [[ "$FOLDER_ID" == "root" ]]; then
    SOURCE="${RCLONE_REMOTE}:${REMOTE_PATH}"
else
    SOURCE="${RCLONE_REMOTE}:{${FOLDER_ID}}/${REMOTE_PATH}"
fi

# Create local directory if needed
LOCAL_DIR=$(dirname "$LOCAL_PATH")
mkdir -p "$LOCAL_DIR"

# Download file
if ! rclone copy "$SOURCE" "$LOCAL_DIR" \
    --progress \
    2>&1 | grep -v "^Transferred:" || true; then
    echo "Error: Failed to download file from Google Drive" >&2
    exit 12
fi

# Get file size
if SIZE=$(stat -c%s "$LOCAL_PATH" 2>/dev/null); then
    :
elif SIZE=$(stat -f%z "$LOCAL_PATH" 2>/dev/null); then
    :
else
    SIZE="0"
fi

# Calculate checksum
if command -v sha256sum >/dev/null 2>&1; then
    CHECKSUM=$(sha256sum "$LOCAL_PATH" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
    CHECKSUM=$(shasum -a 256 "$LOCAL_PATH" | awk '{print $1}')
else
    CHECKSUM="unavailable"
fi

# Return JSON result
jq -n \
    --arg path "$LOCAL_PATH" \
    --arg size "$SIZE" \
    --arg checksum "$CHECKSUM" \
    '{success: true, message: "File downloaded from Google Drive successfully", local_path: $path, size_bytes: ($size | tonumber), checksum: $checksum}'
