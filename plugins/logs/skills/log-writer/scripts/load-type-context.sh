#!/usr/bin/env bash
# Load type context files for a given log type
# Usage: load-type-context.sh {log_type}
# Returns: JSON object with paths to context files

set -euo pipefail

LOG_TYPE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TYPES_DIR="$PLUGIN_ROOT/types"

# Validate input
if [[ -z "$LOG_TYPE" ]]; then
  echo "ERROR: log_type required" >&2
  echo "Usage: load-type-context.sh {log_type}" >&2
  exit 1
fi

# Check if type exists
TYPE_DIR="$TYPES_DIR/$LOG_TYPE"
if [[ ! -d "$TYPE_DIR" ]]; then
  echo "ERROR: Unknown log type '$LOG_TYPE'" >&2
  echo "Available types:" >&2
  find "$TYPES_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort >&2
  exit 1
fi

# Build context object
SCHEMA_PATH="$TYPE_DIR/schema.json"
TEMPLATE_PATH="$TYPE_DIR/template.md"
STANDARDS_PATH="$TYPE_DIR/standards.md"
VALIDATION_PATH="$TYPE_DIR/validation-rules.md"
RETENTION_PATH="$TYPE_DIR/retention-config.json"

# Verify required files exist
MISSING=()
[[ ! -f "$SCHEMA_PATH" ]] && MISSING+=("schema.json")
[[ ! -f "$TEMPLATE_PATH" ]] && MISSING+=("template.md")
[[ ! -f "$STANDARDS_PATH" ]] && MISSING+=("standards.md")
[[ ! -f "$VALIDATION_PATH" ]] && MISSING+=("validation-rules.md")
[[ ! -f "$RETENTION_PATH" ]] && MISSING+=("retention-config.json")

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "ERROR: Missing required files for type '$LOG_TYPE':" >&2
  printf "  - %s\n" "${MISSING[@]}" >&2
  exit 1
fi

# Return JSON object with all paths
cat <<EOF
{
  "log_type": "$LOG_TYPE",
  "type_dir": "$TYPE_DIR",
  "schema": "$SCHEMA_PATH",
  "template": "$TEMPLATE_PATH",
  "standards": "$STANDARDS_PATH",
  "validation_rules": "$VALIDATION_PATH",
  "retention_config": "$RETENTION_PATH"
}
EOF
