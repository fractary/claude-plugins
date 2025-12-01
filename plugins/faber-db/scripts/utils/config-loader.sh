#!/usr/bin/env bash
#
# config-loader.sh
# Load FABER-DB plugin configuration
#
# Usage:
#   source config-loader.sh
#   load_config
#
# Environment Variables:
#   CLAUDE_DB_CWD - Working directory (for config loading)
#   FABER_DB_CONFIG - Override config file path
#
# Exports:
#   CONFIG_FILE - Path to config file
#   DB_PROVIDER - Database provider (postgresql, mysql, etc.)
#   DB_HOSTING - Hosting platform (aws-aurora, local, etc.)
#   MIGRATION_TOOL - Migration tool (prisma, typeorm, etc.)
#   PROJECT_ROOT - Project root directory
#

set -euo pipefail

# Find project root directory
find_project_root() {
    local start_dir="${CLAUDE_DB_CWD:-${PWD}}"

    # Try to find git root first
    if command -v git &> /dev/null; then
        if git_root=$(cd "$start_dir" && git rev-parse --show-toplevel 2>/dev/null); then
            echo "$git_root"
            return 0
        fi
    fi

    # Fallback to current directory
    echo "$start_dir"
}

# Load configuration file
load_config() {
    # Find project root
    PROJECT_ROOT=$(find_project_root)
    export PROJECT_ROOT

    # Determine config file path
    if [ -n "${FABER_DB_CONFIG:-}" ]; then
        CONFIG_FILE="$FABER_DB_CONFIG"
    else
        CONFIG_FILE="$PROJECT_ROOT/.fractary/plugins/faber-db/config.json"
    fi

    # Check if config exists
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: FABER-DB configuration not found at: $CONFIG_FILE" >&2
        echo "Run /faber-db:init to create configuration" >&2
        return 1
    fi

    # Validate JSON
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        echo "Error: Invalid JSON in configuration file: $CONFIG_FILE" >&2
        return 1
    fi

    # Export configuration path
    export CONFIG_FILE

    # Load database settings
    DB_PROVIDER=$(jq -r '.database.provider // "postgresql"' "$CONFIG_FILE")
    DB_HOSTING=$(jq -r '.database.hosting // "local"' "$CONFIG_FILE")
    MIGRATION_TOOL=$(jq -r '.database.migration_tool // "prisma"' "$CONFIG_FILE")

    export DB_PROVIDER
    export DB_HOSTING
    export MIGRATION_TOOL

    return 0
}

# Get environment configuration
get_environment_config() {
    local environment="$1"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Config file not loaded. Call load_config first." >&2
        return 1
    fi

    # Check if environment exists
    if ! jq -e ".environments.\"$environment\"" "$CONFIG_FILE" &>/dev/null; then
        echo "Error: Environment '$environment' not found in configuration" >&2
        return 1
    fi

    # Extract environment settings
    local conn_string_env=$(jq -r ".environments.\"$environment\".connection_string_env" "$CONFIG_FILE")
    local auto_migrate=$(jq -r ".environments.\"$environment\".auto_migrate // false" "$CONFIG_FILE")
    local backup_before=$(jq -r ".environments.\"$environment\".backup_before_migrate // false" "$CONFIG_FILE")
    local require_approval=$(jq -r ".environments.\"$environment\".require_approval // false" "$CONFIG_FILE")

    # Export environment settings
    export ENV_CONNECTION_STRING_VAR="$conn_string_env"
    export ENV_AUTO_MIGRATE="$auto_migrate"
    export ENV_BACKUP_BEFORE="$backup_before"
    export ENV_REQUIRE_APPROVAL="$require_approval"

    # Get actual connection string from environment variable
    export ENV_CONNECTION_STRING="${!conn_string_env:-}"

    if [ -z "$ENV_CONNECTION_STRING" ]; then
        echo "Error: Environment variable '$conn_string_env' is not set" >&2
        echo "Set it with: export $conn_string_env=\"postgresql://...\"" >&2
        return 1
    fi

    return 0
}

# Check if environment is protected
is_protected_environment() {
    local environment="$1"

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Config file not loaded. Call load_config first." >&2
        return 1
    fi

    # Get protected environments list
    local protected_envs=$(jq -r '.safety.protected_environments[]?' "$CONFIG_FILE")

    # Check if environment is in protected list
    if echo "$protected_envs" | grep -q "^${environment}$"; then
        return 0  # Is protected
    else
        return 1  # Not protected
    fi
}

# Get safety settings
get_safety_settings() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Config file not loaded. Call load_config first." >&2
        return 1
    fi

    # Export safety settings
    export SAFETY_MAX_ROLLBACK_ATTEMPTS=$(jq -r '.safety.max_auto_rollback_attempts // 1' "$CONFIG_FILE")
    export SAFETY_HEALTH_CHECK_BEFORE=$(jq -r '.safety.health_check_before_deploy // true' "$CONFIG_FILE")
    export SAFETY_HEALTH_CHECK_AFTER=$(jq -r '.safety.health_check_after_deploy // true' "$CONFIG_FILE")
    export SAFETY_ROLLBACK_ON_FAILURE=$(jq -r '.safety.rollback_on_health_check_failure // true' "$CONFIG_FILE")

    return 0
}

# Get integration settings
get_integration_settings() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Config file not loaded. Call load_config first." >&2
        return 1
    fi

    # Export integration settings
    export CLOUD_PLUGIN=$(jq -r '.integration.cloud_plugin // "fractary-faber-cloud"' "$CONFIG_FILE")
    export WORK_PLUGIN=$(jq -r '.integration.work_plugin // "fractary-work"' "$CONFIG_FILE")
    export LOGS_PLUGIN=$(jq -r '.integration.logs_plugin // "fractary-logs"' "$CONFIG_FILE")

    return 0
}

# Utility function to print config summary
print_config_summary() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Config file not loaded. Call load_config first." >&2
        return 1
    fi

    echo "FABER-DB Configuration"
    echo "  Config File: $CONFIG_FILE"
    echo "  Provider: $DB_PROVIDER"
    echo "  Hosting: $DB_HOSTING"
    echo "  Migration Tool: $MIGRATION_TOOL"
    echo "  Project Root: $PROJECT_ROOT"
}

# Main function for standalone execution
main() {
    if load_config; then
        print_config_summary
        return 0
    else
        return 1
    fi
}

# If script is executed directly (not sourced), run main
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
