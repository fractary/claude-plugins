#!/bin/bash
# GCS Storage Handler: Get URL
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
PROJECT_ID="$1"
BUCKET_NAME="$2"
SERVICE_ACCOUNT_KEY="${3:-}"
REGION="${4:-us-central1}"
REMOTE_PATH="$5"
EXPIRES_IN="${6:-3600}"

# Check gcloud/gsutil CLI available
if ! command -v gcloud >/dev/null 2>&1; then
    echo "Error: gcloud CLI not found. Install from https://cloud.google.com/sdk/docs/install" >&2
    exit 3
fi

# Set service account key if provided (otherwise use ADC)
if [[ -n "$SERVICE_ACCOUNT_KEY" ]] && [[ -f "$SERVICE_ACCOUNT_KEY" ]]; then
    export GOOGLE_APPLICATION_CREDENTIALS="$SERVICE_ACCOUNT_KEY"
fi

# Check if file exists
if ! gcloud storage ls "gs://${BUCKET_NAME}/${REMOTE_PATH}" \
    --project="$PROJECT_ID" \
    >/dev/null 2>&1; then
    echo "Error: File not found in GCS: $REMOTE_PATH" >&2
    exit 10
fi

# Generate signed URL (requires gsutil and service account key)
if command -v gsutil >/dev/null 2>&1 && [[ -n "$SERVICE_ACCOUNT_KEY" ]] && [[ -f "$SERVICE_ACCOUNT_KEY" ]]; then
    # Convert expires_in (seconds) to duration format for gsutil
    DURATION="${EXPIRES_IN}s"

    URL=$(gsutil signurl -d "$DURATION" "$SERVICE_ACCOUNT_KEY" "gs://${BUCKET_NAME}/${REMOTE_PATH}" 2>/dev/null | tail -n1 | awk '{print $NF}')

    if [[ $? -eq 0 ]] && [[ -n "$URL" ]]; then
        jq -n \
            --arg url "$URL" \
            --arg expires "$EXPIRES_IN" \
            '{success: true, message: "Signed URL generated", url: $url, expires_in: ($expires | tonumber), type: "signed"}'
    else
        echo "Error: Failed to generate signed URL" >&2
        exit 12
    fi
else
    # Fallback to gs:// URL if can't generate signed URL
    URL="gs://${BUCKET_NAME}/${REMOTE_PATH}"
    jq -n \
        --arg url "$URL" \
        '{success: true, message: "GCS path returned (signed URL requires service account key)", url: $url, type: "gs_path", note: "Install gsutil and provide service_account_key for signed URLs"}'
fi
