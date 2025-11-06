#!/usr/bin/env bash
#
# check-existing-config.sh - Checks for existing configuration files
#
# Usage: check-existing-config.sh
#
# Outputs (JSON):
# {
#   "project_config_exists": true|false,
#   "project_config_path": ".fractary/plugins/repo/config.json",
#   "global_config_exists": true|false,
#   "global_config_path": "~/.fractary/repo/config.json"
# }
#
# Exit codes:
#   0: Success

set -euo pipefail

# Check project-specific config
PROJECT_CONFIG=".fractary/plugins/repo/config.json"
PROJECT_EXISTS=false
if [ -f "$PROJECT_CONFIG" ]; then
    PROJECT_EXISTS=true
fi

# Check global config
GLOBAL_CONFIG="$HOME/.fractary/repo/config.json"
GLOBAL_EXISTS=false
if [ -f "$GLOBAL_CONFIG" ]; then
    GLOBAL_EXISTS=true
fi

# Output JSON
cat <<EOF | jq '.'
{
  "project_config_exists": $PROJECT_EXISTS,
  "project_config_path": "$PROJECT_CONFIG",
  "global_config_exists": $GLOBAL_EXISTS,
  "global_config_path": "$GLOBAL_CONFIG"
}
EOF
