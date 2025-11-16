# Session Log Validation Rules

## Frontmatter Validation

✅ **MUST have** valid frontmatter with all required fields
✅ **MUST have** `log_type: session`
✅ **MUST have** valid UUID in `session_id` field (8-4-4-4-12 hex format)
✅ **MUST have** valid ISO 8601 date in `date` field
✅ **MUST have** valid status: `active`, `stopped`, `archived`, or `error`
⚠️  **SHOULD have** `issue_number` if session is associated with work item
⚠️  **SHOULD have** `conversation_id` for Claude Code sessions
⚠️  **SHOULD have** `repository` and `branch` for code-related sessions

## Structure Validation

✅ **MUST have** Session Metadata section
✅ **MUST have** Conversation Log section
✅ **MUST have** Session Summary section
⚠️  **SHOULD have** Key Decisions section
⚠️  **SHOULD have** Action Items section
⚠️  **SHOULD have** Files Modified section (if files were modified)
⚠️  **SHOULD have** Commands Executed section (if commands were run)
⚠️  **SHOULD have** Session End section

## Content Validation

✅ **Session ID** must be unique (UUID v4 format)
- Pattern: `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`
- Example: `abc123de-f456-789a-bcde-f0123456789a`

✅ **Date** must be valid ISO 8601 format
- Pattern: `YYYY-MM-DDTHH:mm:ss.sssZ`
- Example: `2025-01-16T14:30:00.000Z`

✅ **Duration** must be non-negative integer (seconds)
- Minimum: 0
- Example: 3600 (1 hour)

✅ **Token count** must be non-negative integer
- Minimum: 0
- Example: 15000

✅ **Status** must be valid enum value
- Valid: `active`, `stopped`, `archived`, `error`
- Invalid: `running`, `complete`, `done`

✅ **Issue number** must be string or number (if present)
- Valid: `"125"`, `125`, `"PROJ-456"`
- Invalid: `null` (omit field instead), `[]`

## Redaction Validation

✅ **No exposed secrets** - Must not contain API keys, tokens, passwords
- Check for patterns: `sk-`, `api_key`, `password`, `token`
- All secrets must be `[REDACTED:SECRET]`

✅ **No PII in public logs** - Must redact emails, personal names (non-workspace)
- Check for patterns: email addresses, phone numbers
- Redact as `[REDACTED:EMAIL]`, `[REDACTED:PHONE]`

✅ **No sensitive paths** - Must obscure internal file structures
- Check for patterns: `/Users/`, `/home/`, `C:\Users\`
- Replace with generic paths: `/path/to/project/`

⚠️  **WARN if database credentials** - Should not contain connection strings
- Pattern: `postgres://`, `mysql://`, `mongodb://`
- Should be `[REDACTED:DB_CONNECTION]`

## Link Validation

✅ **Internal references** must be valid
- Issue links: `#125` must reference existing issue (if validatable)
- File paths: Relative paths should exist (if validatable)

⚠️  **WARN on broken external links** (non-critical)
- HTTP/HTTPS URLs should be accessible
- Report but don't fail validation

## Completeness Checks

⚠️  **WARN if missing conversation content**
- Conversation Log section should not be empty
- Sessions should have actual content

⚠️  **WARN if missing summary**
- Session Summary should be at least 50 characters
- Should provide meaningful overview

⚠️  **WARN if no decisions captured**
- Sessions longer than 30 minutes should typically have decisions
- Empty Key Decisions section warrants warning

✅ **Files Modified list format**
- Each entry must match: `- path: description`
- Pattern: `^\s*-\s*\`[^`]+\`:\s*.+$`

✅ **Action Items checkbox format**
- Each item must match: `- [ ] description`
- Pattern: `^\s*-\s*\[\s*\]\s*.+$`

## Error Messages

When validation fails, provide:
- **Clear description** of the issue
- **Location** (section/line) where error occurred
- **How to fix** with example

### Example Error Messages

**Invalid Session ID**:
```
Error: Invalid session_id format
Location: Frontmatter line 3
Expected: UUID v4 format (8-4-4-4-12)
Got: "abc123"
Fix: Use uuidgen to generate valid UUID
```

**Missing Required Section**:
```
Error: Missing required section "Session Summary"
Location: Document body
Expected: ## Session Summary
Fix: Add session summary after Conversation Log
```

**Exposed Secret**:
```
Error: Potential secret detected
Location: Line 45
Pattern: "sk-ant-..."
Fix: Replace with [REDACTED:API_KEY]
```

**Invalid Status**:
```
Error: Invalid status value
Location: Frontmatter line 6
Expected: active, stopped, archived, or error
Got: "complete"
Fix: Use one of the valid status values
```

## Validation Levels

### Critical (MUST) - Fail validation
- Missing required frontmatter fields
- Invalid data types or formats
- Exposed secrets or PII
- Invalid enum values

### Warning (SHOULD) - Pass with warnings
- Missing optional fields
- Missing recommended sections
- Empty sections (when content expected)
- Broken external links

### Info (MAY) - Informational only
- Style suggestions
- Formatting improvements
- Best practice recommendations

## Validation Script Exit Codes

- **0**: Validation passed (no errors, warnings allowed)
- **1**: Validation failed (critical errors found)
- **2**: Validation error (unable to read file)
- **3**: Validation error (invalid frontmatter YAML)
- **10**: Validation warning only (no critical errors)
