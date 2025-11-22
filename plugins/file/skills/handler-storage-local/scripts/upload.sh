#!/bin/bash
# Local Storage Handler: Upload
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
BASE_PATH="$1"
LOCAL_PATH="$2"
REMOTE_PATH="$3"
CREATE_DIRS="${4:-true}"

# Validate local file exists
if [[ ! -f "$LOCAL_PATH" ]]; then
    echo "Error: Local file not found: $LOCAL_PATH" >&2
    exit 10
fi

# Construct target path
TARGET="$BASE_PATH/$REMOTE_PATH"

# Create target directory if needed
if [[ "$CREATE_DIRS" == "true" ]]; then
    TARGET_DIR=$(dirname "$TARGET")
    mkdir -p "$TARGET_DIR"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to create directory: $TARGET_DIR" >&2
        exit 1
    fi
fi

# Copy file
cp "$LOCAL_PATH" "$TARGET"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to copy file" >&2
    exit 1
fi

# Get absolute path
ABS_PATH=$(realpath "$TARGET")

# Calculate metadata
# Try GNU stat (Linux)
if SIZE=$(stat -c%s "$TARGET" 2>/dev/null); then
    :
elif SIZE=$(stat -f%z "$TARGET" 2>/dev/null); then
    # BSD stat (macOS)
    :
else
    echo "Error: Cannot determine file size" >&2
    exit 1
fi

# Calculate checksum
if command -v sha256sum >/dev/null 2>&1; then
    CHECKSUM=$(sha256sum "$TARGET" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
    CHECKSUM=$(shasum -a 256 "$TARGET" | awk '{print $1}')
else
    CHECKSUM="unavailable"
fi

# Generate file:// URL
URL="file://$ABS_PATH"

# Return JSON result
jq -n \
    --arg url "$URL" \
    --arg size "$SIZE" \
    --arg checksum "$CHECKSUM" \
    --arg path "$ABS_PATH" \
    '{success: true, message: "File uploaded successfully", url: $url, size_bytes: ($size | tonumber), checksum: $checksum, local_path: $path}'
