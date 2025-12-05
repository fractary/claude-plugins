#!/usr/bin/env bash
# check-format.sh - Quick format check for skill responses
#
# Usage: ./check-format.sh '<response_json>'
#
# A lightweight check that doesn't do full validation - just checks structure.
#
# Exit codes:
#   0 - Format is valid
#   1 - Format is invalid
#   2 - Invalid arguments
#   3 - JSON parse error

set -euo pipefail

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo '{"status":"failure","message":"jq is required but not installed","errors":["Missing dependency: jq"]}' >&2
    exit 3
fi

# Parse arguments
if [[ $# -ne 1 ]]; then
    echo '{"status":"failure","message":"Missing required argument","errors":["Usage: check-format.sh <response_json>"]}' >&2
    exit 2
fi

RESPONSE_JSON="$1"

# Parse JSON to verify it's valid
if ! echo "$RESPONSE_JSON" | jq . > /dev/null 2>&1; then
    echo '{"status":"failure","message":"Invalid JSON input","errors":["Could not parse response as JSON"]}' >&2
    exit 3
fi

# Extract field presence
has_status=$(echo "$RESPONSE_JSON" | jq 'has("status")')
has_message=$(echo "$RESPONSE_JSON" | jq 'has("message")')
has_errors=$(echo "$RESPONSE_JSON" | jq 'has("errors")')
has_warnings=$(echo "$RESPONSE_JSON" | jq 'has("warnings")')
has_details=$(echo "$RESPONSE_JSON" | jq 'has("details")')
has_error_analysis=$(echo "$RESPONSE_JSON" | jq 'has("error_analysis")')
has_warning_analysis=$(echo "$RESPONSE_JSON" | jq 'has("warning_analysis")')
has_suggested_fixes=$(echo "$RESPONSE_JSON" | jq 'has("suggested_fixes")')

# Get status value if present
response_status="null"
if [[ "$has_status" == "true" ]]; then
    response_status=$(echo "$RESPONSE_JSON" | jq -r '.status')
fi

# Check if status is valid
is_valid_status=false
if [[ "$response_status" == "success" || "$response_status" == "warning" || "$response_status" == "failure" ]]; then
    is_valid_status=true
fi

# Determine overall validity
is_valid=false
if [[ "$has_status" == "true" && "$is_valid_status" == "true" && "$has_message" == "true" ]]; then
    is_valid=true
fi

# Build result
if [[ "$is_valid" == "true" ]]; then
    result=$(jq -n \
        --arg status "success" \
        --arg message "Response format is valid" \
        --argjson details "$(jq -n \
            --argjson has_status "$has_status" \
            --argjson has_message "$has_message" \
            --arg response_status "$response_status" \
            --argjson has_errors "$has_errors" \
            --argjson has_warnings "$has_warnings" \
            --argjson has_details "$has_details" \
            --argjson has_error_analysis "$has_error_analysis" \
            --argjson has_warning_analysis "$has_warning_analysis" \
            --argjson has_suggested_fixes "$has_suggested_fixes" \
            '{has_status: $has_status, has_message: $has_message, response_status: $response_status, has_errors: $has_errors, has_warnings: $has_warnings, has_details: $has_details, has_error_analysis: $has_error_analysis, has_warning_analysis: $has_warning_analysis, has_suggested_fixes: $has_suggested_fixes}')" \
        '{status: $status, message: $message, details: $details}')
    echo "$result"
    exit 0
else
    errors=()
    if [[ "$has_status" != "true" ]]; then
        errors+=("Missing 'status' field")
    elif [[ "$is_valid_status" != "true" ]]; then
        errors+=("Invalid status value: '$response_status'")
    fi
    if [[ "$has_message" != "true" ]]; then
        errors+=("Missing 'message' field")
    fi

    errors_json=$(printf '%s\n' "${errors[@]}" | jq -R . | jq -s .)

    result=$(jq -n \
        --arg status "failure" \
        --arg message "Response format is invalid" \
        --argjson errors "$errors_json" \
        --argjson details "$(jq -n \
            --argjson has_status "$has_status" \
            --argjson has_message "$has_message" \
            --arg response_status "$response_status" \
            '{has_status: $has_status, has_message: $has_message, response_status: $response_status}')" \
        '{status: $status, message: $message, details: $details, errors: $errors}')
    echo "$result"
    exit 1
fi
