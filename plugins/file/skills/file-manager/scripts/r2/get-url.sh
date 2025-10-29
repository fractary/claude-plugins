#!/bin/bash
# File Manager: R2 Get URL
# Gets a signed or public URL for a file in Cloudflare R2

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <remote_path> [expires_in]" >&2
    exit 2
fi

REMOTE_PATH="$1"
EXPIRES_IN="${2:-3600}"

# Check if aws CLI is available
if ! command -v aws &> /dev/null; then
    echo "Error: aws CLI not found" >&2
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
    echo "Error: R2 configuration incomplete" >&2
    exit 3
fi

# R2 endpoint
R2_ENDPOINT="https://${ACCOUNT_ID}.r2.cloudflarestorage.com"

# Try public URL first if configured
if [ -n "$PUBLIC_URL" ]; then
    # Check if file is publicly accessible
    PUBLIC_FILE_URL="${PUBLIC_URL}/${REMOTE_PATH}"

    # Return public URL
    echo "$PUBLIC_FILE_URL"
    exit 0
fi

# Generate presigned URL
presigned_url=$(aws s3 presign "s3://${BUCKET_NAME}/${REMOTE_PATH}" \
    --endpoint-url "$R2_ENDPOINT" \
    --expires-in "$EXPIRES_IN" \
    2>&1)

if [ $? -ne 0 ]; then
    echo "Error: Failed to generate presigned URL" >&2
    exit 1
fi

echo "$presigned_url"
exit 0
