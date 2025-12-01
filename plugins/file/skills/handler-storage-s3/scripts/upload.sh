#!/bin/bash
# S3 Storage Handler: Upload
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
REGION="$1"
BUCKET_NAME="$2"
ACCESS_KEY="${3:-}"
SECRET_KEY="${4:-}"
ENDPOINT="${5:-}"
LOCAL_PATH="$6"
REMOTE_PATH="$7"
PUBLIC="${8:-false}"

# Validate local file exists
if [[ ! -f "$LOCAL_PATH" ]]; then
    echo "Error: Local file not found: $LOCAL_PATH" >&2
    exit 10
fi

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

# Determine ACL
ACL_FLAG=""
if [[ "$PUBLIC" == "true" ]]; then
    ACL_FLAG="--acl public-read"
fi

# Upload file
if ! eval aws s3 cp \"$LOCAL_PATH\" \"s3://${BUCKET_NAME}/${REMOTE_PATH}\" \
    $ENDPOINT_ARG \
    $ACL_FLAG \
    2>&1; then
    echo "Error: Failed to upload file to S3" >&2
    exit 12
fi

# Calculate metadata
if SIZE=$(stat -c%s "$LOCAL_PATH" 2>/dev/null); then
    :
elif SIZE=$(stat -f%z "$LOCAL_PATH" 2>/dev/null); then
    :
else
    SIZE="0"
fi

if command -v sha256sum >/dev/null 2>&1; then
    CHECKSUM=$(sha256sum "$LOCAL_PATH" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
    CHECKSUM=$(shasum -a 256 "$LOCAL_PATH" | awk '{print $1}')
else
    CHECKSUM="unavailable"
fi

# Generate URL
if [[ "$PUBLIC" == "true" ]]; then
    if [[ -n "$ENDPOINT" ]]; then
        URL="${ENDPOINT}/${REMOTE_PATH}"
    else
        URL="https://${BUCKET_NAME}.s3.${REGION}.amazonaws.com/${REMOTE_PATH}"
    fi
else
    # Presigned URL (24 hours)
    URL=$(eval aws s3 presign \"s3://${BUCKET_NAME}/${REMOTE_PATH}\" \
        $ENDPOINT_ARG \
        --expires-in 86400 2>/dev/null || echo "s3://${BUCKET_NAME}/${REMOTE_PATH}")
fi

# Return JSON result
jq -n \
    --arg url "$URL" \
    --arg size "$SIZE" \
    --arg checksum "$CHECKSUM" \
    '{success: true, message: "File uploaded to S3 successfully", url: $url, size_bytes: ($size | tonumber), checksum: $checksum}'
