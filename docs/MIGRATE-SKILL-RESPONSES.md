# Skill Response Migration Guide

This guide helps you migrate existing skills to use the standardized FABER response format.

## Overview

FABER workflows expect skills to return responses in a standardized JSON format with three status values: `success`, `warning`, and `failure`. This enables consistent result handling, rich error reporting, and intelligent workflow routing.

**Schema Reference**: `plugins/faber/config/schemas/skill-response.schema.json`
**Best Practices**: `docs/standards/SKILL-RESPONSE-BEST-PRACTICES.md`

## Quick Migration Checklist

- [ ] Replace `success: true/false` with `status: "success"/"failure"`
- [ ] Replace `status: "error"` with `status: "failure"`
- [ ] Add required `message` field with human-readable summary
- [ ] Move operation-specific data into `details` object
- [ ] Replace single `error` string with `errors` array
- [ ] Replace single `warning` string with `warnings` array
- [ ] Add `error_analysis` for failure cases (root cause explanation)
- [ ] Add `warning_analysis` for warning cases (impact assessment)
- [ ] Add `suggested_fixes` array for recoverable issues
- [ ] Remove deprecated fields (`error_code`, `result`, `data`, etc.)
- [ ] Remove empty arrays when not applicable

## Migration Patterns

### Pattern 1: Boolean Success to Status

**Before:**
```json
{
  "success": true,
  "result": {
    "branch_name": "feat/123-add-export",
    "commit_sha": "abc123"
  }
}
```

**After:**
```json
{
  "status": "success",
  "message": "Branch 'feat/123-add-export' created successfully",
  "details": {
    "branch_name": "feat/123-add-export",
    "commit_sha": "abc123"
  }
}
```

### Pattern 2: Error Status to Failure

**Before:**
```json
{
  "status": "error",
  "error": "Branch already exists",
  "code": 3
}
```

**After:**
```json
{
  "status": "failure",
  "message": "Failed to create branch - already exists",
  "details": {
    "operation": "create-branch",
    "branch_name": "feat/123-add-export"
  },
  "errors": [
    "Branch 'feat/123-add-export' already exists"
  ],
  "error_analysis": "A branch with this name already exists in the repository",
  "suggested_fixes": [
    "Use a different branch name",
    "Delete existing branch: git branch -d feat/123-add-export",
    "Switch to existing branch: git checkout feat/123-add-export"
  ]
}
```

### Pattern 3: Single Error to Errors Array

**Before:**
```json
{
  "status": "error",
  "error": "Authentication failed",
  "details": "Token expired"
}
```

**After:**
```json
{
  "status": "failure",
  "message": "Authentication failed",
  "errors": [
    "GitHub API authentication failed",
    "Token has expired or been revoked"
  ],
  "error_analysis": "The authentication token is no longer valid",
  "suggested_fixes": [
    "Run: gh auth login",
    "Generate new token at github.com/settings/tokens",
    "Set GITHUB_TOKEN environment variable"
  ]
}
```

### Pattern 4: Adding Warning Status

**Before:**
```json
{
  "success": true,
  "result": {
    "processed": 9,
    "total": 10
  },
  "note": "1 item skipped due to permissions"
}
```

**After:**
```json
{
  "status": "warning",
  "message": "Operation completed with 1 item skipped",
  "details": {
    "processed": 9,
    "total": 10,
    "skipped": 1
  },
  "warnings": [
    "1 item skipped due to insufficient permissions"
  ],
  "warning_analysis": "Most items processed successfully but some were skipped",
  "suggested_fixes": [
    "Check permissions for skipped items",
    "Retry with elevated permissions if needed"
  ]
}
```

### Pattern 5: Nested Result to Details

**Before:**
```json
{
  "status": "success",
  "operation": "create-pr",
  "result": {
    "pr_number": 456,
    "pr_url": "https://github.com/owner/repo/pull/456"
  }
}
```

**After:**
```json
{
  "status": "success",
  "message": "PR #456 created successfully",
  "details": {
    "operation": "create-pr",
    "pr_number": 456,
    "pr_url": "https://github.com/owner/repo/pull/456"
  }
}
```

## Field Mapping Reference

| Old Field | New Field | Notes |
|-----------|-----------|-------|
| `success: true` | `status: "success"` | |
| `success: false` | `status: "failure"` | |
| `status: "error"` | `status: "failure"` | |
| `error` (string) | `errors` (array) | Wrap in array |
| `error_message` | `message` + `errors` | Summary in message, details in errors |
| `result` | `details` | Rename to details |
| `data` | `details` | Rename to details |
| `output` | `details` | Rename to details |
| `code` | - | Remove (use error_analysis instead) |
| `error_code` | - | Remove (use error_analysis instead) |
| `warning` (string) | `warnings` (array) | Wrap in array |
| `note` | `warnings` or `warning_analysis` | Depending on content |
| `suggestion` | `suggested_fixes` | Wrap in array |
| `can_retry` | - | Remove (implied by suggested_fixes) |

## Response Status Decision Tree

Use this to determine which status to return:

```
Was the primary goal achieved?
├─ YES: Was there anything non-ideal?
│   ├─ NO → status: "success"
│   └─ YES → status: "warning"
│       - Deprecation notices
│       - Performance concerns
│       - Partial completion
│       - Missing optional elements
│       - Non-critical issues
└─ NO → status: "failure"
    - Operation failed
    - Required validation failed
    - Critical error occurred
    - Cannot proceed without intervention
```

## SKILL.md OUTPUTS Section Template

Replace your skill's `<OUTPUTS>` section with this template:

```markdown
<OUTPUTS>
Return results using the **standard FABER response format**.

See: `plugins/faber/docs/RESPONSE-FORMAT.md` for complete specification.

**Success Response:**
```json
{
  "status": "success",
  "message": "[Brief description of successful outcome]",
  "details": {
    // Operation-specific data
  }
}
```

**Warning Response:**
```json
{
  "status": "warning",
  "message": "[Brief description with warning summary]",
  "details": {
    // Same structure as success
  },
  "warnings": [
    "[Specific warning 1]",
    "[Specific warning 2]"
  ],
  "warning_analysis": "[Explanation of warning impact]",
  "suggested_fixes": [
    "[Actionable fix 1]"
  ]
}
```

**Failure Response:**
```json
{
  "status": "failure",
  "message": "[Brief description of failure]",
  "details": {
    // Partial results if any
  },
  "errors": [
    "[Specific error 1]",
    "[Specific error 2]"
  ],
  "error_analysis": "[Root cause explanation]",
  "suggested_fixes": [
    "[Actionable fix 1]",
    "[Actionable fix 2]"
  ]
}
```
</OUTPUTS>
```

## Validation

After migrating, validate your responses:

```bash
# Quick format check
./plugins/faber/skills/response-validator/scripts/check-format.sh '{"status":"success","message":"Done"}'

# Full schema validation
./plugins/faber/skills/response-validator/scripts/validate-response.sh '{"status":"success","message":"Done"}'

# Strict validation (all recommended fields)
./plugins/faber/skills/response-validator/scripts/validate-response.sh '...' --strict
```

## Common Migration Mistakes

### 1. Forgetting the message field
```json
// WRONG - missing message
{"status": "success", "details": {...}}

// CORRECT
{"status": "success", "message": "Operation completed", "details": {...}}
```

### 2. Using error instead of errors array
```json
// WRONG - single error string
{"status": "failure", "error": "Something failed"}

// CORRECT - errors array
{"status": "failure", "message": "Something failed", "errors": ["Something failed"]}
```

### 3. Including empty arrays
```json
// WRONG - empty arrays when success
{"status": "success", "message": "Done", "errors": [], "warnings": []}

// CORRECT - omit empty optional fields
{"status": "success", "message": "Done"}
```

### 4. Using status: "error" instead of "failure"
```json
// WRONG - invalid status value
{"status": "error", "message": "Failed"}

// CORRECT - use "failure"
{"status": "failure", "message": "Failed"}
```

### 5. Putting operation data at root level
```json
// WRONG - operation data at root
{"status": "success", "message": "Done", "pr_number": 123, "pr_url": "..."}

// CORRECT - operation data in details
{"status": "success", "message": "Done", "details": {"pr_number": 123, "pr_url": "..."}}
```

## Migration Examples by Plugin

### Repo Plugin Skills

**branch-manager, pr-manager, commit-creator, tag-manager:**
- Move operation-specific fields into `details`
- Add `message` summarizing the operation
- Add platform info in details
- Include `suggested_fixes` for common errors

### Work Plugin Skills

**issue-fetcher, issue-creator, comment-creator:**
- Wrap issue/comment data in `details.issue` or `details.comment`
- Add warning for auto-detected platforms (no config)
- Include authentication fixes in `suggested_fixes`

### Spec Plugin Skills

**spec-generator, spec-validator, spec-archiver:**
- Move spec_path and metadata into `details`
- Use warning for partial completeness
- Include validation scores in details

### FABER Phase Skills

**frame, architect, build, evaluate, release:**
- Already updated - use as reference
- Note how phase-specific artifacts are in `details`
- Review GO/NO-GO decision handling in evaluate

## Testing Your Migration

1. **Unit test responses**: Verify JSON structure
2. **Schema validation**: Use response-validator skill
3. **Integration test**: Run through FABER workflow
4. **Error scenarios**: Test failure and warning paths

## See Also

- [Response Format Specification](../plugins/faber/docs/RESPONSE-FORMAT.md)
- [Best Practices Guide](./standards/SKILL-RESPONSE-BEST-PRACTICES.md)
- [JSON Schema](../plugins/faber/config/schemas/skill-response.schema.json)
- [Skill Response Template](../plugins/faber/templates/skill-response-template.md)
