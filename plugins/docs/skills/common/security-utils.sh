#!/usr/bin/env bash
#
# security-utils.sh - Common security utilities for fractary-docs scripts
#
# Source this file in scripts: source "$(dirname "$0")/security-utils.sh"
#

# Get script name for error messages
SCRIPT_NAME=$(basename "${BASH_SOURCE[1]}")

# Maximum JSON size (1MB)
MAX_JSON_SIZE=1048576

# Maximum JSON depth
MAX_JSON_DEPTH=10

# Validate file path to prevent path traversal and unauthorized access
# Usage: validate_file_path "/path/to/file" "read|write"
validate_file_path() {
  local file_path=$1
  local operation=${2:-read}  # read or write

  # Check for empty path
  if [[ -z "$file_path" ]]; then
    echo "Error [$SCRIPT_NAME]: Empty file path" >&2
    return 1
  fi

  # Get current working directory
  local cwd=$(pwd)

  # Resolve to absolute path (without following symlinks for security)
  local abs_path=$(realpath -m "$file_path" 2>/dev/null)

  # Fallback for systems without realpath
  if [[ -z "$abs_path" ]]; then
    # Basic path resolution
    if [[ "$file_path" =~ ^/ ]]; then
      abs_path="$file_path"
    else
      abs_path="$cwd/$file_path"
    fi
  fi

  # Block obvious path traversal patterns
  if [[ "$file_path" =~ \.\./.*\.\. ]]; then
    echo "Error [$SCRIPT_NAME]: Path traversal detected in: $file_path" >&2
    return 1
  fi

  # Block access to system directories
  if [[ "$abs_path" =~ ^/(etc|sys|proc|dev|bin|sbin|usr/bin|usr/sbin|boot|root|var/log) ]]; then
    echo "Error [$SCRIPT_NAME]: Access to system directories not allowed: $abs_path" >&2
    return 1
  fi

  # For write operations, ensure path is within working directory or docs directory
  if [[ "$operation" == "write" ]]; then
    # Allow writes only within current directory tree or explicit docs directories
    if [[ ! "$abs_path" =~ ^$cwd ]] && [[ ! "$abs_path" =~ /docs/ ]] && [[ ! "$abs_path" =~ /samples/ ]]; then
      echo "Error [$SCRIPT_NAME]: Write access denied outside working directory: $abs_path" >&2
      return 1
    fi
  fi

  return 0
}

# Validate JSON size and structure
# Usage: validate_json "$json_string"
validate_json() {
  local json_string=$1

  # Check size (prevent DoS)
  local json_size=${#json_string}
  if [[ $json_size -gt $MAX_JSON_SIZE ]]; then
    echo "Error [$SCRIPT_NAME]: JSON exceeds maximum size of $MAX_JSON_SIZE bytes (got $json_size)" >&2
    return 1
  fi

  # Validate JSON syntax with jq
  if ! command -v jq &> /dev/null; then
    echo "Error [$SCRIPT_NAME]: jq is required for JSON validation" >&2
    return 1
  fi

  if ! echo "$json_string" | jq empty 2>/dev/null; then
    echo "Error [$SCRIPT_NAME]: Invalid JSON syntax" >&2
    return 1
  fi

  # Check JSON depth (prevent deeply nested DoS)
  local depth=$(echo "$json_string" | jq 'path(.. | scalars) | length' 2>/dev/null | sort -n | tail -1)
  if [[ -n "$depth" ]] && [[ $depth -gt $MAX_JSON_DEPTH ]]; then
    echo "Error [$SCRIPT_NAME]: JSON nesting too deep: $depth levels (max $MAX_JSON_DEPTH)" >&2
    return 1
  fi

  return 0
}

# Sanitize string for shell output
# Usage: sanitized=$(sanitize_shell_string "$unsafe_string")
sanitize_shell_string() {
  local input=$1
  # Use printf %q for proper shell escaping
  printf %q "$input"
}

# Get file size in bytes (cross-platform)
# Usage: size=$(get_file_size "/path/to/file")
get_file_size() {
  local file_path=$1

  if [[ ! -f "$file_path" ]]; then
    echo "0"
    return 1
  fi

  # Try Linux format first (more common in CI), then macOS
  local size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null)
  echo "${size:-0}"
}

# Setup trap handler for cleanup
# Usage: setup_trap_handler "$temp_file"
setup_trap_handler() {
  local temp_file=$1

  cleanup() {
    if [[ -n "$temp_file" && -f "$temp_file" ]]; then
      rm -f "$temp_file"
    fi
  }

  # Trap multiple signals for robust cleanup
  trap cleanup EXIT ERR INT TERM
}

# Validate required dependencies
# Usage: check_dependencies jq yq
check_dependencies() {
  local missing=()

  for cmd in "$@"; do
    if ! command -v "$cmd" &> /dev/null; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error [$SCRIPT_NAME]: Missing required dependencies: ${missing[*]}" >&2
    return 1
  fi

  return 0
}

# Validate string doesn't contain shell metacharacters
# Usage: validate_safe_string "$user_input" "field_name"
validate_safe_string() {
  local input=$1
  local field_name=${2:-input}

  # Check for dangerous shell metacharacters
  if [[ "$input" =~ [\;\&\|\`\$\(\)] ]]; then
    echo "Error [$SCRIPT_NAME]: $field_name contains unsafe shell characters" >&2
    return 1
  fi

  return 0
}

# Create secure temporary file
# Usage: temp_file=$(create_secure_temp)
create_secure_temp() {
  local temp_file=$(mktemp)

  # Set restrictive permissions
  chmod 600 "$temp_file"

  echo "$temp_file"
}
