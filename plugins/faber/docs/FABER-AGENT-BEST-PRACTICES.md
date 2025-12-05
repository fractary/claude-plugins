# FABER Agent Best Practices

Guidelines for building and using FABER workflow agents effectively.

## Overview

FABER agents orchestrate workflow execution across phases (Frame → Architect → Build → Evaluate → Release). This guide covers best practices for response handling, error recovery, and integration.

## Skill Response Format

All skills invoked by FABER agents MUST return responses using the **standard FABER response format**.

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `status` | enum | `"success"`, `"warning"`, or `"failure"` |
| `message` | string | Human-readable summary (1-2 sentences) |

### Recommended Fields

| Field | Type | When to Include |
|-------|------|-----------------|
| `details` | object | Always - operation-specific data |
| `errors` | string[] | When status is `"failure"` |
| `warnings` | string[] | When status is `"warning"` |
| `error_analysis` | string | When status is `"failure"` - root cause |
| `warning_analysis` | string | When status is `"warning"` - impact |
| `suggested_fixes` | string[] | When issue is recoverable |

### References

- **Schema**: `plugins/faber/config/schemas/skill-response.schema.json`
- **Documentation**: `plugins/faber/docs/RESPONSE-FORMAT.md`
- **Best Practices**: `docs/standards/SKILL-RESPONSE-BEST-PRACTICES.md`
- **Migration Guide**: `docs/MIGRATE-SKILL-RESPONSES.md`

## Response Status Values

### Success
- Goal fully achieved
- No issues encountered
- Workflow proceeds automatically (default behavior)

```json
{
  "status": "success",
  "message": "Branch 'feat/123-add-export' created successfully",
  "details": {
    "branch_name": "feat/123-add-export",
    "base_branch": "main"
  }
}
```

### Warning
- Goal achieved but with concerns
- Non-blocking issues detected
- Workflow may prompt user depending on configuration

```json
{
  "status": "warning",
  "message": "Spec generated with incomplete issue data",
  "details": {
    "spec_path": "/specs/WORK-00123.md",
    "completeness_score": 0.75
  },
  "warnings": [
    "Issue description is empty",
    "No acceptance criteria defined"
  ],
  "warning_analysis": "Spec may be incomplete due to sparse issue data",
  "suggested_fixes": [
    "Add description to issue #123",
    "Review and complete spec sections manually"
  ]
}
```

### Failure
- Goal NOT achieved
- Critical error occurred
- Workflow stops immediately (immutable behavior)

```json
{
  "status": "failure",
  "message": "Tests failed - 5 of 47 tests failed",
  "details": {
    "total_tests": 47,
    "passed": 42,
    "failed": 5
  },
  "errors": [
    "test_login: AssertionError",
    "test_logout: TimeoutError",
    "test_token_refresh: KeyError"
  ],
  "error_analysis": "Auth module tests failing due to session handling issues",
  "suggested_fixes": [
    "Add await to session.cleanup() in logout handler",
    "Check token refresh expiry calculation"
  ]
}
```

## Result Handling Configuration

Steps can configure how different result statuses are handled.

### Default Behavior

```json
{
  "on_success": "continue",   // Proceed automatically
  "on_warning": "continue",   // Log warning, proceed
  "on_failure": "stop"        // IMMUTABLE - always stops
}
```

### Custom Configurations

**Prompt on Warning** (recommended for critical steps):
```json
{
  "result_handling": {
    "on_warning": "prompt"
  }
}
```

**Strict Warning Mode** (treat warnings as failures):
```json
{
  "result_handling": {
    "on_warning": "stop"
  }
}
```

## Validation Tooling

### Audit Your Skills

Run the validation script to check skill compliance:

```bash
# Check all plugins
./scripts/validate-skill-responses.sh

# Check specific plugin
./scripts/validate-skill-responses.sh plugins/faber

# Get detailed report
./scripts/validate-skill-responses.sh --verbose

# JSON output for CI
./scripts/validate-skill-responses.sh --json
```

### Validate Individual Responses

```bash
# Quick format check
./plugins/faber/skills/response-validator/scripts/check-format.sh \
  '{"status":"success","message":"Done"}'

# Full schema validation
./plugins/faber/skills/response-validator/scripts/validate-response.sh \
  '{"status":"success","message":"Done"}'
```

## Agent Implementation Guidelines

### 1. Always Validate Responses

Before processing a skill's response, validate its structure:

```
IF result is null OR result.status not in ["success", "warning", "failure"] THEN
  Treat as failure with appropriate error message
```

### 2. Include Rich Error Context

When returning failures, provide actionable information:

```json
{
  "status": "failure",
  "message": "Brief summary",
  "errors": ["Specific error 1", "Specific error 2"],
  "error_analysis": "Why this happened and what it means",
  "suggested_fixes": ["What the user can do to fix it"]
}
```

### 3. Differentiate Warnings from Failures

- **Warning**: Goal achieved but not perfectly
- **Failure**: Goal NOT achieved

Don't use warning when the operation actually failed.

### 4. Use Structured Details

Put operation-specific data in `details`, not at the root level:

```json
// ✅ Correct
{
  "status": "success",
  "message": "PR created",
  "details": {
    "pr_number": 123,
    "pr_url": "https://..."
  }
}

// ❌ Wrong
{
  "status": "success",
  "message": "PR created",
  "pr_number": 123,
  "pr_url": "https://..."
}
```

### 5. Keep Messages Concise

- 1-2 sentences maximum
- Focus on "what happened"
- Avoid technical IDs and timestamps in message
- Use active voice

```json
// ✅ Good
"message": "Branch created successfully"

// ❌ Bad
"message": "Operation completed at 2025-12-05T10:30:00Z with exit code 0"
```

## Error Pattern Handling

Common error patterns and suggested responses:

| Pattern | Analysis | Suggested Fix |
|---------|----------|---------------|
| `ENOENT` | File or directory not found | Create the missing file or check path |
| `ECONNREFUSED` | Service unavailable | Check if service is running |
| `401 Unauthorized` | Auth failure | Run `gh auth login` or check token |
| `test.*failed` | Test failure | Review failing tests, fix implementation |
| `merge conflict` | Git conflict | Resolve conflicts, then retry |

## Logging and Audit

FABER tracks all step results in workflow state:

```json
{
  "phases": {
    "build": {
      "steps": {
        "implement": {
          "status": "completed",
          "result": {
            "status": "success",
            "message": "Implementation complete"
          }
        }
      }
    }
  }
}
```

For failures, recovery actions are also tracked:

```json
{
  "failure_recoveries": [
    {
      "step": "build:implement",
      "timestamp": "2025-12-05T10:30:00Z",
      "action": "suggested_fix",
      "outcome": "retry_attempted"
    }
  ]
}
```

## Migration Checklist

For existing skills that need updating:

- [ ] Replace `success: true/false` with `status: "success"/"failure"`
- [ ] Add `message` field with human-readable summary
- [ ] Move operation data into `details` object
- [ ] Replace single `error` with `errors` array
- [ ] Add `error_analysis` for failure cases
- [ ] Add `suggested_fixes` for recoverable issues
- [ ] Remove deprecated fields (`error_code`, `result`, etc.)
- [ ] Test with response-validator skill
- [ ] Update skill documentation

See `docs/MIGRATE-SKILL-RESPONSES.md` for detailed migration guide.

## See Also

- [RESPONSE-FORMAT.md](./RESPONSE-FORMAT.md) - Complete response schema
- [RESULT-HANDLING.md](./RESULT-HANDLING.md) - Result handling configuration
- [SKILL-RESPONSE-BEST-PRACTICES.md](../../../docs/standards/SKILL-RESPONSE-BEST-PRACTICES.md) - Developer guide
- [MIGRATE-SKILL-RESPONSES.md](../../../docs/MIGRATE-SKILL-RESPONSES.md) - Migration guide
