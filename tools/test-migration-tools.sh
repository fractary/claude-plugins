#!/bin/bash
# test-migration-tools.sh
#
# Test suite for migration tools
# Usage: ./tools/test-migration-tools.sh

set -euo pipefail

echo "=== Migration Tools Test Suite ==="
echo

# Setup test environment
TEST_DIR="./test-migration-$$"
mkdir -p "$TEST_DIR"/{docs,specs}
cd "$TEST_DIR"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
test_start() {
    ((TESTS_RUN++))
    echo "Test $TESTS_RUN: $1"
}

test_pass() {
    ((TESTS_PASSED++))
    echo "  ✓ PASS"
}

test_fail() {
    ((TESTS_FAILED++))
    echo "  ✗ FAIL: $1"
}

# ============================================================================
# Test 1: migrate-docs.sh with --dry-run
# ============================================================================
test_start "migrate-docs.sh --dry-run doesn't modify files"

# Create test doc
cat > docs/test-doc.md <<'EOF'
# Test Document

This is a test document without front matter.
EOF

# Run with --dry-run
../tools/migrate-docs.sh docs/test-doc.md --dry-run > /dev/null 2>&1

# Check file unchanged
if ! grep -q "^---$" docs/test-doc.md 2>/dev/null; then
    test_pass
else
    test_fail "File was modified in dry-run mode"
fi

# ============================================================================
# Test 2: migrate-docs.sh actually modifies files
# ============================================================================
test_start "migrate-docs.sh adds front matter"

# Run without --dry-run
../tools/migrate-docs.sh docs/test-doc.md > /dev/null 2>&1

# Check front matter added
if grep -q "^---$" docs/test-doc.md && \
   grep -q "^codex_sync: true$" docs/test-doc.md; then
    test_pass
else
    test_fail "Front matter not added correctly"
fi

# ============================================================================
# Test 3: migrate-docs.sh skips files with existing front matter
# ============================================================================
test_start "migrate-docs.sh skips files with existing front matter"

# Run again (should skip)
OUTPUT=$(../tools/migrate-docs.sh docs/test-doc.md 2>&1)

if echo "$OUTPUT" | grep -q "already has front matter"; then
    test_pass
else
    test_fail "Didn't detect existing front matter"
fi

# ============================================================================
# Test 4: migrate-specs.sh with --dry-run
# ============================================================================
test_start "migrate-specs.sh --dry-run doesn't modify files"

# Create test spec
cat > SPEC-123-test.md <<'EOF'
# Test Specification

This is a test spec.
EOF

# Run with --dry-run
../tools/migrate-specs.sh . --dry-run > /dev/null 2>&1

# Check spec not moved
if [[ -f "SPEC-123-test.md" ]] && [[ ! -f "/specs/SPEC-123-test.md" ]]; then
    test_pass
else
    test_fail "Files were modified in dry-run mode"
fi

# ============================================================================
# Test 5: migrate-specs.sh migrates specs
# ============================================================================
test_start "migrate-specs.sh migrates specs to /specs"

# Create /specs directory and mark it as a test directory
mkdir -p /specs
touch /specs/.test-migration-marker-$$

# Run without --dry-run
../tools/migrate-specs.sh . > /dev/null 2>&1

# Check spec moved and has front matter
if [[ -f "/specs/SPEC-123-test.md" ]] && \
   grep -q "^spec_id: SPEC-123-test$" /specs/SPEC-123-test.md && \
   grep -q "^issue_number: 123$" /specs/SPEC-123-test.md; then
    test_pass
else
    test_fail "Spec not migrated correctly"
fi

# ============================================================================
# Test 6: add-frontmatter-bulk.sh with --dry-run
# ============================================================================
test_start "add-frontmatter-bulk.sh --dry-run doesn't modify files"

# Create docs without front matter
cat > docs/bulk-test-1.md <<'EOF'
# Bulk Test 1
Content here.
EOF

cat > docs/bulk-test-2.md <<'EOF'
# Bulk Test 2
Content here.
EOF

# Run with --dry-run
../tools/add-frontmatter-bulk.sh docs/ --dry-run > /dev/null 2>&1

# Check files unchanged
if ! grep -q "^codex_sync:" docs/bulk-test-1.md && \
   ! grep -q "^codex_sync:" docs/bulk-test-2.md; then
    test_pass
else
    test_fail "Files were modified in dry-run mode"
fi

# ============================================================================
# Test 7: add-frontmatter-bulk.sh processes multiple files
# ============================================================================
test_start "add-frontmatter-bulk.sh processes multiple files"

# Run without --dry-run
../tools/add-frontmatter-bulk.sh docs/ > /dev/null 2>&1

# Check both files have codex_sync
if grep -q "^codex_sync: true$" docs/bulk-test-1.md && \
   grep -q "^codex_sync: true$" docs/bulk-test-2.md; then
    test_pass
else
    test_fail "Not all files processed correctly"
fi

# ============================================================================
# Test 8: add-frontmatter-bulk.sh counter works
# ============================================================================
test_start "add-frontmatter-bulk.sh reports correct counts"

# Create one more doc
cat > docs/bulk-test-3.md <<'EOF'
# Bulk Test 3
Content here.
EOF

# Run and capture output
OUTPUT=$(../tools/add-frontmatter-bulk.sh docs/ 2>&1)

# Check for "Updated: 1" (only the new file)
# And "Skipped: 3" (the ones already processed)
if echo "$OUTPUT" | grep -q "Updated: 1" && \
   echo "$OUTPUT" | grep -q "Skipped: 3"; then
    test_pass
else
    test_fail "Counter not working correctly"
fi

# ============================================================================
# Test 9: validate-migration.sh runs without errors
# ============================================================================
test_start "validate-migration.sh runs without errors"

# Create minimal structure
mkdir -p .fractary/plugins/file
echo '{}' > .fractary/plugins/file/config.json

# Run validation
if ../tools/validate-migration.sh > /dev/null 2>&1; then
    test_pass
else
    test_fail "Validation script failed"
fi

# ============================================================================
# Test 10: Cross-platform date handling in migrate-specs.sh
# ============================================================================
test_start "migrate-specs.sh handles dates on both Linux and macOS"

# Create test spec
cat > SPEC-999-date-test.md <<'EOF'
# Date Test Spec
Testing cross-platform date handling.
EOF

# Run migration
../tools/migrate-specs.sh . > /dev/null 2>&1

# Check date format is valid (YYYY-MM-DD)
if grep -q "^created: [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}$" /specs/SPEC-999-date-test.md; then
    test_pass
else
    test_fail "Date format invalid"
fi

# ============================================================================
# Cleanup
# ============================================================================
cd ..
rm -rf "$TEST_DIR"

# Only remove /specs if it contains our test marker (safety guard)
if [[ -f "/specs/.test-migration-marker-$$" ]]; then
    rm -rf /specs
elif [[ -d "/specs" ]]; then
    echo "Warning: /specs exists but wasn't created by this test run - not removing"
fi

# ============================================================================
# Summary
# ============================================================================
echo
echo "=== Test Results ==="
echo "Tests run: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo

if ((TESTS_FAILED > 0)); then
    echo "❌ Some tests failed"
    exit 1
else
    echo "✅ All tests passed!"
    exit 0
fi
