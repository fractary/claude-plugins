#!/bin/bash
# Work Initializer: GitHub Credential Validator
# Validates GitHub token and repository access

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
Usage: $0 <owner> <repo> <token>

Validates GitHub token and repository access.

Arguments:
  owner                 Repository owner
  repo                  Repository name
  token                 GitHub Personal Access Token

Exit Codes:
  0  - Success (token valid and repository accessible)
  11 - Authentication failed (invalid token)
  10 - Repository not found or no access
  12 - Network error

Examples:
  $0 myorg myproject ghp_xxxxx

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

warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

error() {
    echo -e "${RED}✗${NC} $*" >&2
}

# Validate token with GitHub API
validate_token() {
    local token="$1"

    info "Validating GitHub token..."

    # Try using gh CLI first (preferred)
    if command -v gh >/dev/null 2>&1; then
        # Set token for gh CLI
        export GH_TOKEN="$token"

        # Check auth status
        if gh auth status >/dev/null 2>&1; then
            success "Token is valid (verified with gh CLI)"

            # Get user info
            local user
            user=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
            info "Authenticated as: $user"

            return 0
        else
            error "Token validation failed (gh auth status failed)"
            return 11
        fi
    else
        # Fallback to direct API call
        warn "gh CLI not found, using curl for validation"

        local response
        local http_code

        response=$(curl -s -w "\n%{http_code}" \
            -H "Authorization: token $token" \
            -H "Accept: application/vnd.github.v3+json" \
            https://api.github.com/user)

        http_code=$(echo "$response" | tail -n1)
        local body
        body=$(echo "$response" | sed '$d')

        if [ "$http_code" = "200" ]; then
            success "Token is valid"

            # Extract user info
            local user
            user=$(echo "$body" | jq -r '.login' 2>/dev/null || echo "unknown")
            info "Authenticated as: $user"

            # Check scopes
            local scopes
            scopes=$(curl -sI \
                -H "Authorization: token $token" \
                https://api.github.com/user | \
                grep -i "x-oauth-scopes:" | \
                sed 's/x-oauth-scopes: //i' | \
                tr -d '\r')

            if [ -n "$scopes" ]; then
                info "Token scopes: $scopes"

                # Check for required scopes
                if [[ "$scopes" =~ repo ]] || [[ "$scopes" =~ public_repo ]]; then
                    success "Token has required repository scopes"
                else
                    warn "Token may not have required repository scopes (repo or public_repo)"
                fi
            fi

            return 0
        elif [ "$http_code" = "401" ]; then
            error "Token validation failed: Invalid or expired token"
            return 11
        elif [ "$http_code" = "403" ]; then
            error "Token validation failed: Forbidden (check token scopes)"
            return 11
        else
            error "Token validation failed: HTTP $http_code"
            return 12
        fi
    fi
}

# Validate repository access
validate_repository() {
    local owner="$1"
    local repo="$2"
    local token="$3"

    info "Validating repository access: $owner/$repo..."

    # Try using gh CLI first (preferred)
    if command -v gh >/dev/null 2>&1; then
        export GH_TOKEN="$token"

        if gh repo view "$owner/$repo" >/dev/null 2>&1; then
            success "Repository access verified: $owner/$repo"

            # Get repository info
            local repo_url
            repo_url=$(gh repo view "$owner/$repo" --json url --jq '.url' 2>/dev/null || echo "")
            if [ -n "$repo_url" ]; then
                info "Repository URL: $repo_url"
            fi

            return 0
        else
            error "Repository not found or no access: $owner/$repo"
            error "Ensure the token has access to this repository"
            return 10
        fi
    else
        # Fallback to direct API call
        local response
        local http_code

        response=$(curl -s -w "\n%{http_code}" \
            -H "Authorization: token $token" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/$owner/$repo")

        http_code=$(echo "$response" | tail -n1)
        local body
        body=$(echo "$response" | sed '$d')

        if [ "$http_code" = "200" ]; then
            success "Repository access verified: $owner/$repo"

            # Extract repository info
            local repo_url
            repo_url=$(echo "$body" | jq -r '.html_url' 2>/dev/null || echo "")
            if [ -n "$repo_url" ]; then
                info "Repository URL: $repo_url"
            fi

            return 0
        elif [ "$http_code" = "404" ]; then
            error "Repository not found: $owner/$repo"
            error "Ensure the repository exists and the token has access"
            return 10
        elif [ "$http_code" = "401" ]; then
            error "Authentication failed"
            return 11
        elif [ "$http_code" = "403" ]; then
            error "Access forbidden to repository: $owner/$repo"
            error "Ensure the token has the required scopes"
            return 10
        else
            error "Repository validation failed: HTTP $http_code"
            return 12
        fi
    fi
}

# Check gh CLI availability
check_gh_cli() {
    if command -v gh >/dev/null 2>&1; then
        local version
        version=$(gh --version | head -n1)
        success "gh CLI available: $version"
        return 0
    else
        warn "gh CLI not found"
        warn "Install gh CLI for full functionality: https://cli.github.com/"
        warn "Basic operations will still work using curl"
        return 1
    fi
}

# Main execution
main() {
    # Parse arguments
    if [ $# -ne 3 ]; then
        usage
    fi

    local owner="$1"
    local repo="$2"
    local token="$3"

    echo ""
    info "GitHub Credential Validation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Step 1: Validate token
    if ! validate_token "$token"; then
        exit $?
    fi
    echo ""

    # Step 2: Validate repository access
    if ! validate_repository "$owner" "$repo" "$token"; then
        exit $?
    fi
    echo ""

    # Step 3: Check gh CLI (non-fatal)
    check_gh_cli
    echo ""

    # Success
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    success "Validation complete"
    echo ""

    exit 0
}

# Run main
main "$@"
