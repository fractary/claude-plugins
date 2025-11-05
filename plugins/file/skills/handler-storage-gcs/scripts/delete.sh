#!/bin/bash
# GCS Storage Handler: Delete
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
PROJECT_ID="$1"
BUCKET_NAME="$2"
SERVICE_ACCOUNT_KEY="${3:-}"
REGION="${4:-us-central1}"
REMOTE_PATH="$5"

# Check gcloud CLI available
if ! command -v gcloud >/dev/null 2>&1; then
    echo "Error: gcloud CLI not found. Install from https://cloud.google.com/sdk/docs/install" >&2
    exit 3
fi

# Set service account key if provided (otherwise use ADC)
if [[ -n "$SERVICE_ACCOUNT_KEY" ]] && [[ -f "$SERVICE_ACCOUNT_KEY" ]]; then
    export GOOGLE_APPLICATION_CREDENTIALS="$SERVICE_ACCOUNT_KEY"
fi

# Delete file
if ! gcloud storage rm "gs://${BUCKET_NAME}/${REMOTE_PATH}" \
    --project="$PROJECT_ID" \
    2>&1; then
    echo "Error: Failed to delete file from GCS" >&2
    exit 12
fi

# Return JSON result
jq -n \
    --arg path "$REMOTE_PATH" \
    '{success: true, message: "File deleted from GCS successfully", remote_path: $path}'
