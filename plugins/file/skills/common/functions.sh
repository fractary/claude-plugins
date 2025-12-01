#!/bin/bash
# Common Functions Library for File Plugin
# Provides shared utilities for all storage handlers

# Load handler-specific configuration
# Usage: load_handler_config <config_file> <handler>
# Returns: JSON object with handler configuration
load_handler_config() {
    local config_file="$1"
    local handler="$2"

    # Try project config first
    if [[ -z "$config_file" ]]; then
        config_file=".fractary/plugins/file/config.json"
    fi

    if [[ ! -f "$config_file" ]]; then
        # Try global config
        config_file="$HOME/.config/fractary/file/config.json"
    fi

    if [[ ! -f "$config_file" ]]; then
        echo "{}" # Return empty config
        return 0
    fi

    if ! jq -r ".handlers.$handler // {}" "$config_file" 2>/dev/null; then
        echo "Error: Invalid JSON in config file: $config_file" >&2
        return 1
    fi
}

# Load global settings from configuration
# Usage: load_global_settings [config_file]
# Returns: JSON object with global settings
load_global_settings() {
    local config_file="${1:-.fractary/plugins/file/config.json}"

    if [[ ! -f "$config_file" ]]; then
        config_file="$HOME/.config/fractary/file/config.json"
    fi

    if [[ ! -f "$config_file" ]]; then
        echo '{"retry_attempts":3,"retry_delay_ms":1000,"timeout_seconds":300,"verify_checksums":true}'
        return 0
    fi

    if ! jq -r ".global_settings // {}" "$config_file" 2>/dev/null; then
        echo '{"retry_attempts":3,"retry_delay_ms":1000,"timeout_seconds":300,"verify_checksums":true}'
        return 0
    fi
}

# Get active handler from configuration
# Usage: get_active_handler [config_file]
# Returns: Handler name (e.g., "local", "r2", "s3")
get_active_handler() {
    local config_file="${1:-.fractary/plugins/file/config.json}"

    if [[ ! -f "$config_file" ]]; then
        config_file="$HOME/.config/fractary/file/config.json"
    fi

    if [[ ! -f "$config_file" ]]; then
        echo "local" # Default to local
        return 0
    fi

    local handler=$(jq -r '.active_handler // "local"' "$config_file" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "local"
        return 0
    fi

    echo "$handler"
}

# Expand environment variables in config values
# Usage: expand_env_vars <value>
# Returns: Value with ${VAR_NAME} replaced
expand_env_vars() {
    local value="$1"

    if [[ -z "$value" ]]; then
        echo ""
        return 0
    fi

    # Replace ${VAR_NAME} with actual value
    echo "$value" | envsubst
}

# Calculate checksum (cross-platform)
# Usage: calculate_checksum <file>
# Returns: SHA256 checksum
calculate_checksum() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file" >&2
        return 1
    fi

    # Try sha256sum (Linux)
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
        return 0
    fi

    # Try shasum (macOS)
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
        return 0
    fi

    echo "Error: No checksum command available (tried sha256sum, shasum)" >&2
    return 1
}

# Get file size (cross-platform)
# Usage: get_file_size <file>
# Returns: File size in bytes
get_file_size() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file" >&2
        return 1
    fi

    # Try GNU stat (Linux)
    if stat -c%s "$file" 2>/dev/null; then
        return 0
    fi

    # Try BSD stat (macOS)
    if stat -f%z "$file" 2>/dev/null; then
        return 0
    fi

    echo "Error: Cannot determine file size" >&2
    return 1
}

# Retry operation with exponential backoff
# Usage: retry_operation <max_attempts> <initial_delay> <command...>
# Returns: 0 on success, 1 on failure after all attempts
retry_operation() {
    local max_attempts="${1:-3}"
    local initial_delay="${2:-1}"
    shift 2
    local command="$*"

    if [[ -z "$command" ]]; then
        echo "Error: No command specified for retry" >&2
        return 1
    fi

    local attempt=1
    local delay="$initial_delay"

    while (( attempt <= max_attempts )); do
        if eval "$command"; then
            return 0
        fi

        if (( attempt < max_attempts )); then
            echo "Attempt $attempt failed, retrying in ${delay}s..." >&2
            sleep "$delay"
            delay=$((delay * 2))  # Exponential backoff
        fi

        attempt=$((attempt + 1))
    done

    echo "Error: Command failed after $max_attempts attempts" >&2
    return 1
}

# Return JSON result (safe JSON construction)
# Usage: return_result <success> <message> [extra_json]
# Returns: JSON object with success, message, and optional extra fields
return_result() {
    local success="$1"
    local message="$2"
    shift 2
    local extra="${*:-{}}"

    # Validate extra is valid JSON
    if ! echo "$extra" | jq empty 2>/dev/null; then
        extra="{}"
    fi

    jq -n \
        --arg success "$success" \
        --arg message "$message" \
        --argjson extra "$extra" \
        '{success: ($success == "true"), message: $message} + $extra'
}

# Validate required tools are available
# Usage: check_required_tools <tool1> <tool2> ...
# Returns: 0 if all tools available, 1 if any missing
check_required_tools() {
    local tools=("$@")
    local missing=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing+=("$tool")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        echo "Error: Missing required tools: ${missing[*]}" >&2
        echo "Please install them before continuing." >&2
        return 1
    fi

    return 0
}

# Validate file path for safety (prevent path traversal)
# Usage: validate_path <path>
# Returns: 0 if safe, 1 if potentially dangerous
validate_path() {
    local path="$1"

    # Check for path traversal attempts
    if [[ "$path" =~ \.\. ]]; then
        echo "Error: Path contains '..' (path traversal attempt)" >&2
        return 1
    fi

    # Check for absolute paths in remote paths (should be relative)
    if [[ "$path" =~ ^/ ]] && [[ "${2:-}" != "allow_absolute" ]]; then
        echo "Error: Absolute paths not allowed: $path" >&2
        return 1
    fi

    return 0
}

# Mask sensitive value for logging
# Usage: mask_credential <value>
# Returns: Masked value (shows first 4 and last 4 characters)
mask_credential() {
    local value="$1"
    local length=${#value}

    if [[ $length -le 8 ]]; then
        echo "****"
        return 0
    fi

    local prefix="${value:0:4}"
    local suffix="${value: -4}"
    echo "${prefix}****${suffix}"
}

# Check and enforce file permissions on config file
# Usage: enforce_config_permissions <config_file>
# Returns: 0 if permissions correct or fixed, 1 on error
enforce_config_permissions() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        return 0 # File doesn't exist yet
    fi

    # Get current permissions (numeric)
    local perms
    if perms=$(stat -c %a "$config_file" 2>/dev/null); then
        # Linux stat
        :
    elif perms=$(stat -f %A "$config_file" 2>/dev/null); then
        # macOS stat
        :
    else
        echo "Warning: Cannot check file permissions" >&2
        return 0
    fi

    # Check if permissions are too open
    if [[ "$perms" != "600" ]]; then
        echo "Warning: Config file permissions are $perms (should be 600)" >&2
        echo "Fixing permissions: chmod 0600 $config_file" >&2
        chmod 0600 "$config_file"
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to set permissions on $config_file" >&2
            return 1
        fi
    fi

    return 0
}

# Create directory with safe permissions
# Usage: create_safe_directory <dir_path>
# Returns: 0 on success, 1 on failure
create_safe_directory() {
    local dir_path="$1"

    if [[ -d "$dir_path" ]]; then
        return 0 # Already exists
    fi

    mkdir -p "$dir_path"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to create directory: $dir_path" >&2
        return 1
    fi

    chmod 0755 "$dir_path"
    return 0
}

# Log operation for audit trail
# Usage: log_operation <handler> <operation> <path> [status]
# Logs to ~/.config/fractary/file/audit.log
log_operation() {
    local handler="$1"
    local operation="$2"
    local path="$3"
    local status="${4:-success}"

    local log_dir="$HOME/.config/fractary/file"
    local log_file="$log_dir/audit.log"

    create_safe_directory "$log_dir" >/dev/null 2>&1

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local log_entry="$timestamp | $handler | $operation | $path | $status"

    echo "$log_entry" >> "$log_file" 2>/dev/null || true
}

# Export functions for use in other scripts
export -f load_handler_config
export -f load_global_settings
export -f get_active_handler
export -f expand_env_vars
export -f calculate_checksum
export -f get_file_size
export -f retry_operation
export -f return_result
export -f check_required_tools
export -f validate_path
export -f mask_credential
export -f enforce_config_permissions
export -f create_safe_directory
export -f log_operation
