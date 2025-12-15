#!/bin/bash
# Wrapper for fractary CLI codex commands
# Supports global install or npx fallback for maximum flexibility
#
# Usage: invoke-cli.sh <command> [args...]
# Example: invoke-cli.sh fetch "codex://org/project/file.md" --json

set -euo pipefail

# Validate arguments
if [ $# -lt 1 ]; then
    echo '{"status":"failure","message":"Missing command argument","usage":"invoke-cli.sh <command> [args...]"}' >&2
    exit 1
fi

command="$1"
shift
args="$@"

# Check for CLI availability (global first, then npx fallback)
FRACTARY_CMD=""
CLI_SOURCE=""

if command -v fractary &> /dev/null; then
    # Global installation found
    FRACTARY_CMD="fractary"
    CLI_SOURCE="global"
elif command -v npx &> /dev/null; then
    # npx fallback - will download if not cached
    FRACTARY_CMD="npx --yes @fractary/cli"
    CLI_SOURCE="npx"
    # Inform user about npx usage (non-fatal)
    echo '{"info":"Using npx fallback - consider installing globally: npm install -g @fractary/cli"}' >&2
else
    # Neither available
    echo '{"status":"failure","message":"@fractary/cli not installed and npx not available","suggested_fixes":["Install globally: npm install -g @fractary/cli","Or ensure npx is available (comes with npm 5.2+)","Or install locally: npm install @fractary/cli"]}' >&2
    exit 1
fi

# Execute command with JSON output
# Note: --json flag ensures programmatic output for parsing
$FRACTARY_CMD codex "$command" $args --json 2>&1
exit_code=$?

# Exit with CLI's exit code
exit $exit_code
