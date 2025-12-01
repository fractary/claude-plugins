#!/usr/bin/env bash
# Integration tests for load-context.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOAD_SCRIPT="$SCRIPT_DIR/load-context.sh"
TEST_DIR="/tmp/faber-cloud-test-$$"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup() {
    mkdir -p "$TEST_DIR"

    # Create test design file
    cat > "$TEST_DIR/test-design.md" <<'EOF'
# API Backend Design

We need an S3 bucket for file uploads and a Lambda function to process them.
The Lambda needs DynamoDB for storing metadata.
EOF

    # Create test FABER spec
    mkdir -p "$TEST_DIR/.faber/specs"
    cat > "$TEST_DIR/.faber/specs/123-api.md" <<'EOF'
# Feature Specification: API Gateway

Create an API Gateway with Lambda integration.
CloudFront distribution for CDN.
IAM roles for permissions.
EOF

    # Create large file (>10MB)
    dd if=/dev/zero of="$TEST_DIR/large-file.md" bs=1M count=11 2>/dev/null

    # Create empty file
    touch "$TEST_DIR/empty-file.md"
}

# Cleanup test environment
cleanup() {
    rm -rf "$TEST_DIR"
}

# Test helper
assert_success() {
    local test_name="$1"
    local source_type="$2"
    local instructions="$3"
    local file_path="$4"

    echo -n "Testing: $test_name... "

    local result
    if result=$(cd "$TEST_DIR" && "$LOAD_SCRIPT" "$source_type" "$instructions" "$file_path" 2>/dev/null); then
        # Verify JSON structure
        if echo "$result" | jq -e '.mode and .base_requirements and .requirements_source' > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PASSED${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ FAILED${NC} (invalid JSON structure)"
            echo "Result: $result"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo -e "${RED}✗ FAILED${NC} (script error)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_failure() {
    local test_name="$1"
    local source_type="$2"
    local instructions="$3"
    local file_path="$4"

    echo -n "Testing: $test_name... "

    if (cd "$TEST_DIR" && "$LOAD_SCRIPT" "$source_type" "$instructions" "$file_path" > /dev/null 2>&1); then
        echo -e "${RED}✗ FAILED${NC} (expected failure, but succeeded)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        echo -e "${GREEN}✓ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
}

assert_contains_resource() {
    local test_name="$1"
    local source_type="$2"
    local instructions="$3"
    local file_path="$4"
    local expected_resource="$5"

    echo -n "Testing: $test_name... "

    local result
    if result=$(cd "$TEST_DIR" && "$LOAD_SCRIPT" "$source_type" "$instructions" "$file_path" 2>/dev/null); then
        if echo "$result" | jq -e ".base_requirements | map(select(. == \"$expected_resource\")) | length > 0" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PASSED${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ FAILED${NC} (resource '$expected_resource' not found)"
            echo "Requirements: $(echo "$result" | jq -r '.base_requirements')"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo -e "${RED}✗ FAILED${NC} (script error)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Setup before tests
setup
trap cleanup EXIT

echo "========================================="
echo "load-context.sh Integration Tests"
echo "========================================="
echo ""

# Test 1: Load design file successfully
assert_success "Load design file" "design_file" "test" "test-design.md"

# Test 2: Load FABER spec successfully
assert_success "Load FABER spec" "faber_spec" "test" ".faber/specs/123-api.md"

# Test 3: Direct instructions (no file)
assert_success "Direct instructions" "direct_instructions" "Create S3 bucket for uploads" ""

# Test 4: File not found
assert_failure "File not found" "design_file" "test" "nonexistent.md"

# Test 5: Empty file
assert_failure "Empty file" "design_file" "test" "empty-file.md"

# Test 6: File too large (>10MB)
assert_failure "File too large" "design_file" "test" "large-file.md"

# Test 7: S3 detection
assert_contains_resource "S3 detection" "design_file" "test" "test-design.md" "s3_bucket"

# Test 8: Lambda detection
assert_contains_resource "Lambda detection" "design_file" "test" "test-design.md" "lambda_function"

# Test 9: DynamoDB detection
assert_contains_resource "DynamoDB detection" "design_file" "test" "test-design.md" "dynamodb_table"

# Test 10: API Gateway detection
assert_contains_resource "API Gateway detection" "faber_spec" "test" ".faber/specs/123-api.md" "api_gateway"

# Test 11: CloudFront detection
assert_contains_resource "CloudFront detection" "faber_spec" "test" ".faber/specs/123-api.md" "cloudfront_distribution"

# Test 12: IAM detection
assert_contains_resource "IAM detection" "faber_spec" "test" ".faber/specs/123-api.md" "iam_role"

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
