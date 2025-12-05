# Skill Response Best Practices

This guide provides best practices for implementing skill responses in FABER workflows. Following these guidelines ensures consistent response handling, better error recovery, and improved user experience.

## Overview

All FABER skills must return responses that conform to the standard response format. This enables:
- Intelligent workflow routing based on status
- Rich error handling with multiple errors/warnings
- Actionable recovery suggestions
- Comprehensive audit logging

**Schema Reference**: `plugins/faber/config/schemas/skill-response.schema.json`
**Documentation**: `plugins/faber/docs/RESPONSE-FORMAT.md`

## Required Fields

Every skill response MUST include:

```json
{
  "status": "success" | "warning" | "failure",
  "message": "Human-readable summary"
}
```

### Status Values

| Value | When to Use |
|-------|-------------|
| `"success"` | Goal achieved completely, no issues |
| `"warning"` | Goal achieved but with non-blocking concerns |
| `"failure"` | Goal NOT achieved, operation failed |

### Message Guidelines

- Keep messages concise (1-2 sentences)
- Be specific about what happened
- Use active voice
- Don't include stack traces or technical IDs

**Good messages:**
- "Specification generated successfully"
- "Build completed with 3 warnings"
- "Test suite failed - 5 tests failed"

**Bad messages:**
- "Done"
- "Error occurred"
- "Operation completed at 2025-12-05T10:30:00Z with exit code 0"

## Optional Fields

### details (object)

Operation-specific structured data. Use for artifacts, metrics, and results.

```json
"details": {
  "spec_path": "/specs/WORK-00123.md",
  "word_count": 2847,
  "sections": 7
}
```

**Best practices:**
- Include paths to created artifacts
- Add metrics (counts, durations, sizes)
- Store IDs for created resources (PR number, commit SHA)
- Keep structure shallow (avoid deep nesting)

### errors (string[])

List of error messages when status is "failure".

```json
"errors": [
  "Test test_auth_login failed: AssertionError",
  "Test test_export failed: TimeoutError after 30s"
]
```

**Best practices:**
- Include one error per array item
- Be specific about location (file, line, function)
- Include relevant values or context
- Order by severity (most critical first)

### warnings (string[])

List of warning messages when status is "warning" or when a success has minor concerns.

```json
"warnings": [
  "Deprecated API usage: useCallback will be removed in v3.0",
  "Large bundle size: 2.5MB exceeds recommended 1MB"
]
```

**Best practices:**
- Explain the concern clearly
- Include timeline for deprecations
- Mention impact if not addressed
- Distinguish from blocking errors

### error_analysis (string)

Root cause analysis for failures. Helps users understand WHY something failed.

```json
"error_analysis": "Authentication tests are failing because the session module was recently refactored. The new async cleanup pattern requires await, but the logout handler is calling cleanup() synchronously."
```

**Best practices:**
- Explain the root cause, not just symptoms
- Connect multiple errors to common cause
- Mention recent changes that might be relevant
- Keep technical but accessible

### warning_analysis (string)

Impact assessment for warnings. Explains consequences if not addressed.

```json
"warning_analysis": "The deprecated API will be removed in React v19 (expected Q2 2025). Bundle size may cause slow initial load on mobile devices."
```

**Best practices:**
- Mention timelines (deprecation dates, etc.)
- Explain downstream impact
- Quantify when possible (estimated load times, etc.)
- Prioritize which warnings matter most

### suggested_fixes (string[])

Actionable recovery suggestions for failures and warnings.

```json
"suggested_fixes": [
  "Add 'await' before session.cleanup() in src/auth/logout.ts:45",
  "Run 'npm run migrate:rollback' then retry deployment"
]
```

**Best practices:**
- Be specific and actionable
- Include file paths and line numbers
- Order by likelihood of success
- Include commands that can be run

## Complete Examples

### Success Response

```json
{
  "status": "success",
  "message": "Build phase completed - 3 files modified, 2 commits created",
  "details": {
    "phase": "build",
    "commits": [
      "a1b2c3d: feat: add CSV export endpoint",
      "e5f6g7h: test: add export tests"
    ],
    "files_changed": [
      "src/api/export.py",
      "src/utils/csv.py",
      "tests/test_export.py"
    ],
    "lines_added": 245,
    "lines_removed": 12
  }
}
```

### Warning Response

```json
{
  "status": "warning",
  "message": "Specification generated with warnings - missing some details",
  "details": {
    "phase": "architect",
    "spec_path": "/specs/WORK-00123-export.md",
    "completeness_score": 0.75
  },
  "warnings": [
    "Work item description lacks technical details",
    "No acceptance criteria defined in issue",
    "Estimated complexity: HIGH (may need clarification)"
  ],
  "warning_analysis": "The specification was generated but may be incomplete because the work item lacks detailed requirements. Consider adding acceptance criteria to the issue.",
  "suggested_fixes": [
    "Add acceptance criteria to issue #123",
    "Review generated spec and add missing sections",
    "Consider splitting into smaller work items"
  ]
}
```

### Failure Response

```json
{
  "status": "failure",
  "message": "Test suite failed - 5 of 47 tests failed",
  "details": {
    "phase": "evaluate",
    "test_results": {
      "total": 47,
      "passed": 42,
      "failed": 5,
      "skipped": 0
    },
    "coverage": 78.5
  },
  "errors": [
    "test_auth_login (test_auth.py:45): AssertionError - expected True, got False",
    "test_auth_logout (test_auth.py:67): TimeoutError - exceeded 30s limit",
    "test_token_refresh (test_auth.py:89): KeyError - 'refresh_token' not in response",
    "test_export_csv (test_export.py:23): FileNotFoundError - /tmp/export.csv",
    "test_export_json (test_export.py:45): JSONDecodeError - invalid JSON"
  ],
  "error_analysis": "Authentication tests (3 failures) are failing due to session handling issues introduced in recent changes. Export tests (2 failures) are failing because the temp directory is not being created.",
  "suggested_fixes": [
    "Add 'await' to session.cleanup() call in logout handler",
    "Check token refresh endpoint returns 'refresh_token' key",
    "Create temp directory in test setup: os.makedirs('/tmp', exist_ok=True)",
    "Verify export endpoint returns valid JSON"
  ]
}
```

## Anti-Patterns

### DON'T: Use bare booleans

```json
// Bad
{ "success": true, "result": "done" }

// Good
{ "status": "success", "message": "Operation completed successfully" }
```

### DON'T: Put all info in message

```json
// Bad
{
  "status": "failure",
  "message": "Failed: test_auth (AssertionError), test_export (TimeoutError), missing file"
}

// Good
{
  "status": "failure",
  "message": "Test suite failed - 2 tests failed",
  "errors": [
    "test_auth: AssertionError",
    "test_export: TimeoutError"
  ]
}
```

### DON'T: Use inconsistent field names

```json
// Bad - mixing naming conventions
{
  "status": "success",
  "result": {...},         // should be "details"
  "errorMessages": [...],  // should be "errors"
  "warn": [...]            // should be "warnings"
}
```

### DON'T: Return empty errors/warnings arrays

```json
// Bad - empty arrays when success
{
  "status": "success",
  "message": "Done",
  "errors": [],
  "warnings": []
}

// Good - omit empty optional fields
{
  "status": "success",
  "message": "Done"
}
```

### DON'T: Include stack traces in message

```json
// Bad
{
  "status": "failure",
  "message": "Error at Object.parse (/app/src/index.js:45:12)\n    at Module._compile..."
}

// Good
{
  "status": "failure",
  "message": "JSON parsing failed - invalid input",
  "errors": ["Invalid JSON at position 45: unexpected token"],
  "error_analysis": "The input file contains malformed JSON",
  "suggested_fixes": ["Validate JSON with 'jq .' before processing"]
}
```

## Determining Status

### When to return "success"

- All operations completed without errors
- All tests passed
- All validation checks passed
- Goal fully achieved

### When to return "warning"

- Goal achieved but with non-blocking concerns:
  - Deprecated API usage
  - Performance concerns
  - Missing optional elements
  - Partial success (e.g., 9/10 items processed)
- Tests passed but with warnings
- Operation completed but couldn't do optional cleanup

### When to return "failure"

- Goal was NOT achieved
- Required operation failed
- Tests failed
- Critical validation failed
- Cannot proceed without user intervention

## Migration Checklist

For existing skills that need updating:

- [ ] Replace `success: true/false` with `status: "success"/"failure"`
- [ ] Add `message` field with human-readable summary
- [ ] Move operation-specific data to `details` object
- [ ] Add `errors` array for failure cases
- [ ] Add `warnings` array for warning cases
- [ ] Add `error_analysis` for non-obvious failures
- [ ] Add `suggested_fixes` for recoverable issues
- [ ] Remove deprecated fields (`error_code`, `result`, etc.)
- [ ] Test with response-validator skill
- [ ] Update skill documentation

## Validation

Use the response-validator skill to validate responses:

```bash
# Validate response
./plugins/faber/skills/response-validator/scripts/validate-response.sh '{"status":"success","message":"Done"}'

# Strict validation (all required fields enforced)
./plugins/faber/skills/response-validator/scripts/validate-response.sh '...' --strict
```

## See Also

- [Response Format Specification](../../plugins/faber/docs/RESPONSE-FORMAT.md)
- [Result Handling Guide](../../plugins/faber/docs/RESULT-HANDLING.md)
- [JSON Schema](../../plugins/faber/config/schemas/skill-response.schema.json)
- [Plugin Standards](./FRACTARY-PLUGIN-STANDARDS.md)
