# Untyped Log Standards

## Purpose
Fallback category for logs that don't fit into established types or haven't been classified yet.

## When to Use
- Ad-hoc logging during development
- One-off investigations
- Logs awaiting classification
- Custom workflows not covered by standard types

## Required Sections
- Content (main log data)
- Context (optional metadata)
- Classification Note (reminder to categorize if applicable)

## Capture Rules
**ALWAYS capture**: Source of log, basic metadata, timestamp
**REDACT**: Same redaction rules as other types (secrets, PII)
**CONSIDER**: Can this be classified as session, build, deployment, debug, test, audit, or operational?

## Retention
- Local: 7 days (shortest general retention)
- Cloud: 30 days
- Priority: low

## Migration Path
Untyped logs should be reviewed and reclassified when possible:
1. Review log content and purpose
2. Identify appropriate log type
3. Update frontmatter `log_type` field
4. Ensure all required fields for target type are present
5. Archive will automatically apply correct retention policy

## Best Practices
- Use descriptive `category` field to enable future classification
- Document `source` clearly for traceability
- Minimize use of `_untyped` - prefer explicit types for better organization
