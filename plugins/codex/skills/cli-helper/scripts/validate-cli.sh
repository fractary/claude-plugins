#!/bin/bash
# Validate fractary CLI installation and version
#
# Returns JSON with installation status and version info
# Exit codes: 0 = CLI available, 1 = CLI not available

set -euo pipefail

# Check for CLI availability
CLI_AVAILABLE=false
CLI_VERSION=""
CLI_SOURCE=""
NPX_AVAILABLE=false

# Check global installation
if command -v fractary &> /dev/null; then
    CLI_AVAILABLE=true
    CLI_SOURCE="global"
    CLI_VERSION=$(fractary --version 2>/dev/null || echo "unknown")
fi

# Check npx availability as fallback
if command -v npx &> /dev/null; then
    NPX_AVAILABLE=true
    if [ "$CLI_AVAILABLE" = false ]; then
        CLI_SOURCE="npx"
        # Try to get version via npx (may download package)
        CLI_VERSION=$(npx --yes @fractary/cli --version 2>/dev/null || echo "unknown")
        if [ "$CLI_VERSION" != "unknown" ]; then
            CLI_AVAILABLE=true
        fi
    fi
fi

# Build JSON response
if [ "$CLI_AVAILABLE" = true ]; then
    cat <<EOF
{
  "status": "success",
  "cli_available": true,
  "cli_source": "$CLI_SOURCE",
  "cli_version": "$CLI_VERSION",
  "npx_available": $NPX_AVAILABLE,
  "message": "Fractary CLI is available via $CLI_SOURCE"
}
EOF
    exit 0
else
    cat <<EOF
{
  "status": "failure",
  "cli_available": false,
  "cli_source": "none",
  "cli_version": null,
  "npx_available": $NPX_AVAILABLE,
  "message": "Fractary CLI not available",
  "suggested_fixes": [
    "Install globally: npm install -g @fractary/cli",
    "Or ensure npx is available (comes with npm 5.2+)"
  ]
}
EOF
    exit 1
fi
