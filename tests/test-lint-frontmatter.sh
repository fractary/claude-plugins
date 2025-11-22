#!/usr/bin/env bash
set -euo pipefail

# Test suite for lint-command-frontmatter.sh
#
# Usage: ./tests/test-lint-frontmatter.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LINTER="$PROJECT_ROOT/scripts/lint-command-frontmatter.sh"

# Test counters
total_tests=0
passed_tests=0
failed_tests=0

echo -e "${BLUE}=== Linter Test Suite ===${NC}"
echo ""

# Test 1: Valid files should pass
echo -n "Test 1: Valid files should pass ... "
((total_tests++))
if "$LINTER" --quiet "$SCRIPT_DIR/fixtures/valid/" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((passed_tests++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((failed_tests++))
fi

# Test 2: Invalid files should fail
echo -n "Test 2: Invalid files should fail ... "
((total_tests++))
if ! "$LINTER" --quiet "$SCRIPT_DIR/fixtures/invalid/" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((passed_tests++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((failed_tests++))
fi

# Test 3: Leading slash error message
echo -n "Test 3: Leading slash error message ... "
((total_tests++))
if "$LINTER" "$SCRIPT_DIR/fixtures/invalid/commands/leading-slash.md" 2>&1 | grep -q "Name field has leading slash"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((passed_tests++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((failed_tests++))
fi

# Test 4: Missing name error message
echo -n "Test 4: Missing name error message ... "
((total_tests++))
if "$LINTER" "$SCRIPT_DIR/fixtures/invalid/commands/missing-name.md" 2>&1 | grep -q "Missing required field: name"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((passed_tests++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((failed_tests++))
fi

# Test 5: No frontmatter error message
echo -n "Test 5: No frontmatter error message ... "
((total_tests++))
if "$LINTER" "$SCRIPT_DIR/fixtures/invalid/commands/no-frontmatter.md" 2>&1 | grep -q "Missing or invalid frontmatter structure"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((passed_tests++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((failed_tests++))
fi

# Test 6: Invalid pattern warning
echo -n "Test 6: Invalid pattern warning ... "
((total_tests++))
if "$LINTER" "$SCRIPT_DIR/fixtures/invalid/commands/invalid-pattern.md" 2>&1 | grep -q "Name field doesn't follow expected pattern"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((passed_tests++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((failed_tests++))
fi

# Test 7: Multiline YAML support
echo -n "Test 7: Multiline YAML support ... "
((total_tests++))
if "$LINTER" --quiet "$SCRIPT_DIR/fixtures/valid/commands/multiline-description.md" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((passed_tests++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((failed_tests++))
fi

# Test 8: --fix flag
echo -n "Test 8: --fix flag functionality ... "
((total_tests++))
cp "$SCRIPT_DIR/fixtures/invalid/commands/leading-slash.md" /tmp/test-fix.md
if "$LINTER" --fix /tmp/test-fix.md >/dev/null 2>&1 && grep -q "^name: test-plugin:leading-slash" /tmp/test-fix.md; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((passed_tests++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((failed_tests++))
fi
rm -f /tmp/test-fix.md

# Test 9: --verbose flag
echo -n "Test 9: --verbose flag shows all files ... "
((total_tests++))
if "$LINTER" --verbose "$SCRIPT_DIR/fixtures/valid/" 2>&1 | grep -q "✓.*simple-command.md"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((passed_tests++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((failed_tests++))
fi

# Test 10: --quiet flag suppresses file output
echo -n "Test 10: --quiet flag suppresses output ... "
((total_tests++))
output=$("$LINTER" --quiet "$SCRIPT_DIR/fixtures/valid/" 2>&1)
if ! echo "$output" | grep -q "File:"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((passed_tests++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((failed_tests++))
fi

echo ""
echo -e "${BLUE}=== Test Summary ===${NC}"
echo "Total tests: $total_tests"
echo "Passed: $passed_tests"
echo "Failed: $failed_tests"
echo ""

if [ $failed_tests -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
