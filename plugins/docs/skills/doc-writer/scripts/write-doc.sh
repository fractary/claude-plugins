#!/bin/bash
# write-doc.sh - Write document file with frontmatter injection
# Usage: write-doc.sh <file_path> <content> <frontmatter_json>

set -euo pipefail

FILE_PATH="$1"
CONTENT="$2"
FRONTMATTER_JSON="${3:-{}}"

# Create directory if it doesn't exist
DIR=$(dirname "$FILE_PATH")
mkdir -p "$DIR"

# Generate frontmatter from JSON
FRONTMATTER=$(echo "$FRONTMATTER_JSON" | jq -r '
  "---\n" +
  (to_entries | map("\(.key): \(.value | @json)") | join("\n")) +
  "\n---"
')

# Combine frontmatter and content
FULL_CONTENT="${FRONTMATTER}\n\n${CONTENT}"

# Write to file
echo -e "$FULL_CONTENT" > "$FILE_PATH"

# Set appropriate permissions
chmod 644 "$FILE_PATH"

echo "✓ Written: $FILE_PATH"
