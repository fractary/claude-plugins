#!/bin/bash
# classify-by-path.sh - Classify doc_type by file path
# Usage: classify-by-path.sh <file_path>

set -euo pipefail

FILE_PATH="$1"

# Extract doc_type from path pattern: docs/{doc_type}/...
if [[ "$FILE_PATH" =~ docs/([^/]+)/ ]]; then
    DOC_TYPE="${BASH_REMATCH[1]}"
    echo "{\"doc_type\": \"$DOC_TYPE\", \"confidence\": 100, \"method\": \"path\"}"
    exit 0
fi

# No match
echo "{\"doc_type\": \"_untyped\", \"confidence\": 0, \"method\": \"none\"}"
exit 1
