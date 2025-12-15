#!/bin/bash
# Migrate codex configuration from JSON to YAML format
# Supports both project and global configs

set -euo pipefail

# Check for jq and yq
if ! command -v jq &> /dev/null; then
    cat <<EOF
{
  "status": "failure",
  "error": "jq not installed",
  "message": "jq is required for JSON parsing",
  "suggested_fixes": [
    "Install jq: brew install jq (macOS)",
    "Install jq: apt-get install jq (Ubuntu/Debian)",
    "Install jq: yum install jq (RHEL/CentOS)"
  ]
}
EOF
    exit 1
fi

if ! command -v yq &> /dev/null; then
    cat <<EOF
{
  "status": "failure",
  "error": "yq not installed",
  "message": "yq (mikefarah/yq) is required for YAML generation",
  "suggested_fixes": [
    "Install yq: brew install yq (macOS)",
    "Install yq: snap install yq (Ubuntu)",
    "Or download from: https://github.com/mikefarah/yq/releases"
  ]
}
EOF
    exit 1
fi

# Parse arguments
SOURCE_PATH=""
TARGET_PATH=".fractary/codex.yaml"
DRY_RUN=false
REMOVE_SOURCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --source)
            SOURCE_PATH="$2"
            shift 2
            ;;
        --target)
            TARGET_PATH="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --remove-source)
            REMOVE_SOURCE=true
            shift
            ;;
        *)
            echo "{\"status\":\"failure\",\"error\":\"Unknown argument: $1\"}" >&2
            exit 1
            ;;
    esac
done

# Auto-detect source if not provided
if [ -z "$SOURCE_PATH" ]; then
    if [ -f ".fractary/plugins/codex/config.json" ]; then
        SOURCE_PATH=".fractary/plugins/codex/config.json"
    elif [ -f "$HOME/.config/fractary/codex/config.json" ]; then
        SOURCE_PATH="$HOME/.config/fractary/codex/config.json"
    else
        cat <<EOF
{
  "status": "failure",
  "error": "No JSON config found",
  "message": "Could not find config.json to migrate",
  "checked_paths": [
    ".fractary/plugins/codex/config.json",
    "$HOME/.config/fractary/codex/config.json"
  ]
}
EOF
        exit 1
    fi
fi

# Verify source exists
if [ ! -f "$SOURCE_PATH" ]; then
    cat <<EOF
{
  "status": "failure",
  "error": "Source config not found",
  "path": "$SOURCE_PATH"
}
EOF
    exit 1
fi

# Verify target doesn't exist (unless dry-run)
if [ -f "$TARGET_PATH" ] && [ "$DRY_RUN" = false ]; then
    cat <<EOF
{
  "status": "failure",
  "error": "Target config already exists",
  "path": "$TARGET_PATH",
  "suggested_fixes": [
    "Remove existing YAML config first",
    "Or use --dry-run to preview migration"
  ]
}
EOF
    exit 1
fi

# Read source JSON
if ! JSON_CONTENT=$(cat "$SOURCE_PATH"); then
    cat <<EOF
{
  "status": "failure",
  "error": "Failed to read source config",
  "path": "$SOURCE_PATH"
}
EOF
    exit 1
fi

# Validate JSON
if ! echo "$JSON_CONTENT" | jq . > /dev/null 2>&1; then
    cat <<EOF
{
  "status": "failure",
  "error": "Invalid JSON in source config",
  "path": "$SOURCE_PATH"
}
EOF
    exit 1
fi

# Convert JSON to YAML using yq
# Update version to 4.0 for CLI compatibility
YAML_CONTENT=$(echo "$JSON_CONTENT" | jq '.version = "4.0"' | yq -P)

if [ "$DRY_RUN" = true ]; then
    # Dry-run: show what would be created
    cat <<EOF
{
  "status": "success",
  "operation": "dry-run",
  "source": {
    "path": "$SOURCE_PATH",
    "format": "json"
  },
  "target": {
    "path": "$TARGET_PATH",
    "format": "yaml"
  },
  "would_remove_source": $REMOVE_SOURCE,
  "preview": $(echo "$YAML_CONTENT" | jq -Rs .)
}
EOF
    exit 0
fi

# Create target directory if needed
TARGET_DIR=$(dirname "$TARGET_PATH")
if [ ! -d "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
fi

# Write YAML config
echo "$YAML_CONTENT" > "$TARGET_PATH"

# Remove source if requested
if [ "$REMOVE_SOURCE" = true ]; then
    rm "$SOURCE_PATH"
fi

# Success response
cat <<EOF
{
  "status": "success",
  "operation": "migrate",
  "source": {
    "path": "$SOURCE_PATH",
    "format": "json",
    "removed": $REMOVE_SOURCE
  },
  "target": {
    "path": "$TARGET_PATH",
    "format": "yaml",
    "created": true
  },
  "message": "Configuration migrated successfully",
  "next_steps": [
    "Review the new YAML config: cat $TARGET_PATH",
    "Test with: fractary codex health",
    "Update any scripts that reference the old path"
  ]
}
EOF
exit 0
