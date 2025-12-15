#!/bin/bash
# Detect codex configuration format and location
# Returns JSON with config information

set -euo pipefail

# Configuration paths
PROJECT_JSON_CONFIG=".fractary/plugins/codex/config.json"
PROJECT_YAML_CONFIG=".fractary/codex.yaml"
LEGACY_GLOBAL_CONFIG="$HOME/.config/fractary/codex/config.json"

# Check for project YAML config (preferred)
if [ -f "$PROJECT_YAML_CONFIG" ]; then
    cat <<EOF
{
  "status": "found",
  "format": "yaml",
  "location": "project",
  "path": "$PROJECT_YAML_CONFIG",
  "is_preferred": true,
  "migration_needed": false
}
EOF
    exit 0
fi

# Check for project JSON config (deprecated, needs migration)
if [ -f "$PROJECT_JSON_CONFIG" ]; then
    cat <<EOF
{
  "status": "found",
  "format": "json",
  "location": "project",
  "path": "$PROJECT_JSON_CONFIG",
  "is_preferred": false,
  "migration_needed": true,
  "migration_target": "$PROJECT_YAML_CONFIG",
  "deprecation_warning": "JSON format is deprecated. Please migrate to YAML format at .fractary/codex.yaml"
}
EOF
    exit 0
fi

# Check for legacy global config (deprecated)
if [ -f "$LEGACY_GLOBAL_CONFIG" ]; then
    cat <<EOF
{
  "status": "found",
  "format": "json",
  "location": "global",
  "path": "$LEGACY_GLOBAL_CONFIG",
  "is_preferred": false,
  "migration_needed": true,
  "migration_target": "$PROJECT_YAML_CONFIG",
  "deprecation_warning": "Global config is deprecated. Please migrate to project-level YAML config at .fractary/codex.yaml"
}
EOF
    exit 0
fi

# No config found
cat <<EOF
{
  "status": "not_found",
  "suggested_action": "Run /fractary-codex:init to create configuration",
  "preferred_format": "yaml",
  "preferred_path": "$PROJECT_YAML_CONFIG"
}
EOF
exit 0
