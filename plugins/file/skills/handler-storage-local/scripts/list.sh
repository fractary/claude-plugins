#!/bin/bash
# Local Storage Handler: List
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
BASE_PATH="$1"
PREFIX="${2:-}"
MAX_RESULTS="${3:-100}"

# Construct search path
SEARCH_PATH="$BASE_PATH"
if [[ -n "$PREFIX" ]]; then
    SEARCH_PATH="$BASE_PATH/$PREFIX"
fi

# Check if path exists
if [[ ! -d "$SEARCH_PATH" ]]; then
    # Return empty array if directory doesn't exist
    echo '{"success": true, "message": "Directory not found", "files": []}'
    exit 0
fi

# Find files (not directories)
FILES=()
while IFS= read -r -d '' file; do
    # Get relative path from base
    REL_PATH="${file#$BASE_PATH/}"

    # Get file size
    if SIZE=$(stat -c%s "$file" 2>/dev/null); then
        :
    elif SIZE=$(stat -f%z "$file" 2>/dev/null); then
        :
    else
        SIZE="0"
    fi

    # Get modification time
    if MTIME=$(stat -c%Y "$file" 2>/dev/null); then
        :
    elif MTIME=$(stat -f%m "$file" 2>/dev/null); then
        :
    else
        MTIME="0"
    fi

    # Add to array
    FILES+=("{\"path\": \"$REL_PATH\", \"size_bytes\": $SIZE, \"modified_at\": $MTIME}")

    # Stop if we've reached max results
    if [[ ${#FILES[@]} -ge $MAX_RESULTS ]]; then
        break
    fi
done < <(find "$SEARCH_PATH" -type f -print0 2>/dev/null | head -z -n "$MAX_RESULTS")

# Build JSON array
if [[ ${#FILES[@]} -eq 0 ]]; then
    echo '{"success": true, "message": "No files found", "files": []}'
else
    # Join array elements with commas
    FILES_JSON=$(IFS=,; echo "${FILES[*]}")
    echo "{\"success\": true, \"message\": \"Found ${#FILES[@]} files\", \"files\": [$FILES_JSON]}"
fi
