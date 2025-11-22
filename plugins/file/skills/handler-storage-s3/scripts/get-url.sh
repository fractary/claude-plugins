#!/bin/bash
# S3 Storage Handler: Get URL
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
REGION="$1"
BUCKET_NAME="$2"
ACCESS_KEY="${3:-}"
SECRET_KEY="${4:-}"
ENDPOINT="${5:-}"
REMOTE_PATH="$6"
EXPIRES_IN="${7:-3600}"
PUBLIC_URL="${8:-}"

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

# Try to get object metadata to verify it exists
if ! eval aws s3api head-object \
    --bucket \"$BUCKET_NAME\" \
    --key \"$REMOTE_PATH\" \
    $ENDPOINT_ARG \
    >/dev/null 2>&1; then
    echo "Error: File not found in S3: $REMOTE_PATH" >&2
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
    URL=$(eval aws s3 presign \"s3://${BUCKET_NAME}/${REMOTE_PATH}\" \
        $ENDPOINT_ARG \
        --expires-in \"$EXPIRES_IN\" \
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
