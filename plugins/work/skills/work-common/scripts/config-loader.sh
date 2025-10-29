#!/bin/bash
# Work Common: Configuration Loader
# Loads and validates work plugin configuration from .faber/plugins/work/config.json

set -euo pipefail

# Configuration file location (relative to project root)
CONFIG_FILE=".faber/plugins/work/config.json"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found: $CONFIG_FILE" >&2
    echo "  Create configuration from template:" >&2
    echo "  cp plugins/work/config/config.example.json $CONFIG_FILE" >&2
    exit 3
fi

# Validate JSON syntax
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo "Error: Invalid JSON in configuration file: $CONFIG_FILE" >&2
    exit 3
fi

# Validate required fields exist
if ! jq -e '.handlers["work-tracker"]' "$CONFIG_FILE" >/dev/null 2>&1; then
    echo "Error: Missing required field: .handlers[\"work-tracker\"]" >&2
    exit 3
fi

if ! jq -e '.handlers["work-tracker"].active' "$CONFIG_FILE" >/dev/null 2>&1; then
    echo "Error: Missing required field: .handlers[\"work-tracker\"].active" >&2
    exit 3
fi

# Extract active platform
ACTIVE_PLATFORM=$(jq -r '.handlers["work-tracker"].active' "$CONFIG_FILE" 2>/dev/null)

# Validate platform configuration exists
if ! jq -e ".handlers[\"work-tracker\"].\"$ACTIVE_PLATFORM\"" "$CONFIG_FILE" >/dev/null 2>&1; then
    echo "Error: Configuration for platform '$ACTIVE_PLATFORM' not found" >&2
    echo "  Active platform set to: $ACTIVE_PLATFORM" >&2
    echo "  But .handlers[\"work-tracker\"].$ACTIVE_PLATFORM is missing" >&2
    exit 3
fi

# Output full configuration JSON to stdout
cat "$CONFIG_FILE"

exit 0
