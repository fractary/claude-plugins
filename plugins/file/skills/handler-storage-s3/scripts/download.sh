#!/bin/bash
# S3 Storage Handler: Download
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
REGION="$1"
BUCKET_NAME="$2"
ACCESS_KEY="${3:-}"
SECRET_KEY="${4:-}"
ENDPOINT="${5:-}"
REMOTE_PATH="$6"
LOCAL_PATH="$7"

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

# Create local directory if needed
LOCAL_DIR=$(dirname "$LOCAL_PATH")
mkdir -p "$LOCAL_DIR"

# Download file
if ! eval aws s3 cp \"s3://${BUCKET_NAME}/${REMOTE_PATH}\" \"$LOCAL_PATH\" \
    $ENDPOINT_ARG \
    2>&1; then
    echo "Error: Failed to download file from S3" >&2
    exit 12
fi

# Get file size
if SIZE=$(stat -c%s "$LOCAL_PATH" 2>/dev/null); then
    :
elif SIZE=$(stat -f%z "$LOCAL_PATH" 2>/dev/null); then
    :
else
    SIZE="0"
fi

# Calculate checksum
if command -v sha256sum >/dev/null 2>&1; then
    CHECKSUM=$(sha256sum "$LOCAL_PATH" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
    CHECKSUM=$(shasum -a 256 "$LOCAL_PATH" | awk '{print $1}')
else
    CHECKSUM="unavailable"
fi

# Return JSON result
jq -n \
    --arg path "$LOCAL_PATH" \
    --arg size "$SIZE" \
    --arg checksum "$CHECKSUM" \
    '{success: true, message: "File downloaded from S3 successfully", local_path: $path, size_bytes: ($size | tonumber), checksum: $checksum}'
