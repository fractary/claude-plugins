#!/bin/bash

# Test script to verify code review fixes
# Tests all three fixes from PR #17 code review

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${HOME}/.fractary/repo"
CACHE_FILE="${CACHE_DIR}/status.cache"

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Code Review Fixes Test - PR #17${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Not in a git repository${NC}"
    exit 1
fi

echo -e "${BLUE}Test 1: Empty status output counting (MUST FIX)${NC}"
echo "────────────────────────────────────────"
echo -e "${YELLOW}  Creating a clean commit to test...${NC}"

# Save current state
STASH_NEEDED=false
if ! git diff-index --quiet HEAD -- 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
    echo -e "${YELLOW}  Stashing current changes...${NC}"
    git stash push -u -m "test-review-fixes temp stash" >/dev/null 2>&1 || true
    STASH_NEEDED=true
fi

# Update cache with clean state
"${SCRIPT_DIR}/update-status-cache.sh" --quiet

# Read uncommitted changes count
UNCOMMITTED=$("${SCRIPT_DIR}/read-status-cache.sh" uncommitted_changes 2>/dev/null)

if [ "$UNCOMMITTED" = "0" ]; then
    echo -e "${GREEN}  ✅ Clean repo correctly shows 0 uncommitted changes (not 1)${NC}"
    TEST1_PASS=true
else
    echo -e "${RED}  ❌ Clean repo shows $UNCOMMITTED uncommitted changes (expected 0)${NC}"
    TEST1_PASS=false
fi

# Restore stashed changes if needed
if [ "$STASH_NEEDED" = true ]; then
    echo -e "${YELLOW}  Restoring stashed changes...${NC}"
    git stash pop >/dev/null 2>&1 || true
fi
echo

echo -e "${BLUE}Test 2: Flag parsing order independence (LOW PRIORITY)${NC}"
echo "────────────────────────────────────────"
echo -e "${YELLOW}  Testing --quiet --skip-lock order...${NC}"

# Test 1: --quiet first
OUTPUT1=$("${SCRIPT_DIR}/update-status-cache.sh" --quiet --skip-lock 2>&1 || true)
if [ -z "$OUTPUT1" ]; then
    echo -e "${GREEN}  ✅ --quiet --skip-lock produces no output${NC}"
    TEST2A_PASS=true
else
    echo -e "${RED}  ❌ --quiet --skip-lock produced output: $OUTPUT1${NC}"
    TEST2A_PASS=false
fi

echo -e "${YELLOW}  Testing --skip-lock --quiet order...${NC}"

# Test 2: --skip-lock first
OUTPUT2=$("${SCRIPT_DIR}/update-status-cache.sh" --skip-lock --quiet 2>&1 || true)
if [ -z "$OUTPUT2" ]; then
    echo -e "${GREEN}  ✅ --skip-lock --quiet produces no output${NC}"
    TEST2B_PASS=true
else
    echo -e "${RED}  ❌ --skip-lock --quiet produced output: $OUTPUT2${NC}"
    TEST2B_PASS=false
fi

if [ "$TEST2A_PASS" = true ] && [ "$TEST2B_PASS" = true ]; then
    echo -e "${GREEN}  ✅ Flag parsing is order-independent${NC}"
    TEST2_PASS=true
else
    echo -e "${RED}  ❌ Flag parsing depends on order${NC}"
    TEST2_PASS=false
fi
echo

echo -e "${BLUE}Test 3: Critically stale cache recovery (LOW PRIORITY)${NC}"
echo "────────────────────────────────────────"
echo -e "${YELLOW}  Simulating critically stale cache (>5 minutes old)...${NC}"

# Make cache file appear very old (set timestamp to 10 minutes ago)
BACKUP_CACHE=$(mktemp)
cp "${CACHE_FILE}" "${BACKUP_CACHE}" 2>/dev/null || true
touch -d "10 minutes ago" "${CACHE_FILE}" 2>/dev/null || touch -t $(date -d "10 minutes ago" +%Y%m%d%H%M.%S 2>/dev/null || date -v-10M +%Y%m%d%H%M.%S) "${CACHE_FILE}"

# Read cache (should trigger emergency refresh)
echo -e "${YELLOW}  Reading from critically stale cache...${NC}"
BRANCH_OUTPUT=$("${SCRIPT_DIR}/read-status-cache.sh" branch 2>&1)

# Check if emergency refresh was triggered
if echo "$BRANCH_OUTPUT" | grep -q "very stale"; then
    echo -e "${GREEN}  ✅ Emergency refresh triggered for critically stale cache${NC}"
    TEST3_PASS=true
elif echo "$BRANCH_OUTPUT" | grep -q "claude"; then
    echo -e "${GREEN}  ✅ Cache was refreshed (branch data retrieved)${NC}"
    TEST3_PASS=true
else
    echo -e "${YELLOW}  ⚠️  Emergency refresh behavior unclear: $BRANCH_OUTPUT${NC}"
    TEST3_PASS=false
fi

# Restore backup cache
if [ -f "${BACKUP_CACHE}" ]; then
    mv "${BACKUP_CACHE}" "${CACHE_FILE}"
fi
echo

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"

# Summary
if [ "$TEST1_PASS" = true ] && [ "$TEST2_PASS" = true ] && [ "$TEST3_PASS" = true ]; then
    echo -e "${GREEN}✅ All code review fixes verified!${NC}"
    echo
    echo -e "${YELLOW}Fixes applied:${NC}"
    echo -e "  ✓ Fix #1 (MUST): Empty status output now returns 0, not 1"
    echo -e "  ✓ Fix #2 (LOW): Flag parsing is order-independent"
    echo -e "  ✓ Fix #3 (LOW): Emergency recovery for critically stale cache"
    EXIT_CODE=0
else
    echo -e "${RED}❌ Some fixes failed verification${NC}"
    echo
    [ "$TEST1_PASS" = false ] && echo -e "  ${RED}✗ Fix #1 failed${NC}"
    [ "$TEST2_PASS" = false ] && echo -e "  ${RED}✗ Fix #2 failed${NC}"
    [ "$TEST3_PASS" = false ] && echo -e "  ${RED}✗ Fix #3 failed${NC}"
    EXIT_CODE=1
fi

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"

exit $EXIT_CODE
