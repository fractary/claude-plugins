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

# Check CLI version requirement
check_version() {
    local required_version="0.3.0"
    local current_version
    current_version=$("$CLI_CMD" --version 2>/dev/null | head -1 | tr -d 'v')

    if [ -z "$current_version" ]; then
        echo '{"status":"error","code":"VERSION_CHECK_FAILED","message":"Could not determine CLI version"}' >&2
        exit 1
    fi

    # Simple version comparison (works for semver x.y.z)
    if [ "$(printf '%s\n' "$required_version" "$current_version" | sort -V | head -1)" != "$required_version" ]; then
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
