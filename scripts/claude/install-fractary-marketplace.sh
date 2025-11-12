#!/bin/bash
###############################################################################
# install-fractary-marketplace.sh
#
# Purpose: Automatically install the fractary/claude-plugins marketplace
#          when Claude Code sessions start in fresh environments.
#
# Usage: Called automatically via SessionStart hook in .claude/settings.json
#
# Author: Fractary team
# Issue: https://github.com/fractary/claude-plugins/issues/84
###############################################################################

set -euo pipefail

# Configuration
MARKETPLACE_REPO="fractary/claude-plugins"
MARKETPLACE_NAME="fractary"
LOG_PREFIX="[Fractary Marketplace Installer]"

# Logging functions
log_info() {
    echo "$LOG_PREFIX INFO: $*" >&2
}

log_error() {
    echo "$LOG_PREFIX ERROR: $*" >&2
}

log_success() {
    echo "$LOG_PREFIX SUCCESS: $*" >&2
}

# Check if marketplace is already installed
is_marketplace_installed() {
    # Check if the marketplace appears in the installed list
    # We use the /plugin command output or check for the marketplace in config
    if claude plugin marketplace list 2>/dev/null | grep -q "$MARKETPLACE_NAME"; then
        return 0
    fi
    return 1
}

# Main installation logic
main() {
    log_info "Starting fractary marketplace installation check..."

    # Check if marketplace is already installed
    if is_marketplace_installed; then
        log_info "Marketplace '$MARKETPLACE_NAME' is already installed. Skipping installation."

        # Output context for Claude
        if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
            echo "export FRACTARY_MARKETPLACE_STATUS=installed" >> "$CLAUDE_ENV_FILE"
        fi

        # Return success context for Claude Code
        cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Fractary marketplace already installed and ready. All fractary plugins are available."
  }
}
EOF
        exit 0
    fi

    log_info "Marketplace '$MARKETPLACE_NAME' not found. Installing..."

    # Install the marketplace
    if claude plugin marketplace add "$MARKETPLACE_REPO" 2>&1 | tee /tmp/marketplace-install.log; then
        log_success "Marketplace '$MARKETPLACE_NAME' installed successfully!"

        # Set environment variable
        if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
            echo "export FRACTARY_MARKETPLACE_STATUS=newly_installed" >> "$CLAUDE_ENV_FILE"
        fi

        # Return success context for Claude Code
        cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Fractary marketplace successfully installed. All fractary plugins (faber, work, repo, file, codex, docs, logs, spec, faber-cloud) are now available for use."
  }
}
EOF
        exit 0
    else
        log_error "Failed to install marketplace '$MARKETPLACE_NAME'"
        log_error "Installation log: $(cat /tmp/marketplace-install.log 2>/dev/null || echo 'N/A')"

        # Set error status
        if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
            echo "export FRACTARY_MARKETPLACE_STATUS=failed" >> "$CLAUDE_ENV_FILE"
        fi

        # Return error context for Claude Code
        cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "WARNING: Fractary marketplace installation failed. Manual installation may be required. Run: /plugin marketplace add $MARKETPLACE_REPO"
  }
}
EOF
        exit 1
    fi
}

# Execute main function
main "$@"
