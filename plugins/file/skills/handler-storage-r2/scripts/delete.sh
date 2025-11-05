#!/bin/bash
# R2 Storage Handler: Delete
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
ACCOUNT_ID="$1"
BUCKET_NAME="$2"
ACCESS_KEY="$3"
SECRET_KEY="$4"
REMOTE_PATH="$5"

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

# Delete file
if ! aws s3 rm "s3://${BUCKET_NAME}/${REMOTE_PATH}" \
    --endpoint-url "$R2_ENDPOINT" \
    2>&1; then
    echo "Error: Failed to delete file from R2" >&2
    exit 12
fi

# Return JSON result
jq -n \
    --arg path "$REMOTE_PATH" \
    '{success: true, message: "File deleted from R2 successfully", remote_path: $path}'
