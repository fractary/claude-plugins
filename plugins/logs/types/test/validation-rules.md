# Test Log Validation Rules

## Frontmatter
✅ **MUST have** `log_type: test`
✅ **MUST have** `test_id`
✅ **MUST have** valid status
⚠️  **SHOULD have** test counts (total, passed, failed)

## Structure
✅ **MUST have** Test Results section
⚠️  **SHOULD have** Failed Tests section (if failures occurred)
⚠️  **SHOULD have** Test Coverage section

## Content
✅ **Test counts must be consistent**: total = passed + failed + skipped
✅ **Status must match results**: failed status if failed_tests > 0
