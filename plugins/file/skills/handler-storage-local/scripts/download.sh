#!/bin/bash
# Local Storage Handler: Download
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
BASE_PATH="$1"
REMOTE_PATH="$2"
LOCAL_PATH="$3"
CREATE_DIRS="${4:-true}"

# Construct source path
SOURCE="$BASE_PATH/$REMOTE_PATH"

# Validate source file exists
if [[ ! -f "$SOURCE" ]]; then
    echo "Error: Remote file not found: $SOURCE" >&2
    exit 10
fi

# Create local directory if needed
if [[ "$CREATE_DIRS" == "true" ]]; then
    LOCAL_DIR=$(dirname "$LOCAL_PATH")
    mkdir -p "$LOCAL_DIR"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to create directory: $LOCAL_DIR" >&2
        exit 1
    fi
fi

# Copy file
cp "$SOURCE" "$LOCAL_PATH"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to copy file" >&2
    exit 1
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
    '{success: true, message: "File downloaded successfully", local_path: $path, size_bytes: ($size | tonumber), checksum: $checksum}'
