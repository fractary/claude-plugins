# FABER State Tracking Guide

Complete guide to dual-state tracking in FABER workflow (state.json + fractary-logs).

## Overview

FABER v2.0 uses a **dual-state tracking approach** combining:
1. **Current State** - `.fractary/plugins/faber/state.json` (current workflow state)
2. **Historical Logs** - `fractary-logs` plugin with workflow log type (complete audit trail)

This provides both **operational efficiency** (fast state queries) and **complete auditability** (full historical record).

## Architecture

```
┌─────────────────────────────────────────────────┐
│                FABER Workflow                    │
│  (faber-manager orchestrates all 5 phases)       │
└─────────────┬───────────────────┬───────────────┘
              │                   │
              ▼                   ▼
   ┌──────────────────┐  ┌──────────────────────┐
   │   state.json     │  │  fractary-logs       │
   │  (current state) │  │  (historical events) │
   └──────────────────┘  └──────────────────────┘
              │                   │
              └───────┬───────────┘
                      ▼
              ┌──────────────────┐
              │  /faber:status   │
              │ (combines both)  │
              └──────────────────┘
```

## Current State (state.json)

### Location
```
.fractary/plugins/faber/state.json
```

### Purpose
- Track **current** workflow state
- Enable **resume** capability
- Support **retry** logic
- Fast queries for status display

### Schema

```json
{
  "work_id": "158",
  "status": "in_progress",
  "current_phase": "architect",
  "started_at": "2025-11-19T10:30:15Z",
  "updated_at": "2025-11-19T10:45:23Z",
  "phases": {
    "frame": {
      "status": "completed",
      "started_at": "2025-11-19T10:30:20Z",
      "completed_at": "2025-11-19T10:32:35Z",
      "steps_completed": ["fetch-work", "classify", "setup-env"]
    },
    "architect": {
      "status": "in_progress",
      "started_at": "2025-11-19T10:45:20Z",
      "steps_completed": []
    },
    "build": {
      "status": "pending"
    },
    "evaluate": {
      "status": "pending",
      "retries": 0
    },
    "release": {
      "status": "pending"
    }
  },
  "artifacts": {
    "specification": "specs/WORK-00158-description.md",
    "branch": "feat/158-review-faber-workflow-config",
    "commits": []
  },
  "errors": {}
}
```

### State Management

**Creation**: Created by faber-manager when workflow starts

```bash
# Initialize state file
{
  "work_id": "158",
  "status": "pending",
  "current_phase": null,
  "started_at": "2025-11-19T10:30:15Z",
  "updated_at": "2025-11-19T10:30:15Z",
  "phases": { ... all pending ... },
  "artifacts": {},
  "errors": {}
}
```

**Updates**: Updated by faber-manager as workflow progresses

```bash
# When phase starts
phases.architect.status = "in_progress"
phases.architect.started_at = "2025-11-19T10:45:20Z"
current_phase = "architect"
updated_at = "2025-11-19T10:45:20Z"

# When phase completes
phases.architect.status = "completed"
phases.architect.completed_at = "2025-11-19T10:48:30Z"
updated_at = "2025-11-19T10:48:30Z"

# When artifact created
artifacts.specification = "specs/WORK-00158-description.md"
```

**Deletion**: Retained after workflow completes (for historical reference)

## Historical Logs (fractary-logs)

### Integration
FABER integrates with the `fractary-logs` plugin using the `workflow` log type.

### Purpose
- Provide **complete audit trail**
- Enable **debugging** and troubleshooting
- Support **analytics** and reporting
- Track **timing** and performance

### Workflow Log Type

Defined in `plugins/logs/types/workflow.json`, supports 15 event types:

1. **workflow_start** - Workflow initiated
2. **workflow_complete** - Workflow finished successfully
3. **workflow_fail** - Workflow failed
4. **phase_start** - Phase execution started
5. **phase_complete** - Phase completed successfully
6. **phase_fail** - Phase failed
7. **step_start** - Sub-step execution started
8. **step_complete** - Sub-step completed
9. **step_fail** - Sub-step failed
10. **hook_execute** - Hook executed (pre/post phase)
11. **retry_attempt** - Retry attempt (evaluate phase)
12. **approval_requested** - Waiting for user approval
13. **approval_granted** - User approved continuation
14. **artifact_created** - Artifact generated
15. **state_change** - Status change recorded

### Log Entry Example

```json
{
  "timestamp": "2025-11-19T10:45:20Z",
  "event_type": "phase_start",
  "work_id": "158",
  "phase": "architect",
  "message": "Architect phase started",
  "metadata": {
    "previous_phase": "frame",
    "steps_to_execute": ["generate-spec"]
  }
}
```

### Logging Events

**Phase Lifecycle**:
```javascript
// Phase start
{
  "event_type": "phase_start",
  "phase": "architect",
  "message": "Architect phase started"
}

// Phase complete
{
  "event_type": "phase_complete",
  "phase": "architect",
  "message": "Architect phase completed successfully",
  "duration_seconds": 185
}
```

**Step Execution**:
```javascript
// Step start
{
  "event_type": "step_start",
  "phase": "frame",
  "step": "fetch-work",
  "message": "Starting fetch-work step"
}

// Step complete
{
  "event_type": "step_complete",
  "phase": "frame",
  "step": "fetch-work",
  "message": "fetch-work step completed",
  "duration_seconds": 12
}
```

**Hook Execution**:
```javascript
{
  "event_type": "hook_execute",
  "phase": "architect",
  "position": "pre",
  "hook_name": "load-standards",
  "hook_type": "document",
  "message": "Executing pre_architect hook: load-standards"
}
```

## Dual-State Query Pattern

The `/fractary-faber:status` command demonstrates the dual-state query pattern:

```bash
#!/bin/bash

# 1. Load current state
STATE_JSON=$(cat .fractary/plugins/faber/state.json)
WORK_ID=$(echo "$STATE_JSON" | jq -r '.work_id')
STATUS=$(echo "$STATE_JSON" | jq -r '.status')
CURRENT_PHASE=$(echo "$STATE_JSON" | jq -r '.current_phase')

# 2. Query recent logs
RECENT_LOGS=$(fractary-logs query \
  --type workflow \
  --work-id "$WORK_ID" \
  --limit 10)

# 3. Combine for display
echo "Current Phase: $CURRENT_PHASE (from state.json)"
echo "Recent Events: (from fractary-logs)"
echo "$RECENT_LOGS" | jq -r '.[] | "  [\(.timestamp)] \(.event_type) - \(.message)"'
```

## Configuration

Enable logging in `.fractary/plugins/faber/config.json`:

```json
{
  "logging": {
    "use_logs_plugin": true,
    "log_type": "workflow",
    "log_level": "info",
    "log_phases": true,
    "log_sub_steps": true,
    "log_hooks": true
  }
}
```

**Fields**:
- **use_logs_plugin**: Enable/disable fractary-logs integration
- **log_type**: Must be `"workflow"`
- **log_level**: `debug`, `info`, `warn`, or `error`
- **log_phases**: Log phase start/complete events
- **log_sub_steps**: Log sub-step execution
- **log_hooks**: Log hook execution

## Benefits of Dual-State Tracking

### 1. Performance
- **Fast queries**: state.json is a single file, no log scanning
- **Instant status**: No need to parse log history for current state

### 2. Auditability
- **Complete history**: All events preserved in fractary-logs
- **Debugging**: Full execution trace for troubleshooting
- **Analytics**: Historical data for workflow optimization

### 3. Reliability
- **Resume capability**: state.json enables workflow resume after interruption
- **Retry logic**: Retry count tracked in state for evaluate phase
- **Error tracking**: Errors recorded in both state and logs

### 4. Separation of Concerns
- **Operational**: state.json optimized for workflow execution
- **Analytical**: fractary-logs optimized for historical analysis

## File Locations

```
project-root/
├── .fractary/
│   └── plugins/
│       ├── faber/
│       │   ├── config.json        # Configuration
│       │   └── state.json         # Current state
│       └── logs/
│           └── workflow/          # Historical logs (managed by fractary-logs)
│               ├── 2025-11-19.log
│               └── ...
```

## See Also

- [CONFIGURATION.md](./CONFIGURATION.md) - Complete configuration guide
- [HOOKS.md](./HOOKS.md) - Phase-level hooks guide
- `/fractary-faber:status` - Status command using dual-state pattern
- `plugins/logs/types/workflow.json` - Workflow log type definition
