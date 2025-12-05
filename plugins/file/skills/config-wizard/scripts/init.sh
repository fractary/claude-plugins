#!/usr/bin/env bash
#
# init.sh - Initialize file plugin configuration
#
# Usage: init.sh [--handler <name>] [--force]
#
# Arguments:
#   --handler <name>: local|r2|s3|gcs|gdrive (default: local)
#   --force: Overwrite existing config without prompting
#
# Outputs (JSON):
# {
#   "status": "success|failure|exists",
#   "config_path": "/path/to/config.json",
#   "handler": "local|r2|s3|gcs|gdrive",
#   "message": "Human-readable message"
# }
#
# Exit codes:
#   0: Success
#   1: General error
#   10: Config already exists (without --force)

set -euo pipefail

# Default values
HANDLER="local"
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --handler)
            HANDLER="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

CONFIG_PATH=".fractary/plugins/file/config.json"

# Check if config already exists
if [ -f "$CONFIG_PATH" ] && [ "$FORCE" = false ]; then
    jq -n \
        --arg status "exists" \
        --arg config_path "$CONFIG_PATH" \
        --arg message "Configuration already exists. Use --force to overwrite." \
        '{status: $status, config_path: $config_path, message: $message}'
    exit 10
fi

# Validate handler
if [[ ! "$HANDLER" =~ ^(local|r2|s3|gcs|gdrive)$ ]]; then
    jq -n \
        --arg status "failure" \
        --arg message "Invalid handler: $HANDLER. Must be local, r2, s3, gcs, or gdrive." \
        '{status: $status, message: $message}'
    exit 1
fi

# Create directory
mkdir -p "$(dirname "$CONFIG_PATH")"

# Create config file with local handler (simplest default)
cat > "$CONFIG_PATH" << 'EOF'
{
  "schema_version": "1.0",
  "active_handler": "local",
  "handlers": {
    "local": {
      "base_path": ".",
      "create_directories": true,
      "permissions": "0755"
    }
  },
  "global_settings": {
    "retry_attempts": 3,
    "retry_delay_ms": 1000,
    "timeout_seconds": 300,
    "verify_checksums": true,
    "parallel_uploads": 4
  }
}
EOF

# Set permissions
chmod 600 "$CONFIG_PATH"

# Verify and output result
if [ -f "$CONFIG_PATH" ]; then
    jq -n \
        --arg status "success" \
        --arg config_path "$CONFIG_PATH" \
        --arg handler "$HANDLER" \
        --arg message "Configuration created successfully with local handler." \
        '{status: $status, config_path: $config_path, handler: $handler, message: $message}'
    exit 0
else
    jq -n \
        --arg status "failure" \
        --arg message "Failed to create configuration file." \
        '{status: $status, message: $message}'
    exit 1
fi
