#!/usr/bin/env bash
# install.sh - Installs status plugin configuration in current project
# Part of fractary-status plugin
# Usage: bash install.sh
#
# Note: Hooks and scripts are managed at plugin level. This script only
# creates project-specific configuration.

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}Installing Fractary Status Line Plugin...${NC}"

# Get project root (must be in git repo)
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo -e "${RED}Error: Not in a git repository${NC}"
  exit 1
fi

PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT"

# Create plugin configuration directory
echo -e "${CYAN}Creating plugin configuration...${NC}"
mkdir -p .fractary/plugins/status

# Create plugin configuration
cat > .fractary/plugins/status/config.json <<EOF
{
  "version": "1.0.0",
  "installed": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "cache_path": ".fractary/plugins/status"
}
EOF

echo -e "${GREEN}✓ Plugin configuration created${NC}"

# Configure statusLine in .claude/settings.json
echo -e "${CYAN}Configuring status line in .claude/settings.json...${NC}"
mkdir -p .claude

# Determine the status line script path
# For statusLine in project settings.json, use absolute path since ${CLAUDE_PLUGIN_ROOT}
# is only available in plugin-level hooks, not project settings
# Standard plugin path: ~/.claude/plugins/marketplaces/{marketplace}/plugins/{plugin}/
STATUS_LINE_SCRIPT="~/.claude/plugins/marketplaces/fractary/plugins/status/scripts/status-line.sh"

# Create or update settings.json with statusLine configuration
if [ -f .claude/settings.json ]; then
  # Merge with existing settings.json
  jq --arg script "$STATUS_LINE_SCRIPT" '. + {
    "statusLine": {
      "type": "command",
      "command": $script
    }
  }' .claude/settings.json > .claude/settings.json.tmp && mv .claude/settings.json.tmp .claude/settings.json
  echo -e "${GREEN}✓ StatusLine configured in .claude/settings.json${NC}"
else
  # Create new settings.json with statusLine
  cat > .claude/settings.json <<EOF
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "statusLine": {
    "type": "command",
    "command": "$STATUS_LINE_SCRIPT"
  }
}
EOF
  echo -e "${GREEN}✓ Created .claude/settings.json with statusLine${NC}"
fi

# Create .gitignore in plugin directory for cache
cat > .fractary/plugins/status/.gitignore <<EOF
# Fractary status plugin - runtime cache
last-prompt.json
EOF
echo -e "${GREEN}✓ Created .gitignore for cache file${NC}"

# Summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Installation Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Plugin configuration:"
echo -e "  ${CYAN}•${NC} Configuration: .fractary/plugins/status/config.json"
echo -e "  ${CYAN}•${NC} Cache location: .fractary/plugins/status/"
echo -e "  ${CYAN}•${NC} StatusLine: .claude/settings.json"
echo -e "  ${CYAN}•${NC} Script path: $STATUS_LINE_SCRIPT"
echo ""
echo -e "${YELLOW}Plugin Components:${NC}"
echo -e "  ${CYAN}•${NC} StatusLine command: $STATUS_LINE_SCRIPT"
echo -e "  ${CYAN}•${NC} UserPromptSubmit hook (managed in plugin hooks/hooks.json)"
echo -e "  ${CYAN}•${NC} Hook scripts (use \${CLAUDE_PLUGIN_ROOT}/scripts/ in plugin hooks)"
echo ""
echo -e "${YELLOW}Note:${NC} Restart Claude Code to activate the status line"
echo ""
echo -e "Status line format:"
echo -e "  Line 1: ${CYAN}[project] branch ${YELLOW}[±files]${NC} ${MAGENTA}[#issue]${NC} ${BLUE}[PR#pr]${NC} ${GREEN}[↑ahead]${NC} ${RED}[↓behind]${NC}"
echo -e "  Line 2: ${NC}last: prompt text (up to 120 chars)..."
echo ""

exit 0
