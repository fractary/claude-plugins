#!/bin/bash
# R2 Storage Handler: Download
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
ACCOUNT_ID="$1"
BUCKET_NAME="$2"
ACCESS_KEY="$3"
SECRET_KEY="$4"
REMOTE_PATH="$5"
LOCAL_PATH="$6"

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

# Create local directory if needed
LOCAL_DIR=$(dirname "$LOCAL_PATH")
mkdir -p "$LOCAL_DIR"

# Download file
if ! aws s3 cp "s3://${BUCKET_NAME}/${REMOTE_PATH}" "$LOCAL_PATH" \
    --endpoint-url "$R2_ENDPOINT" \
    2>&1; then
    echo "Error: Failed to download file from R2" >&2
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
    '{success: true, message: "File downloaded from R2 successfully", local_path: $path, size_bytes: ($size | tonumber), checksum: $checksum}'
