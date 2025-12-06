---
log_type: step-response
response_id: "{uuid}"
run_id: "{run_id}"
step_id: "{phase}:{step_name}"
phase: "{phase}"
type: "{step|hook|primitive}"
attempt: {attempt_number}
status: "{success|warning|failure}"
timestamp: "{ISO8601}"
---

# Step Response: {step_name}

**Run**: `{run_id}`
**Step**: `{step_id}`
**Phase**: {phase}
**Type**: {type}
**Attempt**: {attempt}
**Status**: {status}
**Duration**: {duration_ms}ms

## Message

{message}

## Details

```json
{details_json}
```

## Warnings ({warning_count})

{#if warnings}
| Severity | Category | Message | Suggested Fix |
|----------|----------|---------|---------------|
{#each warnings}
| {severity} | {category} | {text} | {suggested_fix} |
{/each}

### Warning Analysis

{warning_analysis}
{/if}

## Errors ({error_count})

{#if errors}
| Severity | Category | Message | Suggested Fix |
|----------|----------|---------|---------------|
{#each errors}
| {severity} | {category} | {text} | {suggested_fix} |
{/each}

### Error Analysis

{error_analysis}
{/if}

## Suggested Fixes

{#if suggested_fixes}
{#each suggested_fixes}
### {index}. {description}

{#if command}
```bash
{command}
```
{/if}

{#if file}
**File**: `{file}`
{/if}

{/each}
{else}
No suggested fixes available.
{/if}

## Timing

- **Started**: {timestamp}
- **Completed**: {completed_at}
- **Duration**: {duration_ms}ms
