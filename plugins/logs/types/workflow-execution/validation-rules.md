# Workflow Execution Log Validation Rules

## Required Fields

Every workflow execution log MUST contain:

| Field | Type | Validation |
|-------|------|------------|
| `log_type` | string | Must equal `"workflow-execution"` |
| `execution_id` | string | Valid UUID v4 format |
| `run_id` | string | Non-empty, format: `org/project/uuid` |
| `started_at` | string | Valid ISO 8601 datetime |
| `final_status` | string | One of: completed, completed_with_warnings, failed, cancelled, paused |
| `phases_summary` | object | Must contain all 5 phases |
| `totals` | object | Must contain aggregated counts |

## Conditional Requirements

### When final_status is "completed_with_warnings"

- `totals.warnings` MUST be > 0
- `aggregated_warnings` array SHOULD be non-empty

### When final_status is "failed"

- `totals.errors` SHOULD be > 0 OR a phase has status "failure"

### When completed_at is present

- `duration_ms` SHOULD be present
- `duration_ms` SHOULD equal `completed_at - started_at` in milliseconds

## Phase Summary Validation

Each phase in `phases_summary` MUST have:

| Field | Type | Validation |
|-------|------|------------|
| `status` | string | One of: success, warning, failure, skipped, not_run |
| `steps_total` | integer | >= 0 |
| `steps_succeeded` | integer | >= 0, <= steps_total |
| `warnings` | integer | >= 0 |
| `errors` | integer | >= 0 |

## Totals Validation

The `totals` object MUST have:

| Field | Type | Validation |
|-------|------|------------|
| `steps_total` | integer | >= 0, should equal sum of phase steps |
| `steps_succeeded` | integer | >= 0, <= steps_total |
| `warnings` | integer | >= 0 |
| `errors` | integer | >= 0 |

### Cross-Validation

- `totals.steps_total` SHOULD equal sum of all `phases_summary.*.steps_total`
- `totals.warnings` SHOULD equal sum of all `phases_summary.*.warnings`
- `totals.errors` SHOULD equal sum of all `phases_summary.*.errors`

## Severity Counts Validation

If `warnings_by_severity` or `errors_by_severity` present:

- Sum of low + medium + high SHOULD equal corresponding total
- All values MUST be >= 0

## Category Counts Validation

If `warnings_by_category` or `errors_by_category` present:

- Sum of all categories SHOULD equal corresponding total
- All values MUST be >= 0
- Only valid categories allowed (deprecation, performance, security, style, compatibility, validation, configuration, other)

## Aggregated Items Validation

Each item in `aggregated_warnings` or `aggregated_errors` MUST have:

| Field | Type | Validation |
|-------|------|------------|
| `phase` | string | One of: frame, architect, build, evaluate, release |
| `step_id` | string | Valid step ID format |
| `text` | string | Non-empty |
| `severity` | string | One of: low, medium, high |
| `category` | string | Valid category |

## Step Response References Validation

Each item in `step_response_refs` SHOULD:

- Be a valid log ID or file path
- Reference an existing step-response log
- Match the run_id of this workflow execution

## Recommended Actions Validation

Each item in `recommended_actions` MUST have:

| Field | Type | Validation |
|-------|------|------------|
| `priority` | integer | >= 1 |
| `description` | string | Non-empty |

Optional fields:
- `source_step` - Valid step ID if present
- `command` - Non-empty if present
- `file` - Valid path if present

## Autonomy Configuration Validation

If `autonomy` object present:

| Field | Valid Values |
|-------|--------------|
| `check_in_frequency` | per-step, per-phase, end-only |
| `warning_tolerance` | none, low, medium, high |
| `error_tolerance` | none, low, medium, high |

## Timestamp Validation

- `started_at` MUST be valid ISO 8601
- `completed_at` MUST be valid ISO 8601 if present
- `completed_at` MUST be >= `started_at`
- All timestamps in aggregated items MUST be between `started_at` and `completed_at`

## Validation Errors

When validation fails:

1. **Rejected** if missing required fields
2. **Accepted with warning** if totals don't sum correctly
3. **Accepted with warning** if references can't be verified

## Schema Version

Current schema version: `1.0.0`

Breaking changes require version increment and migration path.
