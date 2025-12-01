#!/bin/bash

# Test script for pre-commit hook
# Validates that shell script permissions are auto-fixed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

echo "Testing pre-commit hook..."
echo "Test directory: $TEST_DIR"
echo ""

# Initialize test repo
cd "$TEST_DIR"
git init -q
git config user.email "test@test.com"
git config user.name "Test"
git config core.hooksPath "$SCRIPT_DIR"

# Test 1: New shell script without executable permission
echo "Test 1: New .sh file should get +x permission"
echo '#!/bin/bash' > test-script.sh
git add test-script.sh

# Check mode before commit
MODE_BEFORE=$(git ls-files -s test-script.sh | cut -d' ' -f1)
echo "  Mode before commit: $MODE_BEFORE"

# Run pre-commit hook (simulated via commit)
git commit -q -m "Add test script" 2>/dev/null || true

# Check mode after
MODE_AFTER=$(git ls-files -s test-script.sh | cut -d' ' -f1)
echo "  Mode after commit: $MODE_AFTER"

if [ "$MODE_AFTER" = "100755" ]; then
    echo "  PASS: Script is now executable"
else
    echo "  FAIL: Script mode is $MODE_AFTER, expected 100755"
    exit 1
fi
echo ""

# Test 2: File with spaces in name
echo "Test 2: File with spaces in name"
echo '#!/bin/bash' > "test script with spaces.sh"
git add "test script with spaces.sh"
git commit -q -m "Add script with spaces" 2>/dev/null || true

MODE=$(git ls-files -s "test script with spaces.sh" | cut -d' ' -f1)
if [ "$MODE" = "100755" ]; then
    echo "  PASS: Script with spaces is executable"
else
    echo "  FAIL: Script mode is $MODE, expected 100755"
    exit 1
fi
echo ""

# Test 3: Non-.sh files should not be affected
echo "Test 3: Non-.sh files should not be modified"
echo "test content" > test.txt
git add test.txt
git commit -q -m "Add text file" 2>/dev/null || true

MODE=$(git ls-files -s test.txt | cut -d' ' -f1)
if [ "$MODE" = "100644" ]; then
    echo "  PASS: Text file remains non-executable"
else
    echo "  FAIL: Text file mode is $MODE, expected 100644"
    exit 1
fi
echo ""

echo "All tests passed!"
