# Untyped Log Validation Rules

## Frontmatter
✅ **MUST have** `log_type: _untyped`
✅ **MUST have** `log_id`
✅ **MUST have** valid status
⚠️  **SHOULD have** `source` (where log originated)
⚠️  **SHOULD have** `category` (hint for future classification)

## Structure
✅ **MUST have** Content section
⚠️  **SHOULD have** Context section
⚠️  **SHOULD have** Classification Note (template provides this)

## Content
⚠️  **SHOULD follow redaction rules**: Even untyped logs must protect secrets and PII
⚠️  **SHOULD include classification hints**: Category, source, purpose help future organization
ℹ️  **MAY be free-form**: Untyped logs have minimal structure requirements

## Recommendations
⚠️  **REVIEW periodically**: Untyped logs should be analyzed for patterns and reclassified
⚠️  **PREFER typed logs**: Use explicit types (session, build, etc.) when applicable
ℹ️  **TEMPORARY category**: `_untyped` should be transitional, not permanent
