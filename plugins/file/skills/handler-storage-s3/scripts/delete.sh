#!/bin/bash
# S3 Storage Handler: Delete
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
REGION="$1"
BUCKET_NAME="$2"
ACCESS_KEY="${3:-}"
SECRET_KEY="${4:-}"
ENDPOINT="${5:-}"
REMOTE_PATH="$6"

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

# Delete file
if ! eval aws s3 rm \"s3://${BUCKET_NAME}/${REMOTE_PATH}\" \
    $ENDPOINT_ARG \
    2>&1; then
    echo "Error: Failed to delete file from S3" >&2
    exit 12
fi

# Return JSON result
jq -n \
    --arg path "$REMOTE_PATH" \
    '{success: true, message: "File deleted from S3 successfully", remote_path: $path}'
