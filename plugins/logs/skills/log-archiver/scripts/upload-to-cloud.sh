#!/bin/bash
# Upload log file to cloud storage via fractary-file
set -euo pipefail

ISSUE_NUMBER="${1:?Issue number required}"
LOG_FILE="${2:?Log file path required}"
CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Check if file exists
if [[ ! -f "$LOG_FILE" ]]; then
    echo "Error: File not found: $LOG_FILE" >&2
    exit 1
fi

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration not found at $CONFIG_FILE" >&2
    exit 1
fi

# Get cloud archive path pattern
CLOUD_PATH_PATTERN=$(jq -r '.storage.cloud_archive_path // "archive/logs/{year}/{month}/{issue_number}"' "$CONFIG_FILE")

# Substitute variables
YEAR=$(date +%Y)
MONTH=$(date +%m)
CLOUD_PATH="${CLOUD_PATH_PATTERN//\{year\}/$YEAR}"
CLOUD_PATH="${CLOUD_PATH//\{month\}/$MONTH}"
CLOUD_PATH="${CLOUD_PATH//\{issue_number\}/$ISSUE_NUMBER}"

# Append filename
FILENAME=$(basename "$LOG_FILE")
FULL_CLOUD_PATH="$CLOUD_PATH/$FILENAME"

# This is a placeholder for fractary-file integration
# In actual implementation, this would invoke the file-manager agent
# For now, we output the expected cloud URL format

# Simulated upload (replace with actual fractary-file invocation)
echo "# Upload $LOG_FILE to $FULL_CLOUD_PATH" >&2

# In actual implementation, this would be:
# Use @agent-fractary-file:file-manager to upload file
# Request: { "operation": "upload", "source": "$LOG_FILE", "destination": "$FULL_CLOUD_PATH" }
# Response: { "url": "s3://bucket/path/to/file" }

# For now, return expected URL format
STORAGE_PROVIDER=$(jq -r '.storage.provider // "s3"' "$CONFIG_FILE" 2>/dev/null || echo "s3")
BUCKET=$(jq -r '.storage.bucket // "fractary-logs"' "$CONFIG_FILE" 2>/dev/null || echo "fractary-logs")

# Output cloud URL
echo "${STORAGE_PROVIDER}://${BUCKET}/${FULL_CLOUD_PATH}"

# TODO: Actual implementation should:
# 1. Invoke fractary-file agent with upload operation
# 2. Wait for upload completion
# 3. Verify upload succeeded
# 4. Return actual cloud URL from response
