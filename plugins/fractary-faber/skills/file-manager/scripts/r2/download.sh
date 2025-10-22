#!/bin/bash
# File Manager: R2 Download
# Downloads a file from Cloudflare R2

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <remote_path> <local_path>" >&2
    exit 2
fi

REMOTE_PATH="$1"
LOCAL_PATH="$2"

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

if [ -z "$ACCOUNT_ID" ] || [ -z "$BUCKET_NAME" ]; then
    echo "Error: R2 configuration incomplete" >&2
    exit 3
fi

# R2 endpoint
R2_ENDPOINT="https://${ACCOUNT_ID}.r2.cloudflarestorage.com"

# Create local directory if needed
LOCAL_DIR=$(dirname "$LOCAL_PATH")
mkdir -p "$LOCAL_DIR"

# Download file from R2
aws s3 cp "s3://${BUCKET_NAME}/${REMOTE_PATH}" "$LOCAL_PATH" \
    --endpoint-url "$R2_ENDPOINT" \
    2>&1

if [ $? -ne 0 ]; then
    echo "Error: Failed to download file from R2" >&2
    exit 10
fi

echo "File downloaded to: $LOCAL_PATH"
exit 0
