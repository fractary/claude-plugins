#!/bin/bash
# Collect all logs for an issue
set -euo pipefail

ISSUE_NUMBER="${1:?Issue number required}"
CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration not found at $CONFIG_FILE"
    exit 1
fi

LOG_DIR=$(jq -r '.storage.local_path // "/logs"' "$CONFIG_FILE")

# Find all logs for issue across different directories
LOGS=()

# Session logs
if [[ -d "$LOG_DIR/sessions" ]]; then
    while IFS= read -r -d '' file; do
        LOGS+=("$file")
    done < <(find "$LOG_DIR/sessions" -type f \( -name "*${ISSUE_NUMBER}*" -o -name "session-${ISSUE_NUMBER}-*" \) -print0 2>/dev/null || true)
fi

# Build logs
if [[ -d "$LOG_DIR/builds" ]]; then
    while IFS= read -r -d '' file; do
        LOGS+=("$file")
    done < <(find "$LOG_DIR/builds" -type f -name "${ISSUE_NUMBER}-*" -print0 2>/dev/null || true)
fi

# Deployment logs
if [[ -d "$LOG_DIR/deployments" ]]; then
    while IFS= read -r -d '' file; do
        LOGS+=("$file")
    done < <(find "$LOG_DIR/deployments" -type f -name "${ISSUE_NUMBER}-*" -print0 2>/dev/null || true)
fi

# Debug logs
if [[ -d "$LOG_DIR/debug" ]]; then
    while IFS= read -r -d '' file; do
        LOGS+=("$file")
    done < <(find "$LOG_DIR/debug" -type f -name "${ISSUE_NUMBER}-*" -print0 2>/dev/null || true)
fi

# Output as JSON array
if [[ ${#LOGS[@]} -eq 0 ]]; then
    echo "[]"
else
    printf '%s\n' "${LOGS[@]}" | jq -R . | jq -s .
fi
