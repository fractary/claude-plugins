#!/usr/bin/env bash
# Integration tests for parse-input.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARSE_SCRIPT="$SCRIPT_DIR/parse-input.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Test helper
assert_success() {
    local test_name="$1"
    local input="$2"
    local expected_type="$3"

    echo -n "Testing: $test_name... "

    local result
    if result=$("$PARSE_SCRIPT" "$input" 2>/dev/null); then
        local actual_type
        actual_type=$(echo "$result" | jq -r '.source_type')

        if [ "$actual_type" = "$expected_type" ]; then
            echo -e "${GREEN}✓ PASSED${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ FAILED${NC} (expected: $expected_type, got: $actual_type)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo -e "${RED}✗ FAILED${NC} (script error)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_failure() {
    local test_name="$1"
    local input="$2"

    echo -n "Testing: $test_name... "

    if "$PARSE_SCRIPT" "$input" > /dev/null 2>&1; then
        echo -e "${RED}✗ FAILED${NC} (expected failure, but succeeded)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        echo -e "${GREEN}✓ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
}

echo "========================================="
echo "parse-input.sh Integration Tests"
echo "========================================="
echo ""

# Test 1: Simple design file
assert_success "Simple design file" "user-uploads.md" "design_file"

# Test 2: FABER spec
assert_success "FABER spec" ".faber/specs/123-add-api.md" "faber_spec"

# Test 3: Direct instructions
assert_success "Direct instructions" "Fix IAM permissions - Lambda needs s3:PutObject" "direct_instructions"

# Test 4: Mixed context
assert_success "Mixed context" "Implement api-backend.md and add CloudWatch alarms" "design_file"

# Test 5: Empty input
assert_success "Empty input (latest design)" "" "latest_design"

# Test 6: Natural language with filename
assert_success "Natural language" "Use design from api-backend.md" "design_file"

# Test 7: Path traversal attempt (should fail)
assert_failure "Path traversal (security)" "../../../etc/passwd"

# Test 8: Input too long (should fail)
assert_failure "Input too long" "$(printf 'a%.0s' {1..10001})"

# Test 9: Full design path
assert_success "Full design path" ".fractary/plugins/faber-cloud/designs/api.md" "design_file"

# Test 10: Special characters in filename
assert_success "Special characters" "my-design (v2).md" "design_file"

echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
