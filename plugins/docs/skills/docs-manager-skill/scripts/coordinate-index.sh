#!/bin/bash
# coordinate-index.sh - Update documentation index for a directory
# Usage: coordinate-index.sh <directory> <doc_type> [title]

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"

# Shared scripts
INDEX_UPDATER="$PLUGIN_ROOT/skills/_shared/lib/index-updater.sh"

# Parse arguments
DIRECTORY="$1"
DOC_TYPE="$2"
TITLE="${3:-${DOC_TYPE^} Documentation}"

echo "🎯 Coordinating index update..."
echo "   Directory: $DIRECTORY"
echo "   Doc Type: $DOC_TYPE"
echo "   Title: $TITLE"
echo ""

# Step 1: Verify directory exists
if [[ ! -d "$DIRECTORY" ]]; then
    echo "ERROR: Directory not found: $DIRECTORY" >&2
    exit 1
fi

# Step 2: Verify index updater script exists
if [[ ! -f "$INDEX_UPDATER" ]]; then
    echo "ERROR: Index updater not found: $INDEX_UPDATER" >&2
    exit 1
fi

# Step 3: Run index updater
echo "Step 1/2: Running index updater..."
echo ""

if bash "$INDEX_UPDATER" "$DIRECTORY" "$DOC_TYPE" "$TITLE"; then
    echo ""
    echo "✅ Index update completed successfully"

    # Determine index file path
    INDEX_FILE="$DIRECTORY/README.md"

    # Return success JSON
    cat <<EOF
{
  "status": "success",
  "operation": "index",
  "directory": "$DIRECTORY",
  "doc_type": "$DOC_TYPE",
  "index_file": "$INDEX_FILE"
}
EOF
    exit 0
else
    echo ""
    echo "❌ Index update failed" >&2

    # Return error JSON
    cat <<EOF
{
  "status": "error",
  "operation": "index",
  "directory": "$DIRECTORY",
  "doc_type": "$DOC_TYPE",
  "error": "Index updater script failed"
}
EOF
    exit 1
fi
