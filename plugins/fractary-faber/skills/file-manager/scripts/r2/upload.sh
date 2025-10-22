#!/bin/bash
# File Manager: R2 Upload
# Uploads a file to Cloudflare R2

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <local_path> <remote_path> [public]" >&2
    exit 2
fi

LOCAL_PATH="$1"
REMOTE_PATH="$2"
PUBLIC="${3:-false}"

# Check if local file exists
if [ ! -f "$LOCAL_PATH" ]; then
    echo "Error: Local file not found: $LOCAL_PATH" >&2
    exit 10
fi

# Check if aws CLI is available
if ! command -v aws &> /dev/null; then
    echo "Error: aws CLI not found. Install it from https://aws.amazon.com/cli/" >&2
    exit 3
fi

# Get R2 configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JSON=$("$SCRIPT_DIR/../../../faber-core/scripts/config-loader.sh")

if [ $? -ne 0 ]; then
    echo "Error: Failed to load configuration" >&2
    exit 3
fi

ACCOUNT_ID=$(echo "$CONFIG_JSON" | jq -r '.systems.file_config.account_id // empty')
BUCKET_NAME=$(echo "$CONFIG_JSON" | jq -r '.systems.file_config.bucket_name // empty')
PUBLIC_URL=$(echo "$CONFIG_JSON" | jq -r '.systems.file_config.public_url // empty')

if [ -z "$ACCOUNT_ID" ] || [ -z "$BUCKET_NAME" ]; then
    echo "Error: R2 configuration incomplete (account_id, bucket_name required)" >&2
    exit 3
fi

# R2 endpoint
R2_ENDPOINT="https://${ACCOUNT_ID}.r2.cloudflarestorage.com"

# Upload file to R2
if [ "$PUBLIC" = "true" ]; then
    # Upload with public-read ACL
    aws s3 cp "$LOCAL_PATH" "s3://${BUCKET_NAME}/${REMOTE_PATH}" \
        --endpoint-url "$R2_ENDPOINT" \
        --acl public-read \
        2>&1
else
    # Upload as private
    aws s3 cp "$LOCAL_PATH" "s3://${BUCKET_NAME}/${REMOTE_PATH}" \
        --endpoint-url "$R2_ENDPOINT" \
        2>&1
fi

if [ $? -ne 0 ]; then
    echo "Error: Failed to upload file to R2" >&2
    exit 12
fi

# Output URL or path
if [ "$PUBLIC" = "true" ] && [ -n "$PUBLIC_URL" ]; then
    echo "${PUBLIC_URL}/${REMOTE_PATH}"
else
    echo "s3://${BUCKET_NAME}/${REMOTE_PATH}"
fi

exit 0
