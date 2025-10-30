#!/bin/bash
# Work Initializer: Linear Credential Validator
# Validates Linear API key

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage
usage() {
    cat <<EOF
Usage: $0 <token>

Validates Linear API key.

Arguments:
  token                 Linear API key

Exit Codes:
  0  - Success (API key valid)
  11 - Authentication failed (invalid API key)
  12 - Network error

Examples:
  $0 lin_api_xxxxx

EOF
    exit 2
}

# Logging functions
info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
}

error() {
    echo -e "${RED}✗${NC} $*" >&2
}

# Validate Linear API key
validate_linear() {
    local token="$1"

    info "Validating Linear API key..."

    local response
    local http_code

    # GraphQL query to get current user
    local query='{"query": "{ viewer { id name email } }"}'

    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: $token" \
        -H "Content-Type: application/json" \
        -d "$query" \
        https://api.linear.app/graphql)

    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        # Check for errors in GraphQL response
        local errors
        errors=$(echo "$body" | jq -r '.errors' 2>/dev/null || echo "null")

        if [ "$errors" != "null" ]; then
            error "Authentication failed: Invalid API key"
            return 11
        fi

        success "Linear API key is valid"

        # Extract user info
        local user_name
        local user_email
        user_name=$(echo "$body" | jq -r '.data.viewer.name' 2>/dev/null || echo "unknown")
        user_email=$(echo "$body" | jq -r '.data.viewer.email' 2>/dev/null || echo "unknown")
        info "Authenticated as: $user_name ($user_email)"

        return 0
    elif [ "$http_code" = "401" ]; then
        error "Authentication failed: Invalid API key"
        return 11
    else
        error "Validation failed: HTTP $http_code"
        return 12
    fi
}

# Main execution
main() {
    # Parse arguments
    if [ $# -ne 1 ]; then
        usage
    fi

    local token="$1"

    echo ""
    info "Linear Credential Validation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Validate API key
    if ! validate_linear "$token"; then
        exit $?
    fi
    echo ""

    # Success
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    success "Validation complete"
    echo ""

    exit 0
}

# Run main
main "$@"
