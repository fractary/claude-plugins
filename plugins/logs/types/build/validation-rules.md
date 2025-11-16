# Build Log Validation Rules

## Frontmatter Validation

✅ **MUST have** valid frontmatter with all required fields
✅ **MUST have** `log_type: build`
✅ **MUST have** `build_id` field (unique identifier)
✅ **MUST have** valid ISO 8601 date in `date` field
✅ **MUST have** valid status: `pending`, `running`, `success`, `failure`, `cancelled`, or `archived`
✅ **MUST have** integer `exit_code` field
⚠️  **SHOULD have** `commit_sha` field (7-40 hex chars)
⚠️  **SHOULD have** `build_tool` field

## Structure Validation

✅ **MUST have** Build Metadata section
✅ **MUST have** Build Output section with stdout/stderr
✅ **MUST have** Build Summary section
⚠️  **SHOULD have** Errors section (if failures occurred)
⚠️  **SHOULD have** Warnings section
⚠️  **SHOULD have** Artifacts section (if artifacts produced)
⚠️  **SHOULD have** Performance Metrics section

## Content Validation

✅ **Build ID** must be unique
- Format: Timestamp-based or sequential
- Example: `20250116-143052` or `build-1234`

✅ **Exit code** must be integer
- 0 = success
- Non-zero = failure
- Should match status (success → 0, failure → non-zero)

✅ **Commit SHA** must match git SHA format (if present)
- Pattern: `^[0-9a-f]{7,40}$`
- Example: `abc1234` (short) or full 40-char SHA

✅ **Duration** must be non-negative integer (seconds)

✅ **Status consistency**
- `exit_code: 0` → status should be `success`
- `exit_code: non-zero` → status should be `failure`

## Error/Warning Format

✅ **Errors must include location**
- Pattern: `**<file>:<line>**: <message>`
- Example: `**src/main.ts:45**: Expected ';'`

⚠️  **SHOULD extract from build output**
- Parse compiler error messages
- Include file, line, column (if available)

## Redaction Validation

✅ **No exposed build secrets**
- Check for API keys, tokens in environment variables
- Redact as `[REDACTED:BUILD_SECRET]`

✅ **No internal infrastructure paths**
- Replace `/home/user/` with `/path/to/project/`
- Redact internal CI/CD server URLs

## Error Messages

**Invalid Exit Code**:
```
Error: Invalid exit_code
Expected: Integer
Got: "success"
Fix: Use numeric exit code (0 for success, non-zero for failure)
```

**Status/Exit Code Mismatch**:
```
Warning: Status does not match exit_code
Status: success
Exit Code: 1 (failure)
Fix: Ensure status aligns with exit code
```
