#!/bin/bash
# S3 Storage Handler: List
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
REGION="$1"
BUCKET_NAME="$2"
ACCESS_KEY="${3:-}"
SECRET_KEY="${4:-}"
ENDPOINT="${5:-}"
PREFIX="${6:-}"
MAX_RESULTS="${7:-100}"

# Check AWS CLI available
if ! command -v aws >/dev/null 2>&1; then
    echo "Error: aws CLI not found. Install from https://aws.amazon.com/cli/" >&2
    exit 3
fi

# Set credentials if provided (otherwise use IAM role)
if [[ -n "$ACCESS_KEY" ]] && [[ -n "$SECRET_KEY" ]]; then
    export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
fi
export AWS_DEFAULT_REGION="$REGION"

# Build endpoint argument
ENDPOINT_ARG=""
if [[ -n "$ENDPOINT" ]]; then
    ENDPOINT_ARG="--endpoint-url $ENDPOINT"
fi

# Build prefix argument
PREFIX_ARG=""
if [[ -n "$PREFIX" ]]; then
    PREFIX_ARG="--prefix $PREFIX"
fi

# List files
OUTPUT=$(eval aws s3api list-objects-v2 \
    --bucket \"$BUCKET_NAME\" \
    $ENDPOINT_ARG \
    $PREFIX_ARG \
    --max-items \"$MAX_RESULTS\" \
    2>&1)

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to list files in S3" >&2
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
