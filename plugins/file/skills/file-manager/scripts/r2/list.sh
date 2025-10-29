#!/bin/bash
# File Manager: R2 List
# Lists files in Cloudflare R2

set -euo pipefail

# Parse arguments
PREFIX="${1:-}"
MAX_RESULTS="${2:-100}"

# Check if aws CLI is available
if ! command -v aws &> /dev/null; then
    echo "Error: aws CLI not found" >&2
    exit 3
fi

# Get R2 configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JSON=$("$SCRIPT_DIR/../../../faber-core/scripts/config-loader.sh")

if [ $? -ne 0 ]; then
    echo "Error: Failed to load configuration" >&2
    exit 3
fi

ACCOUNT_ID=$(echo "$CONFIG_JSON" | jq -r '.systems.file_config.account_id // empty')
BUCKET_NAME=$(echo "$CONFIG_JSON" | jq -r '.systems.file_config.bucket_name // empty')

if [ -z "$ACCOUNT_ID" ] || [ -z "$BUCKET_NAME" ]; then
    echo "Error: R2 configuration incomplete" >&2
    exit 3
fi

# R2 endpoint
R2_ENDPOINT="https://${ACCOUNT_ID}.r2.cloudflarestorage.com"

# Build list command
LIST_CMD="aws s3 ls s3://${BUCKET_NAME}/"

if [ -n "$PREFIX" ]; then
    LIST_CMD="$LIST_CMD${PREFIX}"
fi

LIST_CMD="$LIST_CMD --endpoint-url $R2_ENDPOINT --recursive"

# List files
result=$($LIST_CMD 2>&1 | head -n "$MAX_RESULTS")

if [ $? -ne 0 ]; then
    echo "Error: Failed to list files in R2" >&2
    exit 1
fi

# Convert to JSON array
echo "$result" | awk '{print $4}' | jq -R -s 'split("\n") | map(select(length > 0))'

exit 0
