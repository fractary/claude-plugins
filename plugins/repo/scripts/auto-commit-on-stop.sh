#!/bin/bash

# Auto-commit git changes on Claude Code stop
# This hook runs when Claude Code session ends
# Part of fractary-repo plugin - respects configured source control provider
# Note: Only commits locally; use /fractary-repo:push to push changes

# Skip execution if running as a sub-agent
if [ -n "$CLAUDE_SUB_AGENT" ] || [ -n "$CLAUDE_AGENT_NAME" ]; then
    exit 0
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔄 Checking for git changes...${NC}"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Not in a git repository${NC}"
    exit 0
fi

# Check for changes
if git diff-index --quiet HEAD -- && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo -e "${GREEN}✅ No changes to commit${NC}"
    exit 0
fi

# Show current status
echo -e "${YELLOW}📊 Git status:${NC}"
git status --short

# Attempt to use fractary-repo plugin commands (respects configured provider)
echo -e "${BLUE}💾 Using fractary-repo plugin to commit changes...${NC}"

# Check if we're in a Claude Code session that can invoke slash commands
if [ -n "$CLAUDE_PROJECT_DIR" ] && command -v claude &> /dev/null; then
    # Try to use the plugin's commit command (handles all providers: GitHub, GitLab, Bitbucket)
    echo -e "${YELLOW}📝 Invoking /fractary-repo:commit...${NC}"

    # Note: The /fractary-repo:commit command in auto mode will:
    # - Analyze changes and generate appropriate commit message
    # - Determine commit type automatically
    # - Include proper metadata and attribution
    # - Respect the configured source control provider
    if claude exec "/fractary-repo:commit" 2>/dev/null; then
        echo -e "${GREEN}✅ Commit created via fractary-repo plugin${NC}"
        echo -e "${GREEN}✨ Auto-commit hook completed successfully${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️  Plugin commit failed, falling back to direct git commands${NC}"
    fi
fi

# Fallback: Use direct git commands if plugin invocation unavailable or failed
echo -e "${YELLOW}ℹ️  Using direct git commands (fallback)${NC}"

# Stage all changes
echo -e "${YELLOW}📝 Staging changes...${NC}"
git add -A

# Create commit message with timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
COMMIT_MSG="Auto-commit: Claude Code session ended at ${TIMESTAMP}"

# Commit changes
echo -e "${YELLOW}💾 Committing changes...${NC}"
git commit -m "$COMMIT_MSG"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Changes committed successfully${NC}"
    echo -e "${GREEN}✨ Auto-commit hook completed${NC}"
else
    echo -e "${RED}❌ Commit failed${NC}"
    exit 1
fi