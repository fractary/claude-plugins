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

# Create .gitignore entry for cache
if [ -f .gitignore ]; then
  if ! grep -q "^.fractary/plugins/status/last-prompt.json" .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# Fractary status plugin - runtime cache" >> .gitignore
    echo ".fractary/plugins/status/last-prompt.json" >> .gitignore
    echo -e "${GREEN}✓ Added cache file to .gitignore${NC}"
  fi
fi

# Summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Installation Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Plugin configuration:"
echo -e "  ${CYAN}•${NC} Configuration: .fractary/plugins/status/config.json"
echo -e "  ${CYAN}•${NC} Cache location: .fractary/plugins/status/"
echo ""
echo -e "${YELLOW}Plugin-Level Components (Automatic):${NC}"
echo -e "  ${CYAN}•${NC} StatusLine hook (managed in plugin)"
echo -e "  ${CYAN}•${NC} UserPromptSubmit hook (managed in plugin)"
echo -e "  ${CYAN}•${NC} Scripts (in \${CLAUDE_PLUGIN_ROOT}/scripts/)"
echo ""
echo -e "${YELLOW}Note:${NC} Restart Claude Code to activate the status line"
echo ""
echo -e "Status line format:"
echo -e "  ${CYAN}[branch] ${YELLOW}[±files]${NC} ${MAGENTA}[#issue]${NC} ${BLUE}[PR#pr]${NC} ${GREEN}[↑ahead]${NC} ${RED}[↓behind]${NC} last: prompt..."
echo ""
echo -e "${CYAN}Hooks and scripts are managed at the plugin level and automatically${NC}"
echo -e "${CYAN}available when the plugin is installed. No per-project setup needed!${NC}"
echo ""

exit 0
