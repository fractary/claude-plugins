#!/usr/bin/env bash
# Load validation context for a log type
# Usage: load-validation-context.sh {log_type}
# Returns: JSON with paths to validation files

set -euo pipefail

LOG_TYPE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Delegate to log-writer's load-type-context script (DRY principle)
"$PLUGIN_ROOT/skills/log-writer/scripts/load-type-context.sh" "$LOG_TYPE"
