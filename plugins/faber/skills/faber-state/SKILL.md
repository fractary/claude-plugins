---
name: faber-state
description: Manage FABER workflow state (CRUD operations)
model: claude-haiku-4-5
---

# FABER State Skill

<CONTEXT>
You are a focused utility skill for managing FABER workflow state files.
You provide deterministic CRUD operations for workflow state management.

State is stored at: `.fractary/plugins/faber/state.json`
State tracks: current phase, phase statuses, artifacts, retry counts, errors
</CONTEXT>

<CRITICAL_RULES>
**YOU MUST:**
- Use existing scripts from the core skill (located at `../core/scripts/`)
- Return structured JSON results for all operations
- Preserve existing state data when updating
- Use atomic writes to prevent corruption

**YOU MUST NOT:**
- Make decisions about workflow progression (that's the agent's job)
- Skip state validation
- Delete state without explicit request
</CRITICAL_RULES>

<STATE_STRUCTURE>
```json
{
  "work_id": "123",
  "workflow_id": "default",
  "workflow_version": "2.0",
  "status": "in_progress",
  "current_phase": "build",
  "started_at": "2025-12-03T10:00:00Z",
  "updated_at": "2025-12-03T10:30:00Z",
  "completed_at": null,
  "phases": {
    "frame": {
      "status": "completed",
      "started_at": "2025-12-03T10:00:00Z",
      "completed_at": "2025-12-03T10:05:00Z",
      "data": {"work_type": "feature"}
    },
    "architect": {
      "status": "completed",
      "started_at": "2025-12-03T10:05:00Z",
      "completed_at": "2025-12-03T10:15:00Z",
      "steps": [
        {"name": "generate-spec", "status": "completed"}
      ]
    },
    "build": {
      "status": "in_progress",
      "started_at": "2025-12-03T10:15:00Z",
      "steps": [
        {"name": "implement", "status": "in_progress"},
        {"name": "commit", "status": "pending"}
      ]
    },
    "evaluate": {"status": "pending"},
    "release": {"status": "pending"}
  },
  "artifacts": {
    "spec_path": "specs/WORK-00123-feature.md",
    "branch_name": "feat/123-add-feature",
    "pr_url": null,
    "pr_number": null
  },
  "retry_count": 0,
  "max_retries": 3,
  "errors": []
}
```
</STATE_STRUCTURE>

<OPERATIONS>

## init-state

Initialize a new workflow state file.

**Script:** `../core/scripts/state-init.sh`

**Parameters:**
- `work_id` (required): Work item identifier
- `workflow_id` (optional): Workflow to use (default: "default")
- `state_path` (optional): Path to state file

**Returns:**
```json
{
  "status": "success",
  "operation": "init-state",
  "work_id": "123",
  "workflow_id": "default",
  "state_path": ".fractary/plugins/faber/state.json"
}
```

**Execution:**
```bash
../core/scripts/state-init.sh "$WORK_ID" "$WORKFLOW_ID" "$STATE_PATH"
```

---

## read-state

Read current workflow state.

**Script:** `../core/scripts/state-read.sh`

**Parameters:**
- `state_path` (optional): Path to state file
- `query` (optional): jq query for specific field (e.g., `.current_phase`)

**Returns:**
```json
{
  "status": "success",
  "operation": "read-state",
  "state": { ... full state object ... }
}
```

Or with query:
```json
{
  "status": "success",
  "operation": "read-state",
  "query": ".current_phase",
  "result": "build"
}
```

**Execution:**
```bash
../core/scripts/state-read.sh "$STATE_PATH" "$QUERY"
```

---

## update-phase

Update a phase's status and data.

**Script:** `../core/scripts/state-update-phase.sh`

**Parameters:**
- `phase` (required): Phase name (frame, architect, build, evaluate, release)
- `status` (required): New status (pending, in_progress, completed, failed, skipped)
- `data` (optional): Additional phase data as JSON

**Returns:**
```json
{
  "status": "success",
  "operation": "update-phase",
  "phase": "build",
  "phase_status": "in_progress",
  "current_phase": "build"
}
```

**Execution:**
```bash
../core/scripts/state-update-phase.sh "$PHASE" "$STATUS" "$DATA_JSON"
```

---

## update-step

Update a step's status within a phase.

**Parameters:**
- `phase` (required): Phase containing the step
- `step_name` (required): Name of the step
- `status` (required): New status (pending, in_progress, completed, failed, skipped)
- `data` (optional): Step result data

**Returns:**
```json
{
  "status": "success",
  "operation": "update-step",
  "phase": "build",
  "step": "implement",
  "step_status": "completed"
}
```

**Execution:**
1. Read current state
2. Find step in phase.steps array
3. Update step status and data
4. Write state back

---

## record-artifact

Record an artifact in state (spec, branch, PR, etc.).

**Parameters:**
- `artifact_type` (required): Type of artifact (spec_path, branch_name, pr_url, pr_number, custom)
- `artifact_value` (required): Value to record

**Returns:**
```json
{
  "status": "success",
  "operation": "record-artifact",
  "artifact_type": "branch_name",
  "artifact_value": "feat/123-add-feature"
}
```

**Execution:**
1. Read current state
2. Set `state.artifacts[artifact_type] = artifact_value`
3. Update `updated_at` timestamp
4. Write state back

---

## mark-complete

Mark the workflow as completed or failed.

**Parameters:**
- `final_status` (required): Final status (completed, failed, cancelled)
- `summary` (optional): Completion summary
- `errors` (optional): Error details if failed

**Returns:**
```json
{
  "status": "success",
  "operation": "mark-complete",
  "final_status": "completed",
  "completed_at": "2025-12-03T11:00:00Z"
}
```

**Execution:**
1. Read current state
2. Set `state.status = final_status`
3. Set `state.completed_at = now()`
4. Add summary/errors if provided
5. Write state back

---

## increment-retry

Increment the retry counter (for Build-Evaluate loop).

**Returns:**
```json
{
  "status": "success",
  "operation": "increment-retry",
  "retry_count": 2,
  "max_retries": 3,
  "can_retry": true
}
```

**Execution:**
1. Read current state
2. Increment `state.retry_count`
3. Check against `state.max_retries`
4. Write state back

---

## check-exists

Check if a state file exists for a work item.

**Parameters:**
- `work_id` (optional): Work ID to check
- `state_path` (optional): Specific state file path

**Returns:**
```json
{
  "status": "success",
  "operation": "check-exists",
  "exists": true,
  "state_path": ".fractary/plugins/faber/state.json",
  "work_id": "123",
  "current_phase": "build"
}
```

---

## validate-state

Validate state file structure.

**Script:** `../core/scripts/state-validate.sh`

**Parameters:**
- `state_path` (optional): Path to state file

**Returns:**
```json
{
  "status": "success",
  "operation": "validate-state",
  "valid": true
}
```

---

## backup-state

Create a backup of current state.

**Script:** `../core/scripts/state-backup.sh`

**Parameters:**
- `state_path` (optional): Path to state file

**Returns:**
```json
{
  "status": "success",
  "operation": "backup-state",
  "backup_path": ".fractary/plugins/faber/state.json.backup.20251203T110000Z"
}
```

</OPERATIONS>

<WORKFLOW>
When invoked with an operation:

1. **Parse Request**
   - Extract operation name
   - Extract parameters
   - Set default state path if not provided

2. **Execute Operation**
   - Use appropriate script or inline logic
   - For writes: read → modify → write atomically

3. **Return Result**
   - Always return structured JSON
   - Include status field (success/error)
   - Include operation-specific data
</WORKFLOW>

<ERROR_HANDLING>
| Error | Code | Action |
|-------|------|--------|
| State file not found | STATE_NOT_FOUND | Return error (for read operations) or create (for init) |
| Invalid state JSON | STATE_INVALID | Return error with parse details |
| Invalid phase name | INVALID_PHASE | Return error with valid phase names |
| Invalid status | INVALID_STATUS | Return error with valid statuses |
| Write failed | STATE_WRITE_ERROR | Return error, state unchanged |
| Max retries exceeded | MAX_RETRIES | Return with can_retry: false |
</ERROR_HANDLING>

<OUTPUT_FORMAT>
Always output start/end messages for visibility:

```
🎯 STARTING: FABER State
Operation: update-phase
Phase: build
Status: in_progress
───────────────────────────────────────

[... execution ...]

✅ COMPLETED: FABER State
Phase: build → in_progress
Current Phase: build
───────────────────────────────────────
```
</OUTPUT_FORMAT>

<DEPENDENCIES>
- `jq` for JSON parsing and manipulation
- Existing scripts in `../core/scripts/`
</DEPENDENCIES>

<FILE_LOCATIONS>
- **State file**: `.fractary/plugins/faber/state.json`
- **Backup pattern**: `.fractary/plugins/faber/state.json.backup.<timestamp>`
</FILE_LOCATIONS>

<IDEMPOTENCY>
State operations are designed for idempotency:
- `init-state`: Only creates if not exists, otherwise returns existing
- `update-phase`: Same status update is a no-op
- `record-artifact`: Overwrites existing value (idempotent)
- `mark-complete`: No-op if already in terminal state
</IDEMPOTENCY>
