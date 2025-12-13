#!/bin/bash
# Fractary CLI Invocation Helper
# Shared wrapper for invoking fractary CLI commands from work plugin skills
# Usage: invoke-cli.sh <subcommand> <args...>
# Example: invoke-cli.sh issue create --title "My title" --json

set -e

# CLI command to use
CLI_CMD="fractary"

# Check if CLI is available
check_cli() {
    if ! command -v "$CLI_CMD" &> /dev/null; then
        echo '{"status":"error","code":"CLI_NOT_FOUND","message":"Fractary CLI not found. Install with: npm install -g @fractary/cli"}' >&2
        exit 1
    fi
}

# POSIX-compliant version comparison (works on macOS/BSD and Linux)
# Returns 0 if version1 <= version2, 1 otherwise
version_lte() {
    local v1="$1" v2="$2"
    # Split versions into components
    local v1_major v1_minor v1_patch v2_major v2_minor v2_patch
    v1_major=$(echo "$v1" | cut -d. -f1)
    v1_minor=$(echo "$v1" | cut -d. -f2)
    v1_patch=$(echo "$v1" | cut -d. -f3)
    v2_major=$(echo "$v2" | cut -d. -f1)
    v2_minor=$(echo "$v2" | cut -d. -f2)
    v2_patch=$(echo "$v2" | cut -d. -f3)

    # Default missing components to 0
    v1_minor=${v1_minor:-0}
    v1_patch=${v1_patch:-0}
    v2_minor=${v2_minor:-0}
    v2_patch=${v2_patch:-0}

    # Compare major.minor.patch
    if [ "$v1_major" -lt "$v2_major" ]; then return 0; fi
    if [ "$v1_major" -gt "$v2_major" ]; then return 1; fi
    if [ "$v1_minor" -lt "$v2_minor" ]; then return 0; fi
    if [ "$v1_minor" -gt "$v2_minor" ]; then return 1; fi
    if [ "$v1_patch" -le "$v2_patch" ]; then return 0; fi
    return 1
}

# Check CLI version requirement
check_version() {
    local required_version="0.3.0"
    local current_version
    current_version=$("$CLI_CMD" --version 2>/dev/null | head -1 | tr -d 'v')

    if [ -z "$current_version" ]; then
        echo '{"status":"error","code":"VERSION_CHECK_FAILED","message":"Could not determine CLI version"}' >&2
        exit 1
    fi

    # POSIX-compliant version comparison (no sort -V needed)
    if ! version_lte "$required_version" "$current_version"; then
        echo "{\"status\":\"error\",\"code\":\"VERSION_TOO_OLD\",\"message\":\"CLI version $current_version is too old. Required: >= $required_version\"}" >&2
        exit 1
    fi
}

# Main invocation
main() {
    check_cli
    check_version

    # Execute CLI command with all arguments
    # The caller should include --json flag if needed
    "$CLI_CMD" work "$@"
}

# Run main with all passed arguments
main "$@"
