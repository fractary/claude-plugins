# Gather Debug Context

This workflow step collects all necessary context for debugging workflow issues.

## Overview

Before diagnosing issues, we need to gather:
1. Current workflow state (run status, phase, steps)
2. Event history for the run
3. Errors and warnings from step executions
4. Relevant artifacts (specs, code changes)
5. Explicit problem description (if provided in targeted mode)

## Steps

### 1. Read Workflow State

Use the faber-state skill to get current run state:

```bash
# Get state for the run
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FABER_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CORE_SCRIPTS="$FABER_ROOT/skills/core/scripts"

"$CORE_SCRIPTS/state-read.sh" "$RUN_ID"
```

**Expected Output:**
```json
{
  "run_id": "fractary/claude-plugins/abc123",
  "work_id": "244",
  "workflow_id": "default",
  "status": "failed",
  "current_phase": "build",
  "phases": {
    "frame": { "status": "completed", "steps": [...] },
    "architect": { "status": "completed", "steps": [...] },
    "build": {
      "status": "failed",
      "steps": [
        { "id": "implement", "status": "failed", "error": "..." }
      ]
    }
  },
  "artifacts": {
    "branch_name": "feat/244-...",
    "spec_path": "specs/WORK-00244-..."
  }
}
```

**If State Not Found:**
- If explicit `problem` provided: Continue with problem description only
- If no `problem`: Return failure - cannot do automatic detection without state

---

### 2. Aggregate Errors and Warnings

Parse step responses to extract all errors and warnings:

```bash
scripts/aggregate-errors.sh "$RUN_ID"
```

**Process:**
1. Read state file for all phases and steps
2. Extract `errors` and `warnings` arrays from each step response
3. Extract `error_analysis` fields for context
4. Deduplicate similar messages
5. Group by phase/step for attribution

**Expected Output:**
```json
{
  "errors": [
    {
      "phase": "build",
      "step": "implement",
      "message": "Type error: Expected string, got int",
      "location": "src/auth.ts:45",
      "timestamp": "2025-12-05T15:30:00Z"
    },
    {
      "phase": "build",
      "step": "implement",
      "message": "Import error: Module 'xyz' not found",
      "location": "src/utils.ts:12",
      "timestamp": "2025-12-05T15:30:00Z"
    }
  ],
  "warnings": [
    {
      "phase": "architect",
      "step": "generate-spec",
      "message": "Specification may be incomplete - missing acceptance criteria",
      "timestamp": "2025-12-05T14:45:00Z"
    }
  ],
  "error_analyses": [
    {
      "phase": "build",
      "step": "implement",
      "analysis": "Implementation failed due to type mismatches and missing dependencies"
    }
  ],
  "summary": {
    "total_errors": 2,
    "total_warnings": 1,
    "affected_phases": ["build"],
    "affected_steps": ["implement"]
  }
}
```

---

### 3. Read Event History

Get timeline of workflow events:

```bash
# Read events from run directory
RUN_DIR=".fractary/plugins/faber/runs/$RUN_ID"
cat "$RUN_DIR/events.jsonl" | tail -50
```

**Expected Output:**
```json
[
  {
    "event_id": 1,
    "type": "workflow_start",
    "timestamp": "2025-12-05T14:30:00Z",
    "data": { "workflow": "default" }
  },
  {
    "event_id": 2,
    "type": "phase_start",
    "phase": "frame",
    "timestamp": "2025-12-05T14:30:01Z"
  },
  ...
  {
    "event_id": 15,
    "type": "step_error",
    "phase": "build",
    "step": "implement",
    "timestamp": "2025-12-05T15:30:00Z",
    "data": {
      "error": "Type error in src/auth.ts:45"
    }
  }
]
```

---

### 4. Fetch Related Artifacts

Collect relevant context artifacts:

**Specification:**
```bash
# If spec_path in artifacts
if [ -n "$SPEC_PATH" ]; then
  cat "$SPEC_PATH"
fi
```

**Code Changes (if build failed):**
```bash
# Get recent changes
git diff main...HEAD --stat
git log main..HEAD --oneline
```

**Test Output (if evaluate failed):**
```bash
# Check for test logs
cat .fractary/plugins/faber/runs/$RUN_ID/test-output.log 2>/dev/null
```

---

### 5. Process Explicit Problem (Targeted Mode)

If `problem` parameter was provided:

```json
{
  "mode": "targeted",
  "explicit_problem": {
    "description": "Test suite failing with timeout errors on authentication tests",
    "provided_by": "user",
    "timestamp": "2025-12-05T16:00:00Z"
  }
}
```

**Use explicit problem to:**
- Focus analysis on related errors
- Weight matching knowledge base entries higher
- Include in root cause hypothesis

---

### 6. Aggregate Debug Context

Combine all gathered context:

```json
{
  "run_id": "fractary/claude-plugins/abc123",
  "work_id": "244",
  "gathered_at": "2025-12-05T16:00:00Z",
  "mode": "automatic",

  "state": {
    "status": "failed",
    "current_phase": "build",
    "failed_step": "implement"
  },

  "errors": [...],
  "warnings": [...],
  "error_analyses": [...],

  "events": [...],

  "artifacts": {
    "spec": { "path": "...", "content": "..." },
    "branch": "feat/244-...",
    "recent_changes": [...]
  },

  "explicit_problem": null,

  "context_quality": {
    "complete": true,
    "missing": [],
    "warnings": []
  }
}
```

## Error Handling

**State Not Found:**
```
IF mode == "targeted" AND problem provided:
  Continue with problem description only
  Set context_quality.missing = ["state"]
ELSE:
  Return failure: "Cannot diagnose without state or problem description"
```

**Events Not Found:**
```
Log warning: "Event history not available, using state only"
Set context_quality.missing = ["events"]
Continue with available data
```

**Large Error Lists:**
```
IF errors.length > 100:
  Group similar errors
  Keep first 3 of each group
  Log: "Summarized {N} errors into {M} groups"
```

## Output

Save aggregated context for subsequent steps:

```bash
echo "$DEBUG_CONTEXT_JSON" > /tmp/faber-debugger-context.json
```

Return context quality assessment:
- `complete: true` if all required data available
- `complete: false` with `missing` list if degraded
