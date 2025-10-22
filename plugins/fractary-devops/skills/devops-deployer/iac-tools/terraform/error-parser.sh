#!/bin/bash
# terraform/error-parser.sh
# Parse Terraform errors into categories

set -euo pipefail

# Parse Terraform error output and categorize
parse_terraform_error() {
    local error_output="$1"

    # Extract error messages
    local errors=$(echo "$error_output" | grep -E "^Error:|^│ Error:" || true)

    if [ -z "$errors" ]; then
        echo "No Terraform errors found in output"
        return 0
    fi

    # Categorize errors
    local permission_errors=()
    local configuration_errors=()
    local resource_errors=()
    local state_errors=()
    local unknown_errors=()

    while IFS= read -r error_line; do
        categorize_error "$error_line"
    done <<< "$errors"

    # Display categorized errors
    display_categorized_errors
}

# Categorize individual error
categorize_error() {
    local error="$1"

    # Permission/authentication errors
    if echo "$error" | grep -qiE "AccessDenied|Unauthorized|Forbidden|InvalidClientTokenId|SignatureDoesNotMatch|is not authorized to perform"; then
        permission_errors+=("$error")

    # Configuration errors
    elif echo "$error" | grep -qiE "Invalid|ValidationError|Malformed|required field|missing required|InvalidParameterValue"; then
        configuration_errors+=("$error")

    # Resource errors
    elif echo "$error" | grep -qiE "AlreadyExists|ResourceInUseException|Conflict|DependencyViolation|ResourceNotFoundException"; then
        resource_errors+=("$error")

    # State errors
    elif echo "$error" | grep -qiE "state lock|state file|NoSuchBucket|AccessDenied.*state"; then
        state_errors+=("$error")

    # Unknown errors
    else
        unknown_errors+=("$error")
    fi
}

# Display categorized errors
display_categorized_errors() {
    local total_errors=0

    if [ ${#permission_errors[@]} -gt 0 ]; then
        echo ""
        echo "=== Permission Errors (${#permission_errors[@]}) ==="
        for err in "${permission_errors[@]}"; do
            echo "$err"
        done
        total_errors=$((total_errors + ${#permission_errors[@]}))
    fi

    if [ ${#configuration_errors[@]} -gt 0 ]; then
        echo ""
        echo "=== Configuration Errors (${#configuration_errors[@]}) ==="
        for err in "${configuration_errors[@]}"; do
            echo "$err"
        done
        total_errors=$((total_errors + ${#configuration_errors[@]}))
    fi

    if [ ${#resource_errors[@]} -gt 0 ]; then
        echo ""
        echo "=== Resource Errors (${#resource_errors[@]}) ==="
        for err in "${resource_errors[@]}"; do
            echo "$err"
        done
        total_errors=$((total_errors + ${#resource_errors[@]}))
    fi

    if [ ${#state_errors[@]} -gt 0 ]; then
        echo ""
        echo "=== State Errors (${#state_errors[@]}) ==="
        for err in "${state_errors[@]}"; do
            echo "$err"
        done
        total_errors=$((total_errors + ${#state_errors[@]}))
    fi

    if [ ${#unknown_errors[@]} -gt 0 ]; then
        echo ""
        echo "=== Unknown Errors (${#unknown_errors[@]}) ==="
        for err in "${unknown_errors[@]}"; do
            echo "$err"
        done
        total_errors=$((total_errors + ${#unknown_errors[@]}))
    fi

    echo ""
    echo "Total errors: $total_errors"
}

# Extract permission from error message
extract_permission_from_error() {
    local error="$1"

    # Extract service:Action from "is not authorized to perform: service:Action"
    if echo "$error" | grep -qE "is not authorized to perform"; then
        echo "$error" | grep -oE "[a-z0-9]+:[A-Za-z0-9*]+" | head -1
        return 0
    fi

    # Extract from AccessDenied messages
    if echo "$error" | grep -qE "AccessDenied"; then
        # Try to extract service from resource ARN or error context
        echo "$error" | grep -oE "arn:aws:[a-z0-9-]+:" | head -1 | cut -d: -f3 || echo "unknown"
        return 0
    fi

    echo ""
    return 1
}

# Check if error is a permission error
is_permission_error() {
    local error="$1"

    if echo "$error" | grep -qiE "AccessDenied|Unauthorized|Forbidden|is not authorized to perform"; then
        return 0
    else
        return 1
    fi
}

# Check if error is a configuration error
is_configuration_error() {
    local error="$1"

    if echo "$error" | grep -qiE "Invalid|ValidationError|Malformed|required field|missing required"; then
        return 0
    else
        return 1
    fi
}
