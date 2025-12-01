#!/usr/bin/env bash
# Integration tests for validate-terraform.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATE_SCRIPT="$SCRIPT_DIR/validate-terraform.sh"
TEST_DIR="/tmp/faber-cloud-test-validate-$$"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup() {
    mkdir -p "$TEST_DIR/terraform"

    # Create valid Terraform configuration
    cat > "$TEST_DIR/terraform/main.tf" <<'EOF'
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "uploads" {
  bucket = "my-uploads-bucket"

  tags = {
    Name        = "Uploads"
    Environment = "dev"
  }
}
EOF

    # Create invalid Terraform configuration
    mkdir -p "$TEST_DIR/terraform-invalid"
    cat > "$TEST_DIR/terraform-invalid/main.tf" <<'EOF'
# Invalid syntax - missing closing brace
resource "aws_s3_bucket" "test" {
  bucket = "test-bucket"
  # Missing closing brace
EOF

    # Create unformatted Terraform configuration
    mkdir -p "$TEST_DIR/terraform-unformatted"
    cat > "$TEST_DIR/terraform-unformatted/main.tf" <<'EOF'
resource "aws_s3_bucket" "test"{
bucket="test-bucket"
tags={
Name="Test"
}
}
EOF

    # Create Terraform with missing provider
    mkdir -p "$TEST_DIR/terraform-no-provider"
    cat > "$TEST_DIR/terraform-no-provider/main.tf" <<'EOF'
resource "aws_s3_bucket" "test" {
  bucket = "test-bucket"
}
EOF
}

# Cleanup test environment
cleanup() {
    rm -rf "$TEST_DIR"
}

# Test helper
assert_success() {
    local test_name="$1"
    local tf_dir="$2"

    echo -n "Testing: $test_name... "

    local result
    if result=$(cd "$TEST_DIR" && "$VALIDATE_SCRIPT" "$tf_dir" 2>/dev/null); then
        # Verify JSON structure (check validation_status, not validation_passed)
        if echo "$result" | jq -e '.validation_status == "passed" and .terraform_dir' > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PASSED${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ FAILED${NC} (validation did not pass)"
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
    local tf_dir="$2"

    echo -n "Testing: $test_name... "

    local result
    if result=$(cd "$TEST_DIR" && "$VALIDATE_SCRIPT" "$tf_dir" 2>/dev/null); then
        # Check if validation_status is "failed" (not validation_passed)
        if echo "$result" | jq -e '.validation_status == "failed"' > /dev/null 2>&1; then
            echo -e "${GREEN}✓ PASSED${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ FAILED${NC} (expected validation to fail)"
            echo "Result: $result"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo -e "${RED}✗ FAILED${NC} (script error)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_report_exists() {
    local test_name="$1"
    local tf_dir="$2"

    echo -n "Testing: $test_name... "

    if (cd "$TEST_DIR" && "$VALIDATE_SCRIPT" "$tf_dir" > /dev/null 2>&1); then
        # Check if validation report was created
        if [ -f "$TEST_DIR/$tf_dir/validation-report-latest.txt" ]; then
            echo -e "${GREEN}✓ PASSED${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ FAILED${NC} (validation report not created)"
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
echo "validate-terraform.sh Integration Tests"
echo "========================================="
echo ""

# Skip tests if terraform is not installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Terraform not installed - skipping tests${NC}"
    exit 0
fi

# Test 1: Valid Terraform configuration
assert_success "Valid Terraform" "terraform"

# Test 2: Invalid Terraform syntax
assert_failure "Invalid syntax" "terraform-invalid"

# Test 3: Unformatted Terraform (should fail format check)
assert_failure "Unformatted Terraform" "terraform-unformatted"

# Test 4: Missing provider configuration
assert_failure "Missing provider" "terraform-no-provider"

# Test 5: Validation report generation
assert_report_exists "Validation report created" "terraform"

# Test 6: Nonexistent directory
echo -n "Testing: Nonexistent directory... "
if (cd "$TEST_DIR" && "$VALIDATE_SCRIPT" "nonexistent" > /dev/null 2>&1); then
    echo -e "${RED}✗ FAILED${NC} (expected failure)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
else
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# Test 7: Check timestamped reports don't overwrite
echo -n "Testing: Timestamped reports... "
(cd "$TEST_DIR" && "$VALIDATE_SCRIPT" "terraform" > /dev/null 2>&1)
sleep 1
(cd "$TEST_DIR" && "$VALIDATE_SCRIPT" "terraform" > /dev/null 2>&1)
report_count=$(ls "$TEST_DIR/terraform"/validation-report-*.txt 2>/dev/null | wc -l)
if [ "$report_count" -ge 2 ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC} (reports were overwritten)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

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
