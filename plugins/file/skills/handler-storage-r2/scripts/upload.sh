#!/bin/bash
# R2 Storage Handler: Upload
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
ACCOUNT_ID="$1"
BUCKET_NAME="$2"
ACCESS_KEY="$3"
SECRET_KEY="$4"
LOCAL_PATH="$5"
REMOTE_PATH="$6"
PUBLIC="${7:-false}"
PUBLIC_URL="${8:-}"

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

# Set R2 endpoint
R2_ENDPOINT="https://${ACCOUNT_ID}.r2.cloudflarestorage.com"

# Set credentials
export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
export AWS_DEFAULT_REGION="auto"

# Determine ACL
ACL_FLAG=""
if [[ "$PUBLIC" == "true" ]]; then
    ACL_FLAG="--acl public-read"
fi

# Upload file
if ! aws s3 cp "$LOCAL_PATH" "s3://${BUCKET_NAME}/${REMOTE_PATH}" \
    --endpoint-url "$R2_ENDPOINT" \
    $ACL_FLAG \
    2>&1; then
    echo "Error: Failed to upload file to R2" >&2
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
if [[ "$PUBLIC" == "true" ]] && [[ -n "$PUBLIC_URL" ]]; then
    URL="${PUBLIC_URL}/${REMOTE_PATH}"
else
    # Presigned URL (24 hours)
    URL=$(aws s3 presign "s3://${BUCKET_NAME}/${REMOTE_PATH}" \
        --endpoint-url "$R2_ENDPOINT" \
        --expires-in 86400 2>/dev/null || echo "s3://${BUCKET_NAME}/${REMOTE_PATH}")
fi

# Return JSON result
jq -n \
    --arg url "$URL" \
    --arg size "$SIZE" \
    --arg checksum "$CHECKSUM" \
    '{success: true, message: "File uploaded to R2 successfully", url: $url, size_bytes: ($size | tonumber), checksum: $checksum}'
