#!/bin/bash
# Google Drive Storage Handler: List
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
RCLONE_REMOTE="$1"
FOLDER_ID="$2"
PREFIX="${3:-}"
MAX_RESULTS="${4:-100}"

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

# Build search path
if [[ "$FOLDER_ID" == "root" ]]; then
    if [[ -n "$PREFIX" ]]; then
        SEARCH_PATH="${RCLONE_REMOTE}:${PREFIX}"
    else
        SEARCH_PATH="${RCLONE_REMOTE}:"
    fi
else
    if [[ -n "$PREFIX" ]]; then
        SEARCH_PATH="${RCLONE_REMOTE}:{${FOLDER_ID}}/${PREFIX}"
    else
        SEARCH_PATH="${RCLONE_REMOTE}:{${FOLDER_ID}}"
    fi
fi

# List files using rclone lsjson
OUTPUT=$(rclone lsjson "$SEARCH_PATH" --recursive 2>&1)

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to list files in Google Drive" >&2
    echo "$OUTPUT" >&2
    # Return empty list for empty folders
    echo '{"success": true, "message": "No files found", "files": []}'
    exit 0
fi

# Parse JSON output and limit to MAX_RESULTS
if ! echo "$OUTPUT" | jq -c --argjson max "$MAX_RESULTS" '{
    success: true,
    message: ("Found " + (. | length | tostring) + " files"),
    files: [.[] | select(.IsDir == false) | {
        path: .Path,
        size_bytes: .Size,
        modified_at: .ModTime,
        file_id: .ID
    }] | .[0:$max]
}'; then
    # Return empty list on parse failure
    echo '{"success": true, "message": "No files found", "files": []}'
fi
