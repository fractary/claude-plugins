#!/bin/bash
# Local Storage Handler: Delete
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
BASE_PATH="$1"
REMOTE_PATH="$2"

# Construct target path
TARGET="$BASE_PATH/$REMOTE_PATH"

# Check if file exists
if [[ ! -f "$TARGET" ]]; then
    echo "Error: File not found: $TARGET" >&2
    exit 10
fi

# Delete file
rm "$TARGET"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to delete file" >&2
    exit 1
fi

# Return JSON result
jq -n \
    --arg path "$REMOTE_PATH" \
    '{success: true, message: "File deleted successfully", remote_path: $path}'
