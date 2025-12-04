---
model: claude-haiku-4-5
---

# /fractary-faber:status

Display FABER workflow status with dual-state tracking (current state + historical logs).

## What This Does

Shows comprehensive workflow status by combining:
- **Current State**: From `.fractary/plugins/faber/state.json`
- **Historical Logs**: From `fractary-logs` plugin (workflow log type)

**Features**:
- 📊 Current phase and progress
- 📝 Recent workflow events from logs
- 📦 Artifacts created (specs, branches, PRs)
- ⏭️ Next steps based on current state
- 🔄 Retry count and error tracking
- ⏱️ Phase timing information

## Your Mission

1. **Load current state** from `.fractary/plugins/faber/state.json`
2. **Query recent logs** from fractary-logs plugin
3. **Combine information** to show complete picture
4. **Display phase status** with visual indicators
5. **Provide next steps** based on current state

## Usage

```bash
# Show current workflow status
/fractary-faber:status

# Show status with work item ID
/fractary-faber:status 158

# Show detailed log history (last N events)
/fractary-faber:status --logs 20

# Show only current state (no logs)
/fractary-faber:status --state-only

# Show timing breakdown
/fractary-faber:status --timing

# Show all information (state + full logs + timing)
/fractary-faber:status --verbose
```

## Implementation

This command should:

### Step 1: Load Current State

```bash
# Check if state file exists
STATE_FILE=".fractary/plugins/faber/state.json"

if [ ! -f "$STATE_FILE" ]; then
    echo "No active FABER workflow found in this project." >&2
    echo "" >&2
    echo "To start a workflow:" >&2
    echo "  /fractary-faber:run <work-id>" >&2
    exit 1
fi

# Load current state
STATE_JSON=$(cat "$STATE_FILE")

# Extract key fields
WORK_ID=$(echo "$STATE_JSON" | jq -r '.work_id')
STATUS=$(echo "$STATE_JSON" | jq -r '.status')
CURRENT_PHASE=$(echo "$STATE_JSON" | jq -r '.current_phase')
STARTED_AT=$(echo "$STATE_JSON" | jq -r '.started_at')
UPDATED_AT=$(echo "$STATE_JSON" | jq -r '.updated_at')
```

### Step 2: Query Recent Logs

Use the `fractary-logs` plugin to query workflow events:

```bash
# Query recent workflow log entries (if logs enabled)
LOG_LIMIT="${LOG_LIMIT:-10}"

# Use fractary-logs to query workflow events
# This should invoke the fractary-logs plugin with appropriate filters
RECENT_LOGS=$(fractary-logs query --type workflow --work-id "$WORK_ID" --limit "$LOG_LIMIT" 2>/dev/null || echo "[]")
```

### Step 3: Display Status

Combine current state with recent logs to show comprehensive status.

## Status Output Format

The command displays three sections:

### 1. Current State Section

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 FABER Workflow Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Work ID: 158
Status: in_progress
Current Phase: architect

Started: 2025-11-19 10:30:15
Updated: 2025-11-19 10:45:23

Workflow Phases:
  Frame        ✅ Complete (2m 15s)
  Architect    🔄 In Progress
  Build        ⏸️  Pending
  Evaluate     ⏸️  Pending
  Release      ⏸️  Pending

Artifacts:
  Specification: specs/WORK-00158-description.md
  Branch: feat/158-review-faber-workflow-config
  Commit: abc1234 (2 commits)
```

### 2. Recent Log Events Section

```
Recent Events (last 10):
  [10:45:23] phase_start - Architect phase started
  [10:43:10] step_complete - setup-env completed
  [10:42:55] step_complete - classify completed
  [10:41:30] step_complete - fetch-work completed
  [10:41:15] phase_complete - Frame phase completed
  [10:41:00] phase_start - Frame phase started
  [10:40:45] hook_execute - pre_frame hook: load-context
  [10:40:30] workflow_start - FABER workflow started for #158
```

### 3. Next Steps Section

```
Next Steps:
  🔄 Architect phase in progress
  → Generating technical specification from requirements
  → Estimated time remaining: ~3 minutes

  When architect completes:
    /fractary-faber:run --work-id 158 --phase build   # Continue to build phase
    /fractary-faber:run --work-id 158                 # Continue full workflow
```

## State Information Tracked

From `.fractary/plugins/faber/state.json`:
- **work_id**: Work item identifier
- **status**: Overall workflow status (pending, in_progress, completed, failed)
- **current_phase**: Currently executing phase
- **started_at**: Workflow start timestamp
- **updated_at**: Last update timestamp
- **phases**: Status and timing for each of 5 phases
  - **status**: Phase status (pending, in_progress, completed, failed)
  - **started_at**: Phase start timestamp
  - **completed_at**: Phase completion timestamp
  - **steps_completed**: Array of completed step names
  - **retries**: Retry count (for evaluate phase)
- **artifacts**: Created artifacts
  - **specification**: Path to spec file
  - **branch**: Branch name
  - **commits**: Array of commit SHAs
  - **pr_url**: Pull request URL (if created)
- **errors**: Error tracking per phase

From `fractary-logs` plugin (workflow log type):
- **workflow_start**: Workflow initiated
- **workflow_complete**: Workflow finished successfully
- **workflow_fail**: Workflow failed
- **phase_start**: Phase execution started
- **phase_complete**: Phase completed successfully
- **phase_fail**: Phase failed
- **step_start**: Sub-step execution started
- **step_complete**: Sub-step completed
- **step_fail**: Sub-step failed
- **hook_execute**: Hook executed (pre/post phase)
- **retry_attempt**: Retry attempt (evaluate phase)
- **approval_requested**: Waiting for user approval
- **approval_granted**: User approved continuation
- **artifact_created**: Artifact generated
- **state_change**: Status change recorded

## Error Handling

Handle these cases:

1. **No state file**: "No active FABER workflow found"
2. **Invalid JSON**: "State file is corrupted"
3. **Logs plugin unavailable**: Show state only with warning
4. **Work ID mismatch**: Warn if provided work_id doesn't match state

## Command Flags

- `--logs N`: Show last N log events (default: 10)
- `--state-only`: Skip logs, show only current state
- `--timing`: Include phase timing breakdown
- `--verbose`: Show everything (state + logs + timing)

## Use Cases

**When to use status:**
- Check current workflow progress
- Review phase completion status
- See recent workflow events
- Debug workflow issues
- Verify artifacts created
- Understand next steps

## Integration Points

This command reads:
- **State**: `.fractary/plugins/faber/state.json` (current state)
- **Logs**: `fractary-logs` plugin with workflow log type (historical events)
- **Config**: `.fractary/plugins/faber/config.json` (to understand configuration)

## What This Command Does NOT Do

- Does NOT modify state (read-only)
- Does NOT execute workflows (use `/fractary-faber:run`)
- Does NOT approve releases (handled by faber-manager)
- Does NOT retry workflows (handled by faber-manager)

## Best Practices

1. **Dual-state visibility** - Always show both current state and recent logs
2. **Clear visual indicators** - Use emoji/icons (✅ ❌ 🔄 ⏸️)
3. **Actionable next steps** - Based on current phase and status
4. **Timing information** - Show how long each phase took
5. **Error visibility** - Surface errors prominently

## See Also

- `/fractary-faber:run` - Execute workflow
- `/fractary-faber:audit` - Validate configuration
- Config file: `.fractary/plugins/faber/config.json`
- State file: `.fractary/plugins/faber/state.json`
- Logs: Query via `fractary-logs` plugin
