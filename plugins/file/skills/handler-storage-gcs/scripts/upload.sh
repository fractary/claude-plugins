#!/bin/bash
# GCS Storage Handler: Upload
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
PROJECT_ID="$1"
BUCKET_NAME="$2"
SERVICE_ACCOUNT_KEY="${3:-}"
REGION="${4:-us-central1}"
LOCAL_PATH="$5"
REMOTE_PATH="$6"
PUBLIC="${7:-false}"

# Validate local file exists
if [[ ! -f "$LOCAL_PATH" ]]; then
    echo "Error: Local file not found: $LOCAL_PATH" >&2
    exit 10
fi

# Check gcloud CLI available
if ! command -v gcloud >/dev/null 2>&1; then
    echo "Error: gcloud CLI not found. Install from https://cloud.google.com/sdk/docs/install" >&2
    exit 3
fi

# Set service account key if provided (otherwise use ADC)
if [[ -n "$SERVICE_ACCOUNT_KEY" ]] && [[ -f "$SERVICE_ACCOUNT_KEY" ]]; then
    export GOOGLE_APPLICATION_CREDENTIALS="$SERVICE_ACCOUNT_KEY"
fi

# Upload file
if ! gcloud storage cp "$LOCAL_PATH" "gs://${BUCKET_NAME}/${REMOTE_PATH}" \
    --project="$PROJECT_ID" \
    2>&1; then
    echo "Error: Failed to upload file to GCS" >&2
    exit 12
fi

# Make public if requested
if [[ "$PUBLIC" == "true" ]]; then
    if command -v gsutil >/dev/null 2>&1; then
        gsutil acl ch -u AllUsers:R "gs://${BUCKET_NAME}/${REMOTE_PATH}" 2>&1 || true
    fi
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
    URL="https://storage.googleapis.com/${BUCKET_NAME}/${REMOTE_PATH}"
else
    # For signed URL, we need gsutil
    if command -v gsutil >/dev/null 2>&1 && [[ -n "$SERVICE_ACCOUNT_KEY" ]]; then
        URL=$(gsutil signurl -d 24h "$SERVICE_ACCOUNT_KEY" "gs://${BUCKET_NAME}/${REMOTE_PATH}" 2>/dev/null | tail -n1 | awk '{print $NF}' || echo "gs://${BUCKET_NAME}/${REMOTE_PATH}")
    else
        URL="gs://${BUCKET_NAME}/${REMOTE_PATH}"
    fi
fi

# Return JSON result
jq -n \
    --arg url "$URL" \
    --arg size "$SIZE" \
    --arg checksum "$CHECKSUM" \
    '{success: true, message: "File uploaded to GCS successfully", url: $url, size_bytes: ($size | tonumber), checksum: $checksum}'
