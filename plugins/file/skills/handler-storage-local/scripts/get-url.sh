#!/bin/bash
# Local Storage Handler: Get URL
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
BASE_PATH="$1"
REMOTE_PATH="$2"
# EXPIRES_IN is ignored for local filesystem (no expiration)

# Construct target path
TARGET="$BASE_PATH/$REMOTE_PATH"

# Check if file exists
if [[ ! -f "$TARGET" ]]; then
    echo "Error: File not found: $TARGET" >&2
    exit 10
fi

# Get absolute path
ABS_PATH=$(realpath "$TARGET")

# Generate file:// URL
URL="file://$ABS_PATH"

# Return JSON result
jq -n \
    --arg url "$URL" \
    --arg path "$ABS_PATH" \
    '{success: true, message: "URL generated successfully", url: $url, local_path: $path, note: "file:// URLs do not expire"}'
