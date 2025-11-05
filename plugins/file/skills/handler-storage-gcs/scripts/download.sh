#!/bin/bash
# GCS Storage Handler: Download
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
PROJECT_ID="$1"
BUCKET_NAME="$2"
SERVICE_ACCOUNT_KEY="${3:-}"
REGION="${4:-us-central1}"
REMOTE_PATH="$5"
LOCAL_PATH="$6"

# Check gcloud CLI available
if ! command -v gcloud >/dev/null 2>&1; then
    echo "Error: gcloud CLI not found. Install from https://cloud.google.com/sdk/docs/install" >&2
    exit 3
fi

# Set service account key if provided (otherwise use ADC)
if [[ -n "$SERVICE_ACCOUNT_KEY" ]] && [[ -f "$SERVICE_ACCOUNT_KEY" ]]; then
    export GOOGLE_APPLICATION_CREDENTIALS="$SERVICE_ACCOUNT_KEY"
fi

# Create local directory if needed
LOCAL_DIR=$(dirname "$LOCAL_PATH")
mkdir -p "$LOCAL_DIR"

# Download file
if ! gcloud storage cp "gs://${BUCKET_NAME}/${REMOTE_PATH}" "$LOCAL_PATH" \
    --project="$PROJECT_ID" \
    2>&1; then
    echo "Error: Failed to download file from GCS" >&2
    exit 12
fi

# Get file size
if SIZE=$(stat -c%s "$LOCAL_PATH" 2>/dev/null); then
    :
elif SIZE=$(stat -f%z "$LOCAL_PATH" 2>/dev/null); then
    :
else
    SIZE="0"
fi

# Calculate checksum
if command -v sha256sum >/dev/null 2>&1; then
    CHECKSUM=$(sha256sum "$LOCAL_PATH" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
    CHECKSUM=$(shasum -a 256 "$LOCAL_PATH" | awk '{print $1}')
else
    CHECKSUM="unavailable"
fi

# Return JSON result
jq -n \
    --arg path "$LOCAL_PATH" \
    --arg size "$SIZE" \
    --arg checksum "$CHECKSUM" \
    '{success: true, message: "File downloaded from GCS successfully", local_path: $path, size_bytes: ($size | tonumber), checksum: $checksum}'
