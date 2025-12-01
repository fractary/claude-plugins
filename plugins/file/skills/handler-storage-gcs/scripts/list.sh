#!/bin/bash
# GCS Storage Handler: List
# Pure execution script - all parameters passed by skill

set -euo pipefail

# Parameters from skill
PROJECT_ID="$1"
BUCKET_NAME="$2"
SERVICE_ACCOUNT_KEY="${3:-}"
REGION="${4:-us-central1}"
PREFIX="${5:-}"
MAX_RESULTS="${6:-100}"

# Check gcloud CLI available
if ! command -v gcloud >/dev/null 2>&1; then
    echo "Error: gcloud CLI not found. Install from https://cloud.google.com/sdk/docs/install" >&2
    exit 3
fi

# Set service account key if provided (otherwise use ADC)
if [[ -n "$SERVICE_ACCOUNT_KEY" ]] && [[ -f "$SERVICE_ACCOUNT_KEY" ]]; then
    export GOOGLE_APPLICATION_CREDENTIALS="$SERVICE_ACCOUNT_KEY"
fi

# Build command with prefix if provided
if [[ -n "$PREFIX" ]]; then
    GCS_PATH="gs://${BUCKET_NAME}/${PREFIX}**"
else
    GCS_PATH="gs://${BUCKET_NAME}/**"
fi

# List files
OUTPUT=$(gcloud storage ls -l "$GCS_PATH" \
    --project="$PROJECT_ID" \
    2>&1 | head -n "$MAX_RESULTS")

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to list files in GCS" >&2
    echo "$OUTPUT" >&2
    # Return empty list instead of failing for empty buckets
    echo '{"success": true, "message": "No files found", "files": []}'
    exit 0
fi

# Parse output to JSON array
FILES=()
while IFS= read -r line; do
    # Skip header and summary lines
    if [[ "$line" =~ ^[0-9]+ ]] && [[ "$line" =~ gs:// ]]; then
        # Extract size and path
        SIZE=$(echo "$line" | awk '{print $1}')
        PATH=$(echo "$line" | awk '{print $3}' | sed "s|gs://${BUCKET_NAME}/||")
        TIME=$(echo "$line" | awk '{print $2}')

        FILES+=("{\"path\": \"$PATH\", \"size_bytes\": $SIZE, \"modified_at\": \"$TIME\"}")

        # Stop if we've reached max results
        if [[ ${#FILES[@]} -ge $MAX_RESULTS ]]; then
            break
        fi
    fi
done <<< "$OUTPUT"

# Build JSON array
if [[ ${#FILES[@]} -eq 0 ]]; then
    echo '{"success": true, "message": "No files found", "files": []}'
else
    FILES_JSON=$(IFS=,; echo "${FILES[*]}")
    echo "{\"success\": true, \"message\": \"Found ${#FILES[@]} files\", \"files\": [$FILES_JSON]}"
fi
