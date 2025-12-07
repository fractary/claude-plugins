#!/bin/bash

# Bootstrap and Update Fractary Marketplace
# This script ensures the fractary marketplace is installed and up-to-date
# Used by SessionStart hook to enable plugins in fresh environments
#
# Behavior:
#   1. If marketplace not installed → clone from GitHub (bootstrap)
#   2. If marketplace installed → pull latest changes (update)
#
# Exit codes:
#   0 - Success (installed, updated, or already up-to-date)
#   0 - Failure (non-blocking, allows session to start)
#
# Note: This script never returns non-zero to avoid blocking session startup

set -o pipefail

# =============================================================================
# Configuration
# =============================================================================

# Default marketplace configuration
MARKETPLACE_NAME="${1:-fractary}"
MARKETPLACE_REPO="fractary/claude-plugins"
MARKETPLACE_BRANCH="main"

# Derived paths
MARKETPLACES_BASE="$HOME/.claude/plugins/marketplaces"
MARKETPLACE_DIR="${MARKETPLACES_BASE}/${MARKETPLACE_NAME}"

# Options
QUIET_MODE=false

# =============================================================================
# Argument Parsing
# =============================================================================

# Parse arguments (skip first arg which is marketplace name)
for arg in "$@"; do
    case "$arg" in
        --quiet)
            QUIET_MODE=true
            ;;
        --repo=*)
            MARKETPLACE_REPO="${arg#*=}"
            ;;
        --branch=*)
            MARKETPLACE_BRANCH="${arg#*=}"
            ;;
    esac
done

# =============================================================================
# Helper Functions
# =============================================================================

log() {
    if [ "$QUIET_MODE" = false ]; then
        echo "$1"
    fi
}

log_error() {
    if [ "$QUIET_MODE" = false ]; then
        echo "$1" >&2
    fi
}

# Check network connectivity to GitHub
check_network() {
    # Quick connectivity test - try to reach GitHub
    if command -v curl &> /dev/null; then
        curl -s --connect-timeout 3 --max-time 5 "https://github.com" > /dev/null 2>&1
        return $?
    elif command -v wget &> /dev/null; then
        wget -q --timeout=3 --tries=1 -O /dev/null "https://github.com" 2>&1
        return $?
    else
        # Fallback: try git ls-remote (slower but works)
        git ls-remote --exit-code "https://github.com/${MARKETPLACE_REPO}.git" HEAD >/dev/null 2>&1
        return $?
    fi
}

# =============================================================================
# Bootstrap: Install marketplace if not present
# =============================================================================

bootstrap_marketplace() {
    log "Marketplace '$MARKETPLACE_NAME' not found, bootstrapping..."

    # Check network connectivity first
    if ! check_network; then
        log_error "Cannot reach GitHub, skipping marketplace bootstrap"
        return 1
    fi

    # Ensure base directory exists
    if ! mkdir -p "$MARKETPLACES_BASE" 2>/dev/null; then
        log_error "Failed to create marketplaces directory: $MARKETPLACES_BASE"
        return 1
    fi

    # Clone the marketplace repository
    local CLONE_URL="https://github.com/${MARKETPLACE_REPO}.git"
    log "Cloning marketplace from $CLONE_URL..."

    if git clone --quiet --depth 1 --branch "$MARKETPLACE_BRANCH" "$CLONE_URL" "$MARKETPLACE_DIR" 2>/dev/null; then
        log "Successfully installed marketplace '$MARKETPLACE_NAME'"
        return 0
    else
        log_error "Failed to clone marketplace repository"
        # Clean up partial clone if it exists
        rm -rf "$MARKETPLACE_DIR" 2>/dev/null || true
        return 1
    fi
}

# =============================================================================
# Update: Pull latest changes for existing marketplace
# =============================================================================

update_marketplace() {
    # Verify it's a git repository
    if [ ! -d "$MARKETPLACE_DIR/.git" ]; then
        log "Marketplace '$MARKETPLACE_NAME' is not a git repository, skipping update"
        return 0
    fi

    # Change to marketplace directory
    cd "$MARKETPLACE_DIR" || return 0

    # Check for network connectivity
    if ! git ls-remote --exit-code origin HEAD >/dev/null 2>&1; then
        log "Cannot reach remote, skipping marketplace update"
        return 0
    fi

    # Get current commit before update
    local BEFORE_COMMIT
    BEFORE_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

    # Fetch latest changes
    if ! git fetch --quiet origin 2>/dev/null; then
        log "Failed to fetch updates, continuing with current version"
        return 0
    fi

    # Check if there are updates available
    local LOCAL REMOTE
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse "origin/${MARKETPLACE_BRANCH}" 2>/dev/null || git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null)

    if [ -z "$REMOTE" ]; then
        log "Could not determine remote branch, skipping update"
        return 0
    fi

    if [ "$LOCAL" = "$REMOTE" ]; then
        log "Marketplace '$MARKETPLACE_NAME' is up-to-date"
        return 0
    fi

    # Try to fast-forward (avoids merge conflicts)
    if git pull --ff-only --quiet origin "$MARKETPLACE_BRANCH" 2>/dev/null; then
        local AFTER_COMMIT
        AFTER_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        log "Updated marketplace '$MARKETPLACE_NAME': $BEFORE_COMMIT -> $AFTER_COMMIT"
    else
        log "Marketplace has local changes, skipping update"
    fi

    return 0
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    # Check if marketplace directory exists
    if [ ! -d "$MARKETPLACE_DIR" ]; then
        # Bootstrap: Install the marketplace
        if ! bootstrap_marketplace; then
            # Bootstrap failed, but don't block session startup
            log_error "Marketplace bootstrap failed, plugins may not be available"
            exit 0
        fi
    fi

    # Update: Pull latest changes
    update_marketplace

    exit 0
}

# Run main function
main
