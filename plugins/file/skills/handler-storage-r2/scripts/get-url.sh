#!/bin/bash
# R2 Storage Handler: Get URL
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
ACCOUNT_ID="$1"
BUCKET_NAME="$2"
ACCESS_KEY="$3"
SECRET_KEY="$4"
REMOTE_PATH="$5"
EXPIRES_IN="${6:-3600}"
PUBLIC_URL="${7:-}"

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

# Try to get object metadata to verify it exists
if ! aws s3api head-object \
    --bucket "$BUCKET_NAME" \
    --key "$REMOTE_PATH" \
    --endpoint-url "$R2_ENDPOINT" \
    >/dev/null 2>&1; then
    echo "Error: File not found in R2: $REMOTE_PATH" >&2
    exit 10
fi

# Generate URL
if [[ -n "$PUBLIC_URL" ]]; then
    # Public URL
    URL="${PUBLIC_URL}/${REMOTE_PATH}"
    jq -n \
        --arg url "$URL" \
        '{success: true, message: "Public URL generated", url: $url, type: "public"}'
else
    # Presigned URL
    URL=$(aws s3 presign "s3://${BUCKET_NAME}/${REMOTE_PATH}" \
        --endpoint-url "$R2_ENDPOINT" \
        --expires-in "$EXPIRES_IN" \
        2>&1)

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to generate presigned URL" >&2
        exit 12
    fi

    jq -n \
        --arg url "$URL" \
        --arg expires "$EXPIRES_IN" \
        '{success: true, message: "Presigned URL generated", url: $url, expires_in: ($expires | tonumber), type: "presigned"}'
fi
