# FABER Skill Response Format Specification

This document defines the **standard response format** that ALL workflow skills must return. Consistent responses enable intelligent workflow orchestration, proper error handling, and helpful user prompts.

## Overview

FABER workflow manager expects all step and hook executions to return a standardized response object. This format enables:

- **Intelligent routing**: Manager routes based on status value
- **Rich error handling**: Multiple errors/warnings with analysis
- **Recovery suggestions**: Actionable fixes for failures
- **Audit trail**: Complete logging of execution outcomes
- **Backward compatibility**: Migration path from legacy formats

## Response Schema

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `status` | enum | Execution outcome: `"success"`, `"warning"`, or `"failure"` |
| `message` | string | Human-readable summary (1-2 sentences) |

### Optional Fields

| Field | Type | When to Use |
|-------|------|-------------|
| `details` | object | Operation-specific structured data (artifacts, metrics, paths) |
| `errors` | string[] or object[] | List of error messages or structured error objects |
| `warnings` | string[] or object[] | List of warning messages or structured warning objects |
| `messages` | string[] or object[] | List of informational success messages (for detailed reports) |
| `error_analysis` | string | Root cause analysis for failures |
| `warning_analysis` | string | Impact assessment for warnings |
| `suggested_fixes` | string[] or object[] | Actionable recovery suggestions |

### Structured Warnings/Errors (v2.1)

FABER v2.1 supports structured warnings and errors with severity and category:

```json
{
  "warnings": [
    {
      "text": "Deprecated API: useCallback (will be removed in v3.0)",
      "severity": "medium",
      "category": "deprecation",
      "suggested_fix": "Replace useCallback with useMemo"
    }
  ],
  "errors": [
    {
      "text": "SQL injection vulnerability in user input",
      "severity": "high",
      "category": "security",
      "suggested_fix": "Use parameterized queries"
    }
  ]
}
```

**Backward Compatibility**: Simple strings are still supported:
```json
{
  "warnings": ["Deprecated API usage", "Large file size"]
}
```

When strings are used, severity and category are auto-detected using heuristics.

### Complete Structure

```json
{
  "status": "success" | "warning" | "failure",
  "message": "Human-readable summary of what happened",

  "details": {
    // Operation-specific fields - varies by skill
  },

  "errors": [
    "Error message 1",
    "Error message 2"
  ],

  "warnings": [
    "Warning message 1",
    "Warning message 2"
  ],

  "error_analysis": "Root cause explanation and context",
  "warning_analysis": "Impact assessment and recommendations",

  "suggested_fixes": [
    "Actionable fix suggestion 1",
    "Actionable fix suggestion 2"
  ]
}
```

## Status Values

### Success

Operation completed successfully without issues.

```json
{
  "status": "success",
  "message": "Specification generated successfully",
  "details": {
    "spec_path": "/specs/WORK-00123-feature.md",
    "word_count": 2847,
    "sections": 7
  }
}
```

**Use "success" when:**
- Goal was achieved completely
- No errors or warnings occurred
- Operation is fully complete

**Manager behavior:**
- `on_success: "continue"` (default) - Proceed to next step
- `on_success: "prompt"` - Ask user before proceeding

### Warning

Operation completed but with non-blocking issues that may need attention.

```json
{
  "status": "warning",
  "message": "Build completed with deprecated API usage",
  "details": {
    "files_compiled": 45,
    "warnings_found": 3
  },
  "warnings": [
    "Deprecated API: useCallback (will be removed in v3.0)",
    "Performance: Large bundle size (2.5MB)",
    "Missing type annotations in 2 files"
  ],
  "warning_analysis": "The deprecated API usage should be addressed before the next major version upgrade. The performance warning may impact user experience on slower devices.",
  "suggested_fixes": [
    "Replace useCallback with useMemo for memoization",
    "Code split lazy-loaded components to reduce bundle",
    "Add type annotations to exported functions"
  ]
}
```

**Use "warning" when:**
- Goal was achieved, but with concerns
- Non-critical issues were encountered
- Action is recommended but not required

**Manager behavior:**
- `on_warning: "continue"` (default) - Log and proceed
- `on_warning: "prompt"` - Show intelligent prompt with options
- `on_warning: "stop"` - Treat as failure

### Failure

Operation failed - the goal was not achieved.

```json
{
  "status": "failure",
  "message": "Test suite failed - 5 tests failed",
  "details": {
    "total_tests": 47,
    "passed": 42,
    "failed": 5,
    "skipped": 0
  },
  "errors": [
    "test_auth_login: AssertionError: expected true but got false",
    "test_auth_logout: TimeoutError: HTTP request timeout (30s)",
    "test_token_refresh: KeyError: 'refresh_token' not in response"
  ],
  "error_analysis": "Authentication tests are failing due to session handling issues. The logout handler is not properly awaiting async cleanup, and token refresh validation is incorrect. Root cause appears to be recent changes to the session module.",
  "suggested_fixes": [
    "Add await to session.cleanup() in logout handler",
    "Check token refresh expiry calculation",
    "Verify session state is cleared before new login"
  ]
}
```

**Use "failure" when:**
- Goal was NOT achieved
- Critical errors prevent completion
- Operation cannot proceed

**Manager behavior:**
- `on_failure: "stop"` (**IMMUTABLE** for steps) - Workflow stops
- Shows intelligent failure prompt with errors, analysis, and fixes
- For hooks only: `on_failure: "continue"` allows informational hooks to not block

## Multiple Errors/Warnings

A single response can contain multiple errors or warnings. The `status` field reflects the worst case:

- Any error → `status: "failure"`
- Warnings only → `status: "warning"`
- No issues → `status: "success"`

```json
{
  "status": "failure",
  "message": "Deployment failed with multiple issues",
  "errors": [
    "Health check failed: /api/health returned 503",
    "Database migration failed: column 'user_id' already exists"
  ],
  "warnings": [
    "Deprecated environment variable: USE_SSL (use TLS_ENABLED)",
    "Config file permissions are too open (644, should be 600)"
  ],
  "error_analysis": "The deployment failed due to both health check and migration issues. The migration failure suggests a previous partial deployment may have left the database in an inconsistent state.",
  "suggested_fixes": [
    "Check application logs for startup errors",
    "Run migration rollback: npm run migrate:rollback",
    "Verify database connection parameters"
  ]
}
```

## The `details` Field

The `details` field contains operation-specific structured data. Each skill defines what goes here based on its purpose.

### Examples by Skill Type

**Spec Generator:**
```json
"details": {
  "spec_path": "/specs/WORK-00123-feature.md",
  "word_count": 2847,
  "sections": 7,
  "template_used": "feature"
}
```

**Branch Creator:**
```json
"details": {
  "branch_name": "feat/123-add-csv-export",
  "base_branch": "main",
  "commit_sha": "a1b2c3d4",
  "remote_pushed": true
}
```

**Test Runner:**
```json
"details": {
  "total_tests": 150,
  "passed": 147,
  "failed": 3,
  "skipped": 0,
  "coverage": 87.5,
  "duration_ms": 12340
}
```

**PR Creator:**
```json
"details": {
  "pr_number": 456,
  "pr_url": "https://github.com/org/repo/pull/456",
  "base_branch": "main",
  "head_branch": "feat/123-add-csv-export",
  "reviewers_requested": ["alice", "bob"]
}
```

## Analysis Fields

### error_analysis

Provides **root cause analysis** for failures. Should explain:
- What went wrong and why
- Context that helps understand the failure
- Relationship between multiple errors (if any)

```json
"error_analysis": "The authentication tests are failing because the session module was recently refactored (PR #234). The new async cleanup pattern requires await, but the logout handler is calling cleanup() synchronously. The token refresh failures are a downstream effect - invalid sessions cause token refresh to fail."
```

### warning_analysis

Provides **impact assessment** for warnings. Should explain:
- Potential consequences if not addressed
- Severity and urgency
- Dependencies or timeline concerns

```json
"warning_analysis": "The deprecated API (useCallback) will be removed in React v19, expected Q2 2025. The bundle size warning may cause slow initial load on mobile devices (estimated 3s on 3G). Type annotations are recommended but not blocking."
```

## Suggested Fixes

The `suggested_fixes` array provides **actionable recovery steps**. Each suggestion should be:
- Specific and actionable
- Ordered by likelihood of success
- Clear about what to do

```json
"suggested_fixes": [
  "Add 'await' before session.cleanup() in src/auth/logout.ts:45",
  "Run 'npm run migrate:rollback' then retry deployment",
  "Check DATABASE_URL environment variable is set correctly"
]
```

Manager uses these to offer recovery options in failure/warning prompts.

## Validation

FABER manager validates all responses against the schema. Invalid responses result in:

1. **Missing status**: Error - status is required
2. **Invalid status value**: Error - must be success/warning/failure
3. **Missing message**: Warning - message is strongly recommended
4. **Type mismatches**: Error - arrays must be arrays, objects must be objects

### JSON Schema

The complete schema is available at:
`plugins/faber/config/schemas/skill-response.schema.json`

## Migration from Legacy Formats

### Old Format (Deprecated)

```json
{
  "success": true,
  "result": "Operation completed"
}
```

### New Format (Required)

```json
{
  "status": "success",
  "message": "Operation completed"
}
```

### Migration Checklist

For each skill:

1. [ ] Replace `success: true/false` with `status: "success"/"failure"`
2. [ ] Add `message` field with human-readable summary
3. [ ] Move operation data to `details` object
4. [ ] Add `errors` array for failure cases
5. [ ] Add `warnings` array for warning cases
6. [ ] Add `error_analysis` for non-obvious failures
7. [ ] Add `suggested_fixes` for recoverable issues
8. [ ] Test response validation

## Best Practices

### DO

- Always return `status` and `message`
- Include specific error messages in `errors` array
- Provide actionable suggestions in `suggested_fixes`
- Use `details` for structured operation data
- Make messages human-readable and concise

### DON'T

- Don't return bare strings or booleans
- Don't put error text only in `message` - use `errors` array
- Don't include stack traces in user-facing messages
- Don't mix concerns - keep analysis separate from suggestions
- Don't use inconsistent field names (e.g., `result` vs `details`)

### Message Writing Guidelines

**Good messages:**
- "Specification generated successfully"
- "Build completed with 3 warnings"
- "Test suite failed - 5 tests failed"
- "Branch 'feat/123-export' created from main"

**Bad messages:**
- "Done" (too vague)
- "Error occurred" (no useful information)
- "SUCCESS!!!" (unprofessional)
- "Operation completed at 2025-12-05T10:30:00Z with result code 0" (too technical)

## Integration with Result Handling

The response `status` maps to workflow `result_handling` configuration:

| Response Status | Triggers | Default Action |
|-----------------|----------|----------------|
| `"success"` | `on_success` | `"continue"` |
| `"warning"` | `on_warning` | `"continue"` |
| `"failure"` | `on_failure` | `"stop"` (IMMUTABLE for steps) |

See [RESULT-HANDLING.md](./RESULT-HANDLING.md) for complete result handling documentation.

## Severity Levels

| Severity | Description | Examples |
|----------|-------------|----------|
| `low` | Informational, safe to ignore | Style issues, minor lint warnings |
| `medium` | Should be addressed eventually | Deprecated APIs, performance hints |
| `high` | Critical, address immediately | Security issues, breaking changes |

## Categories

| Category | Description | Examples |
|----------|-------------|----------|
| `deprecation` | Deprecated/obsolete features | "API will be removed in v3.0" |
| `performance` | Performance concerns | "Large bundle size", "Slow query" |
| `security` | Security vulnerabilities | "SQL injection", "XSS risk" |
| `style` | Code style/formatting | "Line too long", "Missing semicolon" |
| `compatibility` | Platform/version issues | "Not supported in Node 14" |
| `validation` | Data validation failures | "Missing required field" |
| `configuration` | Configuration problems | "Invalid config value" |
| `other` | Uncategorized | Default fallback |

## Auto-Detection

When warnings/errors are provided as strings, FABER auto-detects severity and category:

### Severity Detection Keywords

- **high**: `critical`, `fatal`, `security`, `vulnerability`, `breaking`
- **medium**: `deprecated`, `warning`, `should`, `performance`
- **low**: `style`, `format`, `minor`, `optional`

### Category Detection Keywords

- **security**: `security`, `vulnerability`, `injection`, `xss`, `auth`
- **deprecation**: `deprecated`, `obsolete`, `removed in`
- **performance**: `slow`, `memory`, `cpu`, `timeout`
- **validation**: `invalid`, `required`, `schema`

See `skills/faber-manager/workflow/severity-detection.md` for complete heuristics.

## See Also

- [AUTONOMY.md](./AUTONOMY.md) - Two-dimensional autonomy model with tolerance thresholds
- [RESULT-HANDLING.md](./RESULT-HANDLING.md) - Workflow result handling behavior
- [Schema](../config/schemas/skill-response.schema.json) - JSON Schema for validation
- [Best Practices](../../docs/standards/SKILL-RESPONSE-BEST-PRACTICES.md) - Skill development guide
