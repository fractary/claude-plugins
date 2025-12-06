---
spec_id: WORK-00237-workflow-response-aggregation
work_id: 237
issue_url: https://github.com/fractary/claude-plugins/issues/237
title: State Management Should Help Track Workflow Phase/Step Responses
type: feature
status: draft
created: 2025-12-06
updated: 2025-12-06
author: claude
validated: false
source: conversation+issue
---

# Feature Specification: Workflow Response Aggregation, Reporting, and Autonomy Redesign

**Issue**: [#237](https://github.com/fractary/claude-plugins/issues/237)
**Type**: Feature
**Status**: Draft
**Created**: 2025-12-06

## Summary

Enhance the FABER workflow system with three interconnected capabilities:

1. **Always-On Response Aggregation**: All step and hook responses (warnings, errors, messages) are automatically collected throughout workflow execution and persisted via `fractary-logs`.

2. **End-of-Workflow Reporting**: An interactive summary report displays aggregated responses organized by phase/step and by category, with actionable options for addressing issues.

3. **Autonomy Model Redesign**: Replace the current unclear autonomy levels (`dry-run`, `assist`, `guarded`, `autonomous`) with a two-dimensional model controlling check-in frequency and tolerance thresholds.

Together, these changes provide complete visibility into workflow execution while giving users precise control over when to pause for review and what severity of issues to tolerate.

## User Stories

### Story 1: Deferred Issue Review

**As a** developer running an automated FABER workflow
**I want** all warnings and errors collected and shown at the end
**So that** I can run workflows to completion while still being informed of all issues

**Acceptance Criteria**:
- [ ] All step and hook responses are automatically captured
- [ ] Responses are persisted to fractary-logs (survives session end)
- [ ] End-of-workflow report displays issues organized by phase/step
- [ ] Report includes "by category" view for cross-cutting analysis

### Story 2: Configurable Check-in Points

**As a** developer debugging a sensitive workflow
**I want** to configure how frequently the workflow pauses for review
**So that** I can be more hands-on when needed or fully automated when confident

**Acceptance Criteria**:
- [ ] Can configure check-in at every step (`per-step`)
- [ ] Can configure check-in at every phase (`per-phase`)
- [ ] Can configure check-in only at workflow end (`end-only`)
- [ ] Check-in shows accumulated responses since last check-in

### Story 3: Tolerance-Based Continuation

**As a** developer running exploratory workflows
**I want** to set tolerance thresholds for warnings and errors
**So that** low-priority issues don't interrupt my workflow

**Acceptance Criteria**:
- [ ] Can set separate tolerance thresholds for warnings vs errors
- [ ] Workflow continues past issues at or below tolerance level
- [ ] Issues above tolerance trigger stop/prompt per result_handling
- [ ] All issues (tolerated or not) appear in final report

### Story 4: Interactive Issue Resolution

**As a** developer reviewing the end-of-workflow report
**I want** actionable options for addressing issues
**So that** I can quickly apply suggested fixes or run diagnostic commands

**Acceptance Criteria**:
- [ ] Report offers specific commands to execute for fixes
- [ ] User can choose to apply fixes interactively
- [ ] Skipped fixes are noted for manual follow-up

## Functional Requirements

### Response Aggregation

- **FR1**: Automatically capture all step responses (status, message, warnings, errors, details) after each step execution
- **FR2**: Automatically capture all hook responses after each hook execution
- **FR3**: Assign severity level (low/medium/high) to each warning and error
- **FR4**: Assign category to each warning and error (e.g., deprecation, performance, security, style)
- **FR5**: Persist responses to `fractary-logs` using `step-response` log type
- **FR6**: Create `workflow-execution` summary log at workflow completion
- **FR7**: Include retry attempts in response logging (all attempts, not just final)

### Reporting

- **FR8**: Generate end-of-workflow report showing all aggregated responses
- **FR9**: Organize report by phase/step (primary view)
- **FR10**: Provide "by category" cross-cutting view in report
- **FR11**: Include success messages in "detailed" report format only
- **FR12**: Provide interactive options for applying suggested fixes
- **FR13**: Show specific commands user can execute
- **FR14**: Always display report (even on clean success - confirms success)

### Autonomy Redesign

- **FR15**: Implement `check_in_frequency` setting: `per-step`, `per-phase`, `end-only`
- **FR16**: Implement `warning_tolerance` setting: `none`, `low`, `medium`, `high`
- **FR17**: Implement `error_tolerance` setting: `none`, `low`, `medium`, `high`
- **FR18**: Deprecate current autonomy levels (`dry-run`, `assist`, `guarded`, `autonomous`)
- **FR19**: Provide migration path from old autonomy levels to new model
- **FR20**: At each check-in point, display responses accumulated since last check-in

### Limits and Safety

- **FR21**: Implement `max_total_warnings` global limit (default: 50)
- **FR22**: Implement `max_total_errors` global limit (default: 20)
- **FR23**: When limit reached, option to stop or truncate further collection

## Non-Functional Requirements

- **NFR1**: Response capture must not significantly impact workflow execution time (<50ms overhead per step)
- **NFR2**: Log storage must be bounded via fractary-logs retention policies
- **NFR3**: Must be backward compatible - existing workflows work without modification
- **NFR4**: Report generation must handle large numbers of responses gracefully (<500ms for 100 items)

## Technical Design

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      FABER Workflow Manager                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │   Step/Hook  │───▶│   Response   │───▶│  fractary-   │       │
│  │   Execution  │    │   Capture    │    │    logs      │       │
│  └──────────────┘    └──────────────┘    └──────────────┘       │
│         │                   │                    │               │
│         │                   ▼                    │               │
│         │            ┌──────────────┐            │               │
│         │            │   Severity   │            │               │
│         │            │   + Category │            │               │
│         │            │   Assignment │            │               │
│         │            └──────────────┘            │               │
│         │                   │                    │               │
│         ▼                   ▼                    ▼               │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Autonomy Controller                    │   │
│  │  ┌─────────────────┐    ┌─────────────────────────────┐  │   │
│  │  │ Check-in        │    │ Tolerance Evaluation        │  │   │
│  │  │ Frequency       │    │ warning_tolerance           │  │   │
│  │  │ (per-step,      │    │ error_tolerance             │  │   │
│  │  │  per-phase,     │    │ (none/low/medium/high)      │  │   │
│  │  │  end-only)      │    └─────────────────────────────┘  │   │
│  │  └─────────────────┘                                      │   │
│  └──────────────────────────────────────────────────────────┘   │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Report Generator                       │   │
│  │  - By Phase/Step view                                     │   │
│  │  - By Category view                                       │   │
│  │  - Interactive fix options                                │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Data Model

#### Response Object (Captured per Step/Hook)

```json
{
  "response_id": "uuid-v4",
  "workflow_id": "workflow-uuid",
  "run_id": "run-uuid",
  "step_id": "build:implement",
  "step_name": "implement",
  "phase": "build",
  "type": "step",
  "attempt": 1,
  "status": "warning",
  "message": "Build completed with deprecated API usage",
  "details": {
    "files_compiled": 45,
    "warnings_found": 3
  },
  "warnings": [
    {
      "text": "Deprecated API: useCallback (will be removed in v3.0)",
      "severity": "medium",
      "category": "deprecation",
      "suggested_fix": "Replace useCallback with useMemo"
    }
  ],
  "errors": [],
  "warning_analysis": "The deprecated API should be addressed before v3.0",
  "error_analysis": null,
  "suggested_fixes": [
    "Replace useCallback with useMemo for memoization"
  ],
  "timestamp": "2025-12-06T10:30:00Z"
}
```

#### Severity Levels

| Level | Description | Tolerance Meaning |
|-------|-------------|-------------------|
| `low` | Informational, safe to ignore | `low` tolerance = continue past low-severity issues |
| `medium` | Should be addressed eventually | `medium` tolerance = continue past low and medium |
| `high` | Critical, should be addressed now | `high` tolerance = continue past all (dangerous) |

#### Categories

Standard categories for classification:

- `deprecation` - Deprecated API/feature usage
- `performance` - Performance concerns
- `security` - Security issues
- `style` - Code style/formatting
- `compatibility` - Compatibility concerns
- `validation` - Validation failures
- `configuration` - Configuration issues
- `other` - Uncategorized

### Autonomy Configuration

#### New Configuration Schema

```json
{
  "autonomy": {
    "check_in_frequency": "per-phase",
    "warning_tolerance": "low",
    "error_tolerance": "none"
  }
}
```

| Field | Type | Values | Default | Description |
|-------|------|--------|---------|-------------|
| `check_in_frequency` | enum | `per-step`, `per-phase`, `end-only` | `per-phase` | How often to pause for review |
| `warning_tolerance` | enum | `none`, `low`, `medium`, `high` | `low` | Max warning severity to tolerate |
| `error_tolerance` | enum | `none`, `low`, `medium`, `high` | `none` | Max error severity to tolerate |

#### Migration from Old Autonomy Levels

| Old Level | New Equivalent | Rationale |
|-----------|---------------|-----------|
| `dry-run` | `check_in_frequency: "per-step"`, `warning_tolerance: "none"`, `error_tolerance: "none"` | Most conservative |
| `assist` | `check_in_frequency: "per-phase"`, `warning_tolerance: "none"`, `error_tolerance: "none"` | Phase-level review |
| `guarded` | `check_in_frequency: "per-phase"`, `warning_tolerance: "low"`, `error_tolerance: "none"` | Tolerate minor warnings |
| `autonomous` | `check_in_frequency: "end-only"`, `warning_tolerance: "medium"`, `error_tolerance: "low"` | Minimal interruption |

#### Tolerance Evaluation Logic

```
FOR each response:
  FOR each warning in response.warnings:
    IF warning.severity > warning_tolerance:
      TRIGGER result_handling.on_warning behavior
    ELSE:
      COLLECT warning, CONTINUE

  FOR each error in response.errors:
    IF error.severity > error_tolerance:
      TRIGGER result_handling.on_failure behavior (stop)
    ELSE:
      COLLECT error, CONTINUE
```

### fractary-logs Integration

#### Log Type: `step-response`

Individual response records per step/hook execution.

```json
{
  "log_type": "step-response",
  "workflow_id": "...",
  "run_id": "...",
  "step_id": "build:implement",
  "phase": "build",
  "type": "step",
  "attempt": 1,
  "status": "warning",
  "message": "...",
  "warnings": [...],
  "errors": [...],
  "details": {...},
  "timestamp": "..."
}
```

#### Log Type: `workflow-execution`

Aggregated summary at workflow completion.

```json
{
  "log_type": "workflow-execution",
  "workflow_id": "...",
  "run_id": "...",
  "target": "feat/237-response-aggregation",
  "work_id": "237",
  "started_at": "...",
  "completed_at": "...",
  "duration_ms": 332000,
  "final_status": "completed_with_warnings",
  "phases_summary": {
    "frame": { "status": "success", "steps": 3, "warnings": 0, "errors": 0 },
    "architect": { "status": "warning", "steps": 2, "warnings": 1, "errors": 0 },
    "build": { "status": "warning", "steps": 4, "warnings": 2, "errors": 0 },
    "evaluate": { "status": "success", "steps": 2, "warnings": 0, "errors": 0 },
    "release": { "status": "success", "steps": 2, "warnings": 0, "errors": 0 }
  },
  "totals": {
    "warnings": 3,
    "errors": 0,
    "warnings_by_severity": { "low": 1, "medium": 2, "high": 0 },
    "warnings_by_category": { "deprecation": 2, "style": 1 }
  },
  "step_response_refs": [
    "log-id-1", "log-id-2", "..."
  ]
}
```

### Report Format

#### Summary Format (Default)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         WORKFLOW EXECUTION REPORT                           │
├─────────────────────────────────────────────────────────────────────────────┤
│  Target: feat/237-workflow-response-aggregation                             │
│  Work Item: #237                                                            │
│  Duration: 5m 32s                                                           │
│  Status: Completed with warnings                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  PHASE SUMMARY                                                              │
│  ─────────────                                                              │
│  ✅ Frame      3/3 steps                                                    │
│  ⚠️  Architect  2/2 steps, 1 warning (medium)                               │
│  ⚠️  Build      4/4 steps, 2 warnings (1 medium, 1 low)                     │
│  ✅ Evaluate   2/2 steps                                                    │
│  ✅ Release    2/2 steps                                                    │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  WARNINGS BY PHASE/STEP (3)                                                 │
│  ──────────────────────────                                                 │
│                                                                             │
│  📍 architect:generate-spec [medium] [validation]                           │
│     Spec has incomplete acceptance criteria                                 │
│     └─ Analysis: Consider adding measurable success conditions              │
│                                                                             │
│  📍 build:implement [medium] [deprecation]                                  │
│     Deprecated API usage detected (will be removed in v3.0)                 │
│     └─ Analysis: Update to new API before next major version                │
│     └─ Fix: Replace callOldAPI() with callNewAPI()                          │
│                                                                             │
│  📍 build:commit [low] [style]                                              │
│     Large commit size (847 lines added)                                     │
│     └─ Analysis: Consider breaking into smaller commits in future           │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  WARNINGS BY CATEGORY                                                       │
│  ────────────────────                                                       │
│  deprecation (1): build:implement                                           │
│  validation (1): architect:generate-spec                                    │
│  style (1): build:commit                                                    │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  RECOMMENDED ACTIONS                                                        │
│  ───────────────────                                                        │
│                                                                             │
│  [1] Apply fix for build:implement deprecation warning                      │
│      Command: sed -i 's/callOldAPI/callNewAPI/g' src/api.ts                 │
│                                                                             │
│  [2] Review spec acceptance criteria                                        │
│      File: /specs/WORK-00237-workflow-response-aggregation.md               │
│                                                                             │
│  [3] Skip remaining (1 low-priority warning)                                │
│                                                                             │
│  Enter choice (1-3) or 'done' to finish:                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Detailed Format

Same as summary, plus:
- All success messages from each step
- Full `details` objects
- Timing per step

#### Minimal Format

- Phase summary only
- Total warning/error counts
- No individual issue listing

### State File Changes

State files remain per-workflow-run as currently designed. Add reference to log entries:

```json
{
  "workflow_id": "...",
  "run_id": "...",
  "logs": {
    "step_responses": ["log-id-1", "log-id-2", "..."],
    "workflow_execution": "log-id-summary"
  },
  "response_totals": {
    "warnings": 3,
    "errors": 0,
    "by_severity": { "low": 1, "medium": 2, "high": 0 }
  }
}
```

This avoids duplicating full responses in state - they live in fractary-logs.

## Implementation Plan

### Phase 1: fractary-logs Integration

**Tasks**:
- [ ] Define `step-response` log type schema in fractary-logs plugin
- [ ] Define `workflow-execution` log type schema in fractary-logs plugin
- [ ] Implement log writing from faber-manager after each step/hook
- [ ] Test log persistence and retrieval

### Phase 2: Response Capture with Severity/Category

**Tasks**:
- [ ] Add severity and category fields to skill-response schema
- [ ] Update response capture logic in faber-manager
- [ ] Implement severity/category auto-detection heuristics
- [ ] Allow explicit severity/category in skill responses

### Phase 3: Autonomy Model Redesign

**Tasks**:
- [ ] Define new autonomy configuration schema
- [ ] Implement `check_in_frequency` logic in faber-manager
- [ ] Implement `warning_tolerance` evaluation
- [ ] Implement `error_tolerance` evaluation
- [ ] Add migration logic from old autonomy levels
- [ ] Deprecation warnings for old autonomy config

### Phase 4: Report Generation

**Tasks**:
- [ ] Implement summary report format
- [ ] Implement detailed report format (includes messages)
- [ ] Implement minimal report format
- [ ] Add "by category" cross-cutting view
- [ ] Implement interactive fix options
- [ ] Add specific command suggestions

### Phase 5: Global Limits

**Tasks**:
- [ ] Implement `max_total_warnings` limit
- [ ] Implement `max_total_errors` limit
- [ ] Add `on_limit_reached` behavior (stop/truncate)
- [ ] Test limit enforcement

### Phase 6: Testing and Documentation

**Tasks**:
- [ ] Add integration tests for response aggregation
- [ ] Add tests for autonomy model behavior
- [ ] Add tests for report generation
- [ ] Update RESULT-HANDLING.md
- [ ] Update RESPONSE-FORMAT.md
- [ ] Create AUTONOMY.md documentation
- [ ] Update workflow configuration examples

## Files to Create/Modify

### New Files

- `plugins/faber/docs/AUTONOMY.md`: New autonomy model documentation
- `plugins/faber/skills/faber-manager/workflow/capture-response.md`: Response capture workflow
- `plugins/faber/skills/faber-manager/workflow/generate-report.md`: Report generation workflow
- `plugins/logs/config/schemas/step-response.schema.json`: Log type schema
- `plugins/logs/config/schemas/workflow-execution.schema.json`: Log type schema

### Modified Files

- `plugins/faber/config/state.schema.json`: Add log references, response totals
- `plugins/faber/config/workflow.schema.json`: New autonomy config section
- `plugins/faber/config/schemas/skill-response.schema.json`: Add severity, category to warnings/errors
- `plugins/faber/agents/faber-manager.md`: Response capture, autonomy evaluation, report generation
- `plugins/faber/docs/RESULT-HANDLING.md`: Document tolerance behavior
- `plugins/faber/docs/RESPONSE-FORMAT.md`: Document severity/category
- `plugins/faber/docs/configuration.md`: Document new autonomy config

## Testing Strategy

### Unit Tests

- Severity/category assignment logic
- Tolerance evaluation (warning at severity X with tolerance Y = continue/stop)
- Check-in frequency triggers
- Report formatting

### Integration Tests

- Full workflow with warnings at multiple severity levels
- Workflow with check_in_frequency: per-step (verify stops after each)
- Workflow with high tolerance (verify continues through issues)
- Log persistence to fractary-logs
- Report generation from logs

### E2E Tests

- Complete FABER workflow with new autonomy config
- Migration from old autonomy level to new model
- Interactive report with fix application

## Dependencies

- `fractary-logs` plugin (for step-response and workflow-execution log types)
- Existing FABER state management
- Existing skill response format

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Breaking change for existing workflows | Low | High | Old autonomy levels map to new model; deprecation period |
| Log storage grows unbounded | Medium | Medium | Use fractary-logs retention policies; log archival |
| Severity auto-detection inaccurate | Medium | Low | Allow explicit severity in skill responses; tunable heuristics |
| Report too verbose for large workflows | Low | Medium | Minimal format option; pagination for large reports |

## Documentation Updates

- `plugins/faber/docs/AUTONOMY.md`: New file documenting two-dimensional model
- `plugins/faber/docs/RESULT-HANDLING.md`: Add tolerance behavior
- `plugins/faber/docs/RESPONSE-FORMAT.md`: Add severity/category fields
- `plugins/faber/docs/configuration.md`: New autonomy config section
- `CLAUDE.md`: Update FABER section with new capabilities

## Success Metrics

| Metric | Target |
|--------|--------|
| Response capture overhead | < 50ms per step |
| Report generation time | < 500ms for 100 items |
| Backward compatibility | 100% (existing workflows unchanged) |
| Log storage per workflow | < 100KB average |

## Implementation Notes

### Severity Auto-Detection Heuristics

When a skill doesn't specify severity, use heuristics:

- **high**: Keywords like "critical", "security", "breaking", "fail"
- **medium**: Keywords like "deprecated", "warning", "should", "consider"
- **low**: Keywords like "style", "minor", "optional", "info"

Skills should prefer explicit severity for accuracy.

### Category Auto-Detection

- **deprecation**: "deprecated", "removed in", "obsolete"
- **performance**: "slow", "performance", "memory", "cpu"
- **security**: "security", "vulnerability", "auth", "permission"
- **style**: "style", "format", "lint", "convention"
- **validation**: "invalid", "validation", "schema", "required"

### Check-in Behavior

At each check-in point (per-step, per-phase, or end-only):

1. Display accumulated responses since last check-in
2. Show recommended actions
3. Offer interactive options
4. Wait for user input OR continue if all issues within tolerance

### Retry Logging

When a step is retried (by the skill/plugin itself, not by workflow manager):
- Each attempt gets its own `step-response` log entry
- Entries share same `step_id` but have different `attempt` numbers
- Final report shows all attempts for transparency

### Migration Period

1. Old autonomy config continues to work (mapped internally)
2. Warning logged when old config detected
3. Documentation updated with migration guide
4. Old config support removed after 2 major versions
