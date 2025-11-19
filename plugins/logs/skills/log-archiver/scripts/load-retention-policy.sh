#!/usr/bin/env bash
# Load retention policy for a specific log path from config.json
# Usage: load-retention-policy.sh <log_path> <config_file>
# Returns: JSON with matched retention policy (from paths array or default)
#
# This script matches the log path against patterns in retention.paths array
# and returns the first matching policy, or the default policy if no match.
#
# Example:
#   load-retention-policy.sh "/logs/sessions/session-123.md" ".fractary/plugins/logs/config.json"
#   Returns the retention policy for "sessions/*" pattern

set -euo pipefail

LOG_PATH="${1:-}"
CONFIG_FILE="${2:-.fractary/plugins/logs/config.json}"

# Validate inputs
if [[ -z "$LOG_PATH" ]]; then
  echo "ERROR: log_path required" >&2
  echo "Usage: load-retention-policy.sh <log_path> <config_file>" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

# Check for jq dependency
if ! command -v jq &> /dev/null; then
  echo "ERROR: jq is required but not installed" >&2
  echo "Install with: apt-get install jq (Ubuntu/Debian) or brew install jq (macOS)" >&2
  exit 1
fi

# Extract relative path from /logs/ directory
# Example: /logs/sessions/session-123.md -> sessions/session-123.md
RELATIVE_PATH="${LOG_PATH#/logs/}"
RELATIVE_PATH="${RELATIVE_PATH#logs/}"  # Handle both /logs/ and logs/ prefixes

# Load config
CONFIG=$(cat "$CONFIG_FILE")

# Get paths array from config
PATHS_COUNT=$(echo "$CONFIG" | jq -r '.retention.paths | length')

# Try to match against each pattern in order
MATCHED_POLICY=""
for (( i=0; i<PATHS_COUNT; i++ )); do
  PATTERN=$(echo "$CONFIG" | jq -r ".retention.paths[$i].pattern")

  # Convert glob pattern to bash pattern matching
  # Note: This uses bash's case pattern matching which supports globs
  if [[ "$RELATIVE_PATH" == $PATTERN ]]; then
    # Found a match! Extract this policy
    MATCHED_POLICY=$(echo "$CONFIG" | jq ".retention.paths[$i]")
    break
  fi
done

# If no match found, use default policy
if [[ -z "$MATCHED_POLICY" ]]; then
  # Merge default policy with minimal structure
  MATCHED_POLICY=$(echo "$CONFIG" | jq '.retention.default + {
    "pattern": "default",
    "log_type": "unknown",
    "matched": false
  }')
else
  # Add matched flag
  MATCHED_POLICY=$(echo "$MATCHED_POLICY" | jq '. + {"matched": true}')
fi

# Add the original log path to the output for reference
MATCHED_POLICY=$(echo "$MATCHED_POLICY" | jq --arg path "$LOG_PATH" '. + {"log_path": $path}')

# Output the matched policy
echo "$MATCHED_POLICY"
