#!/bin/bash
# Parse JSON output from fractary CLI commands
#
# Usage: parse-output.sh <field> [input_json]
# Example: echo '{"status":"success","data":"value"}' | parse-output.sh status

set -euo pipefail

# Check for jq availability
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq not installed (required for JSON parsing)" >&2
    exit 1
fi

field="$1"

# Read from stdin if no second argument
if [ $# -eq 1 ]; then
    input=$(cat)
else
    input="$2"
fi

# Parse field using jq
echo "$input" | jq -r ".$field" 2>/dev/null
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "ERROR: Failed to parse field '$field' from JSON" >&2
    exit 1
fi

exit 0
