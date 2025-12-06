# Step Response Log Validation Rules

## Required Fields

Every step response log MUST contain:

| Field | Type | Validation |
|-------|------|------------|
| `log_type` | string | Must equal `"step-response"` |
| `response_id` | string | Valid UUID v4 format |
| `run_id` | string | Non-empty, format: `org/project/uuid` |
| `step_id` | string | Pattern: `^(frame|architect|build|evaluate|release|hook):[a-z][a-z0-9-]*$` |
| `phase` | string | One of: frame, architect, build, evaluate, release |
| `type` | string | One of: step, hook, primitive |
| `status` | string | One of: success, warning, failure |
| `message` | string | Non-empty, max 500 characters |
| `timestamp` | string | Valid ISO 8601 datetime |

## Conditional Requirements

### When status is "warning"

- `warnings` array MUST be present and non-empty
- Each warning MUST have: `text`, `severity`, `category`

### When status is "failure"

- `errors` array MUST be present and non-empty
- Each error MUST have: `text`, `severity`, `category`

### When type is "hook"

- `hook_timing` MUST be present
- `hook_timing` MUST be one of: "pre", "post"

## Field Validations

### severity

Valid values (case-sensitive):
- `"low"` - Informational, safe to ignore
- `"medium"` - Should be addressed eventually
- `"high"` - Critical, address now

### category

Valid values (case-sensitive):
- `"deprecation"` - Deprecated API/feature
- `"performance"` - Performance concerns
- `"security"` - Security issues
- `"style"` - Code style/formatting
- `"compatibility"` - Compatibility concerns
- `"validation"` - Validation failures
- `"configuration"` - Configuration issues
- `"other"` - Uncategorized

### step_id

Pattern: `^(frame|architect|build|evaluate|release|hook):[a-z][a-z0-9-]*$`

Valid examples:
- `"build:implement"`
- `"evaluate:test"`
- `"hook:pre-build-lint"`

Invalid examples:
- `"Build:implement"` (uppercase)
- `"build/implement"` (wrong separator)
- `"invalid:step"` (invalid phase)

### duration_ms

- Must be non-negative integer
- Should be present when `completed_at` is present
- Calculated as: `completed_at - timestamp` in milliseconds

## Cross-Field Validations

### Timestamp Consistency

If both `timestamp` and `completed_at` are present:
- `completed_at` MUST be >= `timestamp`
- `duration_ms` SHOULD equal difference in milliseconds

### Attempt Number

- `attempt` MUST start at 1 (not 0)
- For retries, `attempt` increments by 1
- Higher attempt numbers indicate retry attempts

### Status and Content Alignment

| Status | Required Content |
|--------|------------------|
| `success` | No errors, optional warnings |
| `warning` | At least one warning, no errors |
| `failure` | At least one error |

## Redaction Rules

Before logging, MUST redact:

1. **Credentials**: API keys, tokens, passwords
2. **PII**: Email addresses, personal identifiers
3. **Internal paths**: Replace with relative paths when possible

## Validation Errors

When validation fails, log should be:

1. **Rejected** if missing required fields
2. **Accepted with warning** if optional field format is incorrect
3. **Sanitized** if contains sensitive data (redact and accept)

## Schema Version

Current schema version: `1.0.0`

Breaking changes require version increment and migration path.
