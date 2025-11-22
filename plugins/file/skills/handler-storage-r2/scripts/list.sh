#!/bin/bash
# R2 Storage Handler: List
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
ACCOUNT_ID="$1"
BUCKET_NAME="$2"
ACCESS_KEY="$3"
SECRET_KEY="$4"
PREFIX="${5:-}"
MAX_RESULTS="${6:-100}"

# Check AWS CLI available
if ! command -v aws >/dev/null 2>&1; then
    echo "Error: aws CLI not found. Install from https://aws.amazon.com/cli/" >&2
    exit 3
fi

# Set R2 endpoint
R2_ENDPOINT="https://${ACCOUNT_ID}.r2.cloudflarestorage.com"

# Set credentials
export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
export AWS_DEFAULT_REGION="auto"

# Build prefix argument
PREFIX_ARG=""
if [[ -n "$PREFIX" ]]; then
    PREFIX_ARG="--prefix $PREFIX"
fi

# List files
OUTPUT=$(aws s3api list-objects-v2 \
    --bucket "$BUCKET_NAME" \
    --endpoint-url "$R2_ENDPOINT" \
    $PREFIX_ARG \
    --max-items "$MAX_RESULTS" \
    2>&1)

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to list files in R2" >&2
    echo "$OUTPUT" >&2
    exit 12
fi

# Parse output to simplified format
if ! echo "$OUTPUT" | jq -c '{
    success: true,
    message: "Files listed successfully",
    files: [.Contents[]? | {
        path: .Key,
        size_bytes: .Size,
        modified_at: .LastModified,
        etag: .ETag
    }]
}'; then
    # Handle case with no files
    echo '{"success": true, "message": "No files found", "files": []}'
fi
