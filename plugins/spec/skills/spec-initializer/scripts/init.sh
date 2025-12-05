#!/usr/bin/env bash
#
# init.sh - Initialize spec plugin configuration
#
# Usage: init.sh [--force]
#
# Arguments:
#   --force: Overwrite existing config without prompting
#
# Outputs (JSON):
# {
#   "status": "success|failure|exists",
#   "config_path": "/path/to/config.json",
#   "specs_dir": "/path/to/specs",
#   "message": "Human-readable message"
# }
#
# Exit codes:
#   0: Success
#   1: General error
#   10: Config already exists (without --force)

set -euo pipefail

# Default values
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

CONFIG_PATH=".fractary/plugins/spec/config.json"
SPECS_DIR="specs"
ARCHIVE_INDEX=".fractary/plugins/spec/archive-index.json"

# Check if config already exists
if [ -f "$CONFIG_PATH" ] && [ "$FORCE" = false ]; then
    jq -n \
        --arg status "exists" \
        --arg config_path "$CONFIG_PATH" \
        --arg message "Configuration already exists. Use --force to overwrite." \
        '{status: $status, config_path: $config_path, message: $message}'
    exit 10
fi

# Create directories
mkdir -p "$(dirname "$CONFIG_PATH")"
mkdir -p "$SPECS_DIR"

# Create config file
cat > "$CONFIG_PATH" << 'EOF'
{
  "schema_version": "1.0",
  "storage": {
    "local_path": "/specs",
    "cloud_archive_path": "archive/specs/{year}/{spec_id}.md",
    "archive_index": {
      "local_cache": ".fractary/plugins/spec/archive-index.json",
      "cloud_backup": "archive/specs/.archive-index.json"
    }
  },
  "naming": {
    "issue_specs": {
      "prefix": "WORK",
      "digits": 5,
      "phase_format": "numeric",
      "phase_separator": "-"
    },
    "standalone_specs": {
      "prefix": "SPEC",
      "digits": 4,
      "auto_increment": true,
      "start_from": null
    }
  },
  "archive": {
    "strategy": "lifecycle",
    "auto_archive_on": {
      "issue_close": true,
      "pr_merge": true,
      "faber_release": true
    }
  },
  "integration": {
    "work_plugin": "fractary-work",
    "file_plugin": "fractary-file",
    "link_to_issue": true
  },
  "templates": {
    "default": "spec-basic"
  }
}
EOF

# Set permissions
chmod 600 "$CONFIG_PATH"

# Create archive index if it doesn't exist
if [ ! -f "$ARCHIVE_INDEX" ]; then
    echo '{"specs": [], "last_updated": null}' > "$ARCHIVE_INDEX"
    chmod 600 "$ARCHIVE_INDEX"
fi

# Verify and output result
if [ -f "$CONFIG_PATH" ] && [ -d "$SPECS_DIR" ]; then
    jq -n \
        --arg status "success" \
        --arg config_path "$CONFIG_PATH" \
        --arg specs_dir "$SPECS_DIR" \
        --arg archive_index "$ARCHIVE_INDEX" \
        --arg message "Configuration created successfully." \
        '{status: $status, config_path: $config_path, specs_dir: $specs_dir, archive_index: $archive_index, message: $message}'
    exit 0
else
    jq -n \
        --arg status "failure" \
        --arg message "Failed to create configuration." \
        '{status: $status, message: $message}'
    exit 1
fi
