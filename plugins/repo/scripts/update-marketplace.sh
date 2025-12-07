#!/bin/bash

# Update Fractary Marketplace
# This script updates the fractary marketplace by pulling latest from GitHub
# Used by SessionStart hook to keep plugins up-to-date
#
# Exit codes:
#   0 - Success (updated or already up-to-date)
#   0 - Failure (non-blocking, allows session to start)
#
# Note: This script never returns non-zero to avoid blocking session startup

set -o pipefail

# Configuration
MARKETPLACE_NAME="${1:-fractary}"
MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/${MARKETPLACE_NAME}"
QUIET_MODE=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --quiet)
            QUIET_MODE=true
            ;;
    esac
done

# Helper function for output
log() {
    if [ "$QUIET_MODE" = false ]; then
        echo "$1"
    fi
}

# Check if marketplace directory exists
if [ ! -d "$MARKETPLACE_DIR" ]; then
    log "Marketplace '$MARKETPLACE_NAME' not installed at $MARKETPLACE_DIR"
    exit 0
fi

# Check if it's a git repository
if [ ! -d "$MARKETPLACE_DIR/.git" ]; then
    log "Marketplace '$MARKETPLACE_NAME' is not a git repository, skipping update"
    exit 0
fi

# Change to marketplace directory
cd "$MARKETPLACE_DIR" || exit 0

# Check for network connectivity (quick test)
if ! git ls-remote --exit-code origin HEAD >/dev/null 2>&1; then
    log "Cannot reach remote, skipping marketplace update"
    exit 0
fi

# Get current commit before update
BEFORE_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Fetch and pull latest changes
# Using --ff-only to avoid merge conflicts
if git fetch --quiet origin 2>/dev/null; then
    # Check if there are updates
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null)

    if [ "$LOCAL" != "$REMOTE" ]; then
        # Try to fast-forward
        if git pull --ff-only --quiet origin 2>/dev/null; then
            AFTER_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
            log "Updated marketplace '$MARKETPLACE_NAME': $BEFORE_COMMIT -> $AFTER_COMMIT"
        else
            log "Marketplace has local changes, skipping update"
        fi
    else
        log "Marketplace '$MARKETPLACE_NAME' is up-to-date"
    fi
else
    log "Failed to fetch updates, continuing with current version"
fi

exit 0
