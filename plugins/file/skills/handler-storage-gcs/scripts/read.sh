#!/bin/bash
# GCS Storage Handler: Read
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
PROJECT_ID="$1"
BUCKET_NAME="$2"
SERVICE_ACCOUNT_KEY="${3:-}"
REGION="${4:-us-central1}"
REMOTE_PATH="$5"
MAX_BYTES="${6:-10485760}"  # 10MB default

# Check gcloud CLI available
if ! command -v gcloud >/dev/null 2>&1; then
    echo "Error: gcloud CLI not found. Install from https://cloud.google.com/sdk/docs/install" >&2
    exit 3
fi

# Set service account key if provided (otherwise use ADC)
if [[ -n "$SERVICE_ACCOUNT_KEY" ]] && [[ -f "$SERVICE_ACCOUNT_KEY" ]]; then
    export GOOGLE_APPLICATION_CREDENTIALS="$SERVICE_ACCOUNT_KEY"
fi

# Get file size first
SIZE=$(gcloud storage ls -L "gs://${BUCKET_NAME}/${REMOTE_PATH}" \
    --project="$PROJECT_ID" \
    2>/dev/null | grep "Content-Length:" | awk '{print $2}')

if [[ $? -ne 0 ]] || [[ -z "$SIZE" ]]; then
    echo "Error: File not found in GCS: $REMOTE_PATH" >&2
    exit 10
fi

# Warn if file exceeds limit
if (( SIZE > MAX_BYTES )); then
    echo "[Warning: File size $SIZE bytes exceeds max $MAX_BYTES bytes, truncating]" >&2
fi

# Stream file to stdout, truncate if needed
gcloud storage cat "gs://${BUCKET_NAME}/${REMOTE_PATH}" \
    --project="$PROJECT_ID" \
    2>/dev/null | head -c "$MAX_BYTES"

# Show truncation message if needed
if (( SIZE > MAX_BYTES )); then
    echo "" >&2
    echo "[Truncated. Full file size: $SIZE bytes. Use --max-bytes=$SIZE or download full file]" >&2
fi
