#!/bin/bash
# Validate configuration against JSON schema
# Usage: validate-config.sh <config-file-path> [schema-file-path]
# Example: validate-config.sh .fractary/plugins/logs/config.json
#
# Note: This script runs from the plugin source directory and validates
# the runtime config at .fractary/plugins/logs/config.json
set -euo pipefail

CONFIG_FILE="${1:?Configuration file path required}"

# Determine schema file path relative to script location (in plugin source)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="${2:-$SCRIPT_DIR/../../../config/config.schema.json}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file not found: $CONFIG_FILE" >&2
    exit 1
fi

if [[ ! -f "$SCHEMA_FILE" ]]; then
    echo "Warning: Schema file not found: $SCHEMA_FILE" >&2
    echo "Skipping validation" >&2
    exit 0
fi

# Check if ajv-cli is installed (npm install -g ajv-cli)
if ! command -v ajv &> /dev/null; then
    echo "Warning: ajv-cli not found, skipping schema validation" >&2
    echo "Install with: npm install -g ajv-cli" >&2
    exit 0
fi

# Validate configuration against schema
if ajv validate -s "$SCHEMA_FILE" -d "$CONFIG_FILE" --strict=false 2>&1; then
    echo "✓ Configuration is valid"
    exit 0
else
    echo "✗ Configuration validation failed" >&2
    echo "" >&2
    echo "Please fix the configuration errors above." >&2
    echo "Reference: $SCHEMA_FILE" >&2
    exit 1
fi
