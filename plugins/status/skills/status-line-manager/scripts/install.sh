#!/usr/bin/env bash
# install.sh - Installs status line hooks and scripts in current project
# Part of fractary-status plugin
# Usage: bash install.sh

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

# Get plugin directory (go up from scripts/ to status-line-manager/ to skills/ to status/)
PLUGIN_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
echo -e "${CYAN}Plugin source: ${PLUGIN_SOURCE}${NC}"

# Create project directories
echo -e "${CYAN}Creating project directories...${NC}"
mkdir -p .claude/status/scripts
mkdir -p .fractary/plugins/status

# Copy scripts to project
echo -e "${CYAN}Copying scripts...${NC}"
cp "$PLUGIN_SOURCE/skills/status-line-manager/scripts/status-line.sh" .claude/status/scripts/
cp "$PLUGIN_SOURCE/skills/status-line-manager/scripts/capture-prompt.sh" .claude/status/scripts/
chmod +x .claude/status/scripts/*.sh

echo -e "${GREEN}✓ Scripts installed to .claude/status/scripts/${NC}"

# Configure hooks in .claude/settings.json
SETTINGS_FILE=".claude/settings.json"

echo -e "${CYAN}Configuring hooks...${NC}"

# Initialize settings file if it doesn't exist
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Read existing settings
EXISTING_SETTINGS=$(cat "$SETTINGS_FILE")

# Create hooks configuration using jq
NEW_SETTINGS=$(echo "$EXISTING_SETTINGS" | jq '
  # Add StatusLine hook
  .statusLine = {
    "type": "command",
    "command": "bash .claude/status/scripts/status-line.sh"
  } |
  # Add UserPromptSubmit hook
  .hooks.UserPromptSubmit = (
    (.hooks.UserPromptSubmit // []) + [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "bash .claude/status/scripts/capture-prompt.sh"
      }]
    }] | unique_by(.matcher)
  )
')

# Write updated settings
echo "$NEW_SETTINGS" > "$SETTINGS_FILE"

echo -e "${GREEN}✓ Hooks configured in .claude/settings.json${NC}"

# Create plugin configuration
echo -e "${CYAN}Creating plugin configuration...${NC}"
cat > .fractary/plugins/status/config.json <<EOF
{
  "version": "1.0.0",
  "installed": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "scripts_path": ".claude/status/scripts",
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
echo -e "Installed components:"
echo -e "  ${CYAN}•${NC} Status line script: .claude/status/scripts/status-line.sh"
echo -e "  ${CYAN}•${NC} Prompt capture script: .claude/status/scripts/capture-prompt.sh"
echo -e "  ${CYAN}•${NC} StatusLine hook configured"
echo -e "  ${CYAN}•${NC} UserPromptSubmit hook configured"
echo ""
echo -e "${YELLOW}Note:${NC} Restart Claude Code to activate the status line"
echo ""
echo -e "Status line format:"
echo -e "  ${CYAN}[branch] ${YELLOW}[±files]${NC} ${MAGENTA}[#issue]${NC} ${BLUE}[PR#pr]${NC} ${GREEN}[↑ahead]${NC} ${RED}[↓behind]${NC} last: prompt..."
echo ""

exit 0
