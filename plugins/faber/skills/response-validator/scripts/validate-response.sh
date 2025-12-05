#!/usr/bin/env bash
# validate-response.sh - Validates skill responses against FABER response format schema
#
# Usage: ./validate-response.sh '<response_json>' [--strict]
#
# Arguments:
#   response_json  The response object to validate (JSON string)
#   --strict       Enable strict validation (default: lenient)
#
# Exit codes:
#   0 - Validation passed
#   1 - Validation failed
#   2 - Invalid arguments
#   3 - JSON parse error

set -euo pipefail

# Colors for output (disabled if not TTY)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo '{"status":"failure","message":"jq is required but not installed","errors":["Missing dependency: jq"]}' >&2
    exit 3
fi

# Parse arguments
RESPONSE_JSON=""
STRICT_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --strict)
            STRICT_MODE=true
            shift
            ;;
        *)
            if [[ -z "$RESPONSE_JSON" ]]; then
                RESPONSE_JSON="$1"
            else
                echo '{"status":"failure","message":"Too many arguments","errors":["Usage: validate-response.sh <response_json> [--strict]"]}' >&2
                exit 2
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [[ -z "$RESPONSE_JSON" ]]; then
    echo '{"status":"failure","message":"Missing required argument","errors":["Usage: validate-response.sh <response_json> [--strict]"]}' >&2
    exit 2
fi

# Parse JSON to verify it's valid
if ! echo "$RESPONSE_JSON" | jq . > /dev/null 2>&1; then
    echo '{"status":"failure","message":"Invalid JSON input","errors":["Could not parse response as JSON"],"suggested_fixes":["Ensure response is valid JSON format"]}' >&2
    exit 3
fi

# Initialize validation results
errors=()
warnings=()

# Get response fields
status=$(echo "$RESPONSE_JSON" | jq -r '.status // empty')
message=$(echo "$RESPONSE_JSON" | jq -r '.message // empty')
has_errors=$(echo "$RESPONSE_JSON" | jq 'has("errors")')
has_warnings=$(echo "$RESPONSE_JSON" | jq 'has("warnings")')
errors_count=$(echo "$RESPONSE_JSON" | jq '.errors | if type == "array" then length else 0 end')
warnings_count=$(echo "$RESPONSE_JSON" | jq '.warnings | if type == "array" then length else 0 end')

# Count validated fields
fields_validated=0

# Validate required: status
if [[ -z "$status" ]]; then
    errors+=("Missing required field: 'status'")
elif [[ "$status" != "success" && "$status" != "warning" && "$status" != "failure" ]]; then
    errors+=("Invalid status value: '$status'. Must be 'success', 'warning', or 'failure'")
else
    ((fields_validated++))
fi

# Validate required: message
if [[ -z "$message" ]]; then
    if [[ "$STRICT_MODE" == "true" ]]; then
        errors+=("Missing required field: 'message'")
    else
        warnings+=("Missing recommended field: 'message'")
    fi
else
    ((fields_validated++))
fi

# Validate conditional: errors[] when status=failure
if [[ "$status" == "failure" ]]; then
    if [[ "$has_errors" != "true" ]]; then
        if [[ "$STRICT_MODE" == "true" ]]; then
            errors+=("Field 'errors' is required when status is 'failure'")
        else
            warnings+=("Field 'errors' is recommended when status is 'failure'")
        fi
    elif [[ "$errors_count" -eq 0 ]]; then
        if [[ "$STRICT_MODE" == "true" ]]; then
            errors+=("Field 'errors' must contain at least one error message")
        else
            warnings+=("Field 'errors' should contain at least one error message")
        fi
    else
        ((fields_validated++))
    fi
fi

# Validate conditional: warnings[] when status=warning
if [[ "$status" == "warning" ]]; then
    if [[ "$has_warnings" != "true" ]]; then
        if [[ "$STRICT_MODE" == "true" ]]; then
            errors+=("Field 'warnings' is required when status is 'warning'")
        else
            warnings+=("Field 'warnings' is recommended when status is 'warning'")
        fi
    elif [[ "$warnings_count" -eq 0 ]]; then
        if [[ "$STRICT_MODE" == "true" ]]; then
            errors+=("Field 'warnings' must contain at least one warning message")
        else
            warnings+=("Field 'warnings' should contain at least one warning message")
        fi
    else
        ((fields_validated++))
    fi
fi

# Validate optional field types if present
if echo "$RESPONSE_JSON" | jq -e '.details != null' > /dev/null 2>&1; then
    if ! echo "$RESPONSE_JSON" | jq -e '.details | type == "object"' > /dev/null 2>&1; then
        errors+=("Field 'details' must be an object")
    else
        ((fields_validated++))
    fi
fi

if echo "$RESPONSE_JSON" | jq -e '.error_analysis != null' > /dev/null 2>&1; then
    if ! echo "$RESPONSE_JSON" | jq -e '.error_analysis | type == "string"' > /dev/null 2>&1; then
        errors+=("Field 'error_analysis' must be a string")
    else
        ((fields_validated++))
    fi
fi

if echo "$RESPONSE_JSON" | jq -e '.warning_analysis != null' > /dev/null 2>&1; then
    if ! echo "$RESPONSE_JSON" | jq -e '.warning_analysis | type == "string"' > /dev/null 2>&1; then
        errors+=("Field 'warning_analysis' must be a string")
    else
        ((fields_validated++))
    fi
fi

if echo "$RESPONSE_JSON" | jq -e '.suggested_fixes != null' > /dev/null 2>&1; then
    if ! echo "$RESPONSE_JSON" | jq -e '.suggested_fixes | type == "array"' > /dev/null 2>&1; then
        errors+=("Field 'suggested_fixes' must be an array")
    else
        ((fields_validated++))
    fi
fi

# Build suggested fixes
suggested_fixes=()
for err in "${errors[@]}"; do
    case "$err" in
        *"Missing required field: 'status'"*)
            suggested_fixes+=("Add 'status' field with value 'success', 'warning', or 'failure'")
            ;;
        *"Missing required field: 'message'"*)
            suggested_fixes+=("Add 'message' field with a human-readable summary")
            ;;
        *"'errors' is required when status is 'failure'"*)
            suggested_fixes+=("Add 'errors' array with at least one error message describing what failed")
            ;;
        *"'warnings' is required when status is 'warning'"*)
            suggested_fixes+=("Add 'warnings' array with at least one warning message describing the concern")
            ;;
    esac
done

# Build result JSON
mode="lenient"
if [[ "$STRICT_MODE" == "true" ]]; then
    mode="strict"
fi

if [[ ${#errors[@]} -gt 0 ]]; then
    # Validation failed
    errors_json=$(printf '%s\n' "${errors[@]}" | jq -R . | jq -s .)
    fixes_json="[]"
    if [[ ${#suggested_fixes[@]} -gt 0 ]]; then
        fixes_json=$(printf '%s\n' "${suggested_fixes[@]}" | jq -R . | jq -s .)
    fi

    result=$(jq -n \
        --arg status "failure" \
        --arg message "Response validation failed - ${#errors[@]} error(s) found" \
        --argjson errors "$errors_json" \
        --arg error_analysis "The response object does not conform to the standard FABER response format schema" \
        --argjson suggested_fixes "$fixes_json" \
        --argjson details "$(jq -n --argjson valid false --arg mode "$mode" --argjson error_count "${#errors[@]}" '{valid: $valid, mode: $mode, error_count: $error_count}')" \
        '{status: $status, message: $message, details: $details, errors: $errors, error_analysis: $error_analysis, suggested_fixes: $suggested_fixes}')

    echo "$result"
    exit 1
elif [[ ${#warnings[@]} -gt 0 ]]; then
    # Validation passed with warnings
    warnings_json=$(printf '%s\n' "${warnings[@]}" | jq -R . | jq -s .)

    result=$(jq -n \
        --arg status "warning" \
        --arg message "Response validation passed with ${#warnings[@]} warning(s)" \
        --argjson warnings "$warnings_json" \
        --arg warning_analysis "The response is valid but could be improved" \
        --argjson details "$(jq -n --argjson valid true --arg mode "$mode" --argjson fields_validated "$fields_validated" --argjson warning_count "${#warnings[@]}" '{valid: $valid, mode: $mode, fields_validated: $fields_validated, warning_count: $warning_count}')" \
        '{status: $status, message: $message, details: $details, warnings: $warnings, warning_analysis: $warning_analysis}')

    echo "$result"
    exit 0
else
    # Validation passed
    result=$(jq -n \
        --arg status "success" \
        --arg message "Response validation passed" \
        --argjson details "$(jq -n --argjson valid true --arg mode "$mode" --argjson fields_validated "$fields_validated" '{valid: $valid, mode: $mode, fields_validated: $fields_validated}')" \
        '{status: $status, message: $message, details: $details}')

    echo "$result"
    exit 0
fi
