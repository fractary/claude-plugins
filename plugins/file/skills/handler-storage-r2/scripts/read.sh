#!/bin/bash
# R2 Storage Handler: Read
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
ACCOUNT_ID="$1"
BUCKET_NAME="$2"
ACCESS_KEY="$3"
SECRET_KEY="$4"
REMOTE_PATH="$5"
MAX_BYTES="${6:-10485760}"  # 10MB default

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

# Get file size first
SIZE=$(aws s3api head-object \
    --bucket "$BUCKET_NAME" \
    --key "$REMOTE_PATH" \
    --endpoint-url "$R2_ENDPOINT" \
    --query ContentLength \
    --output text 2>/dev/null)

if [[ $? -ne 0 ]]; then
    echo "Error: File not found in R2: $REMOTE_PATH" >&2
    exit 10
fi

# Warn if file exceeds limit
if (( SIZE > MAX_BYTES )); then
    echo "[Warning: File size $SIZE bytes exceeds max $MAX_BYTES bytes, truncating]" >&2
fi

# Stream file to stdout, truncate if needed
aws s3 cp "s3://${BUCKET_NAME}/${REMOTE_PATH}" - \
    --endpoint-url "$R2_ENDPOINT" \
    2>/dev/null | head -c "$MAX_BYTES"

# Show truncation message if needed
if (( SIZE > MAX_BYTES )); then
    echo "" >&2
    echo "[Truncated. Full file size: $SIZE bytes. Use --max-bytes=$SIZE or download full file]" >&2
fi
