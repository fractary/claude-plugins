#!/bin/bash
# Work Initializer: Jira Credential Validator
# Validates Jira API token and project access

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
Usage: $0 <url> <email> <token>

Validates Jira API token and authentication.

Arguments:
  url                   Jira instance URL (e.g., https://domain.atlassian.net)
  email                 User email address
  token                 Jira API token

Exit Codes:
  0  - Success (token valid and authenticated)
  11 - Authentication failed (invalid token)
  12 - Network error

Examples:
  $0 https://domain.atlassian.net user@example.com api_token_here

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

# Validate Jira credentials
validate_jira() {
    local url="$1"
    local email="$2"
    local token="$3"

    info "Validating Jira credentials..."

    local response
    local http_code

    # Test authentication by getting current user info
    response=$(curl -s -w "\n%{http_code}" \
        -u "$email:$token" \
        -H "Accept: application/json" \
        "$url/rest/api/3/myself")

    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        success "Jira authentication successful"

        # Extract user info
        local display_name
        display_name=$(echo "$body" | jq -r '.displayName' 2>/dev/null || echo "unknown")
        info "Authenticated as: $display_name ($email)"

        return 0
    elif [ "$http_code" = "401" ]; then
        error "Authentication failed: Invalid email or token"
        return 11
    elif [ "$http_code" = "403" ]; then
        error "Authentication failed: Access forbidden"
        return 11
    else
        error "Validation failed: HTTP $http_code"
        return 12
    fi
}

# Main execution
main() {
    # Parse arguments
    if [ $# -ne 3 ]; then
        usage
    fi

    local url="$1"
    local email="$2"
    local token="$3"

    echo ""
    info "Jira Credential Validation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Validate credentials
    if ! validate_jira "$url" "$email" "$token"; then
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
