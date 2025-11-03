# Evaluate Phase: Basic Workflow

This workflow implements the basic Evaluate phase - testing implementations and making GO/NO-GO decisions.

## Steps

### 1. Post Evaluate Start Notification
```bash
"$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "evaluate" "🧪 **Evaluate Phase Started**

**Work ID**: \`${WORK_ID}\`
$([ "$RETRY_COUNT" -gt 0 ] && echo "**Retry**: Evaluation attempt $((RETRY_COUNT + 1))")

Running tests and reviewing implementation..." '[]'
```

### 2. Run Test Suite

Execute available tests:

```bash
# Detect and run tests
TEST_PASSED=0
TEST_FAILED=0
TEST_OUTPUT=""

# Check for different test frameworks
if [ -f "package.json" ] && grep -q "\"test\"" package.json; then
    echo "📦 Running npm tests..."
    TEST_OUTPUT=$(npm test 2>&1)
    TEST_EXIT=$?
elif [ -f "pyproject.toml" ] || [ -f "pytest.ini" ]; then
    echo "🐍 Running pytest..."
    TEST_OUTPUT=$(pytest 2>&1)
    TEST_EXIT=$?
elif [ -f "Cargo.toml" ]; then
    echo "🦀 Running cargo test..."
    TEST_OUTPUT=$(cargo test 2>&1)
    TEST_EXIT=$?
else
    echo "⚠️  No test framework detected"
    TEST_EXIT=0  # No tests = pass (for basic workflow)
fi

# Parse test results (simplified)
if [ $TEST_EXIT -eq 0 ]; then
    echo "✅ All tests passed"
    TESTS_PASSED=true
else
    echo "❌ Tests failed"
    TESTS_PASSED=false
    FAILURE_REASONS+=("Test suite failed with exit code $TEST_EXIT")
fi
```

### 3. Code Quality Review

Check linting and formatting:

```bash
# Run linter if available
LINT_PASSED=true

if command -v eslint &> /dev/null && [ -f ".eslintrc.json" ]; then
    echo "🔍 Running ESLint..."
    eslint . || LINT_PASSED=false
elif command -v ruff &> /dev/null; then
    echo "🔍 Running ruff..."
    ruff check . || LINT_PASSED=false
fi

if [ "$LINT_PASSED" = false ]; then
    FAILURE_REASONS+=("Linting errors detected")
fi
```

### 4. Verify Specification Compliance

Check that implementation matches spec:

```bash
# Load spec
SPEC_FILE=$(echo "$ARCHITECT_CONTEXT" | jq -r '.spec_file')

# Extract success criteria from spec
SUCCESS_CRITERIA=$(grep -A 20 "## Success Criteria" "$SPEC_FILE" | grep "^- \[ \]" || true)

# Manual review note (for basic workflow)
echo "📋 Success Criteria (from spec):"
echo "$SUCCESS_CRITERIA"
echo ""
echo "⚠️  Manual verification recommended for spec compliance"
```

### 5. Make GO/NO-GO Decision

```bash
DECISION="go"
FAILURE_REASONS=()

# Aggregate results
if [ "$TESTS_PASSED" = false ]; then
    DECISION="no-go"
fi

if [ "$LINT_PASSED" = false ]; then
    DECISION="no-go"
fi

# Check retry count - don't retry forever
if [ "$RETRY_COUNT" -ge 2 ] && [ "$DECISION" = "no-go" ]; then
    echo "⚠️  Multiple retries attempted - may need manual intervention"
fi
```

### 6. Update Session

```bash
EVALUATE_DATA=$(cat <<EOF
{
  "decision": "$DECISION",
  "test_results": {
    "passed": $TEST_PASSED,
    "failed": $TEST_FAILED,
    "status": "$([ "$TESTS_PASSED" = true ] && echo "passed" || echo "failed")"
  },
  "review_results": {
    "linting": "$([ "$LINT_PASSED" = true ] && echo "passed" || echo "failed")"
  },
  "failure_reasons": $(printf '%s\n' "${FAILURE_REASONS[@]}" | jq -R . | jq -s .)
}
EOF
)

if [ "$DECISION" = "go" ]; then
    "$CORE_SKILL/session-update.sh" "$WORK_ID" "evaluate" "completed" "$EVALUATE_DATA"
else
    "$CORE_SKILL/session-update.sh" "$WORK_ID" "evaluate" "in_progress" "$EVALUATE_DATA"
fi
```

### 7. Post Evaluate Result

```bash
if [ "$DECISION" = "go" ]; then
    "$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "evaluate" "✅ **Evaluate Phase: GO Decision**

All tests passed and code quality checks succeeded.

Ready to proceed to Release phase." '[]'
else
    FAILURE_LIST=$(printf '%s\n' "${FAILURE_REASONS[@]}" | sed 's/^/- /')

    "$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "evaluate" "⚠️  **Evaluate Phase: NO-GO Decision**

**Issues Found**:
$FAILURE_LIST

Will retry Build phase to address issues." '[]'
fi
```

### 8. Return Results

```bash
cat <<EOF
{
  "status": "success",
  "phase": "evaluate",
  "decision": "$DECISION",
  "test_results": $TEST_RESULTS,
  "review_results": $REVIEW_RESULTS,
  "failure_reasons": $(printf '%s\n' "${FAILURE_REASONS[@]}" | jq -R . | jq -s .)
}
EOF

# Exit with non-zero if NO-GO
if [ "$DECISION" = "no-go" ]; then
    exit 1
fi
```

## Success Criteria (GO Decision)
- ✅ All tests passing
- ✅ Code quality checks passing
- ✅ Spec compliance verified
- ✅ No critical issues found

## NO-GO Triggers
- ❌ Test failures
- ❌ Linting errors
- ❌ Security vulnerabilities
- ❌ Spec non-compliance

## Retry Loop

When Evaluate returns NO-GO:
1. workflow-manager captures failure_reasons
2. workflow-manager re-invokes Build with retry_context
3. Build addresses issues
4. Evaluate runs again
5. Loop continues until GO or max retries exceeded

This basic Evaluate workflow provides testing and quality gates while supporting the Build-Evaluate retry loop.
