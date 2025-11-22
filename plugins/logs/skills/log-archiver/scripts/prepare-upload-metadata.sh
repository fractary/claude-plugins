#!/bin/bash
# Prepare metadata for log file upload (agent will perform actual upload)
set -euo pipefail

ISSUE_NUMBER="${1:?Issue number required}"
LOG_FILE="${2:?Log file path required}"
CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Input validation: Issue number should be numeric
if ! [[ "$ISSUE_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: Issue number must be numeric" >&2
    exit 1
fi

# Input validation: Log file path should not contain path traversal
if [[ "$LOG_FILE" =~ \.\. ]]; then
    echo "Error: Log file path contains invalid characters" >&2
    exit 1
fi

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

# Get filename (original, not compressed)
FILENAME=$(basename "$LOG_FILE")
ORIGINAL_FILENAME="${FILENAME%.gz}"  # Remove .gz if present
FULL_CLOUD_PATH="$CLOUD_PATH/$FILENAME"

# Determine log type from path
LOG_TYPE="unknown"
if [[ "$LOG_FILE" =~ /sessions/ ]]; then
    LOG_TYPE="session"
elif [[ "$LOG_FILE" =~ /builds/ ]]; then
    LOG_TYPE="build"
elif [[ "$LOG_FILE" =~ /deployments/ ]]; then
    LOG_TYPE="deployment"
elif [[ "$LOG_FILE" =~ /debug/ ]]; then
    LOG_TYPE="debug"
fi

# Get file size
SIZE_BYTES=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null || echo "0")

# Check if compressed
COMPRESSED="false"
if [[ "$FILENAME" =~ \.gz$ ]]; then
    COMPRESSED="true"
fi

# Calculate checksum
CHECKSUM=$(sha256sum "$LOG_FILE" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$LOG_FILE" 2>/dev/null | cut -d' ' -f1 || echo "unavailable")

# Get file creation time (from frontmatter if session, otherwise file mtime)
CREATED=""
if [[ "$LOG_TYPE" == "session" && -f "$LOG_FILE" ]]; then
    # Try to extract from frontmatter
    CREATED=$(grep "^started:" "$LOG_FILE" 2>/dev/null | head -1 | cut -d: -f2- | xargs || echo "")
fi

if [[ -z "$CREATED" ]]; then
    # Fall back to file modification time
    CREATED=$(date -u -r "$LOG_FILE" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || stat -f%Sm -t %Y-%m-%dT%H:%M:%SZ "$LOG_FILE" 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
fi

# Output as JSON for agent consumption
cat <<EOF
{
  "local_path": "$LOG_FILE",
  "remote_path": "$FULL_CLOUD_PATH",
  "type": "$LOG_TYPE",
  "filename": "$ORIGINAL_FILENAME",
  "size_bytes": $SIZE_BYTES,
  "compressed": $COMPRESSED,
  "checksum": "sha256:$CHECKSUM",
  "created": "$CREATED"
}
EOF
