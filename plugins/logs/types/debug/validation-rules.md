# Debug Log Validation Rules

## Frontmatter
✅ **MUST have** `log_type: debug`
✅ **MUST have** `debug_id`
✅ **MUST have** valid status
⚠️  **SHOULD have** `severity` level
⚠️  **SHOULD have** `component` identifier

## Structure
✅ **MUST have** Problem Description
⚠️  **SHOULD have** Steps to Reproduce
⚠️  **SHOULD have** Debug Output

## Content
✅ **Severity** must be: low, medium, high, or critical
✅ **No sensitive data** in debug output
