# Workflow Execution Log Standards

## Purpose

Workflow execution logs provide aggregated summaries of complete FABER workflow runs. They capture phase totals, collected warnings/errors, and references to individual step-response logs.

**Use for**:
- End-of-workflow summaries
- Aggregated warning and error reporting
- Phase-level execution statistics
- Workflow audit trails
- Pattern analysis across runs

**Do NOT use for**:
- Individual step results (use `step-response` type)
- Build compilation logs (use `build` type)
- Real-time status updates (use events)
- In-progress workflow state (use state.json)

---

## Required Sections

Every workflow execution log MUST include:

1. **Identity Fields**
   - `log_type: workflow-execution`
   - `execution_id` - UUID for this summary
   - `run_id` - Workflow run identifier

2. **Timing**
   - `started_at` - Workflow start timestamp
   - `completed_at` - Workflow completion timestamp
   - `duration_ms` - Total duration

3. **Status**
   - `final_status` - Outcome (completed, completed_with_warnings, failed, etc.)

4. **Phase Summary**
   - Status and statistics for each FABER phase

5. **Totals**
   - Aggregated counts for steps, warnings, errors

---

## Final Status Values

| Status | Meaning |
|--------|---------|
| `completed` | All phases succeeded with no warnings or errors |
| `completed_with_warnings` | All phases completed but warnings were collected |
| `failed` | Workflow stopped due to unrecoverable error |
| `cancelled` | User cancelled the workflow |
| `paused` | Workflow paused awaiting user input |

---

## Phase Summary Structure

Each phase summary includes:

```json
{
  "status": "success|warning|failure|skipped|not_run",
  "steps_total": 4,
  "steps_succeeded": 3,
  "warnings": 2,
  "errors": 0,
  "duration_ms": 45230
}
```

---

## Aggregation Rules

### Warning Aggregation

All warnings from step-response logs are collected into `aggregated_warnings`:

```json
{
  "phase": "build",
  "step_id": "build:implement",
  "text": "Deprecated API usage",
  "severity": "medium",
  "category": "deprecation",
  "analysis": "Should be addressed before v3.0",
  "suggested_fix": "Replace callOldAPI with callNewAPI",
  "timestamp": "2025-12-06T10:30:00Z"
}
```

### Error Aggregation

Errors from tolerated failures (when `error_tolerance` allows continuation):

```json
{
  "phase": "evaluate",
  "step_id": "evaluate:lint",
  "text": "5 lint errors in src/utils.ts",
  "severity": "low",
  "category": "style",
  "analysis": "Style violations, non-blocking",
  "suggested_fix": "Run npm run lint:fix",
  "timestamp": "2025-12-06T10:35:00Z"
}
```

### Category Counts

Aggregate counts by category for filtering:

```json
{
  "warnings_by_category": {
    "deprecation": 2,
    "style": 1,
    "performance": 0
  }
}
```

### Severity Counts

Aggregate counts by severity:

```json
{
  "warnings_by_severity": {
    "low": 1,
    "medium": 2,
    "high": 0
  }
}
```

---

## Report Generation

The workflow execution log feeds the end-of-workflow report:

### Summary Format
- Phase summary with status icons
- Warning/error counts
- High-level statistics

### Detailed Format (includes messages)
- All of summary format, plus:
- Individual step success messages
- Full timing breakdown
- Artifact list

### Minimal Format
- Phase summary only
- Total counts
- No individual issues

---

## Recommended Actions

Prioritized list of suggested fixes:

```json
{
  "recommended_actions": [
    {
      "priority": 1,
      "description": "Fix deprecated API usage in build:implement",
      "source_step": "build:implement",
      "command": "npx codemod deprecate-api"
    },
    {
      "priority": 2,
      "description": "Review spec acceptance criteria",
      "source_step": "architect:generate-spec",
      "file": "/specs/WORK-00237-feature.md"
    }
  ]
}
```

Actions are ordered by:
1. Severity (high > medium > low)
2. Category priority (security > compatibility > deprecation > others)
3. Phase order (earlier phases first)

---

## Relationship to Step Response Logs

```
workflow-execution (this type)
  ├── step_response_refs: ["log-001", "log-002", ...]
  ├── aggregated_warnings: [...flattened from all steps...]
  └── aggregated_errors: [...flattened from all steps...]

step-response (referenced logs)
  ├── step-response-001.json
  ├── step-response-002.json
  └── ...
```

The `step_response_refs` array contains IDs or paths to individual step-response logs, enabling drill-down from summary to detail.

---

## Autonomy Configuration Recording

Record the autonomy settings used for this run:

```json
{
  "autonomy": {
    "check_in_frequency": "per-phase",
    "warning_tolerance": "low",
    "error_tolerance": "none"
  }
}
```

This enables post-hoc analysis of how autonomy settings affected workflow outcomes.

---

## Global Limits

When global limits are reached, record in the log:

```json
{
  "limits_reached": {
    "max_total_warnings": {
      "limit": 50,
      "actual": 50,
      "action": "truncated"
    }
  }
}
```

---

## Example Workflow Execution Log

```json
{
  "log_type": "workflow-execution",
  "execution_id": "550e8400-e29b-41d4-a716-446655440001",
  "workflow_id": "workflow-237-20251206T100000Z",
  "run_id": "fractary/claude-plugins/abc123",
  "target": "feat/237-workflow-response-aggregation",
  "work_id": "237",
  "started_at": "2025-12-06T10:00:00Z",
  "completed_at": "2025-12-06T10:05:32Z",
  "duration_ms": 332000,
  "final_status": "completed_with_warnings",
  "autonomy": {
    "check_in_frequency": "per-phase",
    "warning_tolerance": "low",
    "error_tolerance": "none"
  },
  "phases_summary": {
    "frame": { "status": "success", "steps_total": 3, "steps_succeeded": 3, "warnings": 0, "errors": 0, "duration_ms": 15000 },
    "architect": { "status": "warning", "steps_total": 2, "steps_succeeded": 2, "warnings": 1, "errors": 0, "duration_ms": 45000 },
    "build": { "status": "warning", "steps_total": 4, "steps_succeeded": 4, "warnings": 2, "errors": 0, "duration_ms": 180000 },
    "evaluate": { "status": "success", "steps_total": 2, "steps_succeeded": 2, "warnings": 0, "errors": 0, "duration_ms": 60000 },
    "release": { "status": "success", "steps_total": 2, "steps_succeeded": 2, "warnings": 0, "errors": 0, "duration_ms": 32000 }
  },
  "totals": {
    "steps_total": 13,
    "steps_succeeded": 13,
    "steps_warned": 3,
    "steps_failed": 0,
    "hooks_total": 4,
    "warnings": 3,
    "errors": 0,
    "warnings_by_severity": { "low": 1, "medium": 2, "high": 0 },
    "warnings_by_category": { "deprecation": 1, "validation": 1, "style": 1 },
    "retries_used": 0
  },
  "aggregated_warnings": [
    {
      "phase": "architect",
      "step_id": "architect:generate-spec",
      "text": "Spec has incomplete acceptance criteria",
      "severity": "medium",
      "category": "validation",
      "analysis": "Consider adding measurable success conditions",
      "timestamp": "2025-12-06T10:01:00Z"
    }
  ],
  "step_response_refs": [
    "step-response-abc123-frame:fetch-work-1-20251206T100000Z",
    "step-response-abc123-architect:generate-spec-1-20251206T100100Z"
  ],
  "artifacts": {
    "branch_name": "feat/237-workflow-response-aggregation",
    "spec_path": "/specs/WORK-00237-workflow-response-aggregation.md",
    "pr_number": "255",
    "pr_url": "https://github.com/fractary/claude-plugins/pull/255"
  },
  "recommended_actions": [
    {
      "priority": 1,
      "description": "Fix deprecated API usage in build:implement",
      "source_step": "build:implement",
      "command": "npx codemod deprecate-api"
    }
  ]
}
```

---

## Best Practices

1. **Generate at completion**: Create this log when workflow ends (success or failure)
2. **Include all references**: Link to every step-response log
3. **Flatten warnings/errors**: Aggregate for easy scanning
4. **Calculate totals**: Pre-compute counts for efficient querying
5. **Prioritize actions**: Order recommended actions by importance
6. **Record autonomy**: Note the settings used for this run
7. **Track limits**: Record if any limits were reached
