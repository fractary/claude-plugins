#!/bin/bash
# Compress log file if larger than threshold
set -euo pipefail

LOG_FILE="${1:?Log file path required}"
CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Load configuration
THRESHOLD_MB=1
if [[ -f "$CONFIG_FILE" ]]; then
    COMPRESSION_ENABLED=$(jq -r '.archive.compression.enabled // true' "$CONFIG_FILE")
    THRESHOLD_MB=$(jq -r '.archive.compression.threshold_mb // 1' "$CONFIG_FILE")

    if [[ "$COMPRESSION_ENABLED" != "true" ]]; then
        echo "$LOG_FILE"
        exit 0
    fi
fi

# Check if file exists
if [[ ! -f "$LOG_FILE" ]]; then
    echo "Error: File not found: $LOG_FILE" >&2
    exit 1
fi

# Get file size in MB
SIZE_MB=$(du -m "$LOG_FILE" | cut -f1)

# If below threshold, return original
if (( SIZE_MB <= THRESHOLD_MB )); then
    echo "$LOG_FILE"
    exit 0
fi

# Compress with gzip
COMPRESSED="${LOG_FILE}.gz"

# Remove existing compressed file if present
[[ -f "$COMPRESSED" ]] && rm "$COMPRESSED"

# Compress (keep original for now, delete after upload)
gzip -9 -c "$LOG_FILE" > "$COMPRESSED"

# Verify compression succeeded and is smaller
COMPRESSED_SIZE=$(du -k "$COMPRESSED" | cut -f1)
ORIGINAL_SIZE=$(du -k "$LOG_FILE" | cut -f1)

if (( COMPRESSED_SIZE >= ORIGINAL_SIZE )); then
    # Compression didn't help, use original
    rm "$COMPRESSED"
    echo "$LOG_FILE"
else
    echo "$COMPRESSED"
fi
