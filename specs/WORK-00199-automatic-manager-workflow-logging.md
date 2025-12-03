# WORK-00199: Automatic Manager Workflow Logging

## Metadata

| Field | Value |
|-------|-------|
| **Spec ID** | WORK-00199 |
| **Title** | Automatic Manager Workflow Logging |
| **Type** | Feature |
| **Status** | Draft |
| **Created** | 2025-12-02 |
| **Issue** | [#199](https://github.com/fractary/claude-plugins/issues/199) |
| **Related** | [SPEC-00047](./SPEC-00047-framework-workflow-event-logging.md) - Framework-Level Workflow Event Logging |

---

## Problem Statement

Multiple projects in the Fractary ecosystem use the **manager-as-orchestrator pattern** to orchestrate workflow steps. Each project has historically implemented its own changelog/event logging mechanism, leading to:

1. **Inconsistent formats** across projects
2. **Duplicate effort** implementing logging in each project
3. **Missed events** when developers forget to log
4. **No cross-project visibility** - downstream systems can't easily consume upstream workflow events

The faber-manager skill already has structured phase/step execution with state management, but it doesn't emit standardized workflow events that can be consumed by downstream systems.

---

## Solution Overview

Enhance the faber-manager skill to **automatically emit workflow events** at key points during execution, using the existing fractary-logs `workflow` log type. Events are written locally and optionally pushed to S3 for cross-project consumption.

### Key Insight

The faber-manager skill already has the perfect structure for event emission:
- Step 3 (Initialize Logging) sets up fractary-logs integration
- Phase execution loop has clear start/end points
- State is tracked with timestamps and artifacts
- Hook execution is already logged

**The enhancement**: Make logging structured, standardized, and S3-pushable.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                    faber-manager Skill                           │
├──────────────────────────────────────────────────────────────────┤
│  Workflow Start                                                  │
│     └─→ emit_workflow_event("workflow_start", {...})            │
│                                                                  │
│  For Each Phase:                                                 │
│     ├─→ emit_workflow_event("phase_start", {...})               │
│     │                                                            │
│     │   For Each Step:                                           │
│     │      ├─→ emit_workflow_event("step_start", {...})         │
│     │      └─→ emit_workflow_event("step_complete", {...})      │
│     │                                                            │
│     │   On Artifact Created:                                     │
│     │      └─→ emit_workflow_event("artifact_create", {...})    │
│     │                                                            │
│     └─→ emit_workflow_event("phase_complete", {...})            │
│                                                                  │
│  Workflow Complete                                               │
│     └─→ emit_workflow_event("workflow_complete", {...})         │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                    fractary-logs Plugin                          │
├──────────────────────────────────────────────────────────────────┤
│  log-writer skill                                                │
│  ├── Writes to local: .fractary/logs/workflow/                  │
│  └── Pushes to S3: s3://{bucket}/workflow/{year}/{month}/       │
│                                                                  │
│  Uses existing `workflow` log type standards                     │
└──────────────────────────────────────────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: Create Event Emission Helper Skill

**Location**: `plugins/logs/skills/workflow-event-emitter/`

Create a new focused skill that provides a simple interface for emitting workflow events.

#### 1.1 Skill Structure

```
plugins/logs/skills/workflow-event-emitter/
├── SKILL.md                    # Skill definition
└── scripts/
    └── emit-event.sh           # Event emission script
```

#### 1.2 Skill Interface

The skill accepts:
- `event_type`: One of `workflow_start`, `phase_start`, `step_start`, `step_complete`, `phase_complete`, `artifact_create`, `workflow_complete`
- `workflow_id`: Unique workflow identifier
- `payload`: JSON object with event-specific data

#### 1.3 Script Implementation (`emit-event.sh`)

```bash
#!/usr/bin/env bash
# emit-event.sh - Emit a workflow event to fractary-logs

set -euo pipefail

EVENT_TYPE="${1:-}"
WORKFLOW_ID="${2:-}"
PAYLOAD="${3:-{}}"

# Validate inputs
[[ -z "$EVENT_TYPE" ]] && { echo "Error: event_type required"; exit 1; }
[[ -z "$WORKFLOW_ID" ]] && { echo "Error: workflow_id required"; exit 1; }

# Build event JSON
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PROJECT=$(basename "$PWD")
ENVIRONMENT="${FRACTARY_ENV:-development}"

EVENT=$(jq -n \
  --arg event_type "$EVENT_TYPE" \
  --arg workflow_id "$WORKFLOW_ID" \
  --arg timestamp "$TIMESTAMP" \
  --arg project "$PROJECT" \
  --arg environment "$ENVIRONMENT" \
  --argjson payload "$PAYLOAD" \
  '{
    event_type: $event_type,
    workflow_id: $workflow_id,
    timestamp: $timestamp,
    project: $project,
    environment: $environment,
    payload: $payload
  }')

# Write to workflow log via logs plugin
# The log-writer skill handles local storage + S3 push based on config
echo "$EVENT"
```

### Phase 2: Enhance faber-manager Skill with Event Emission

**Location**: `plugins/faber/skills/faber-manager/SKILL.md`

Add event emission at each orchestration point.

#### 2.1 Add Event Emission Section to SKILL.md

Add a new `<EVENT_EMISSION>` section after `<CRITICAL_RULES>`:

```markdown
<EVENT_EMISSION>
## Automatic Workflow Event Emission

At each orchestration point, emit structured events for downstream consumption.

### Event Points

| Point | Event Type | Trigger |
|-------|------------|---------|
| Workflow initialization | `workflow_start` | After Step 3 (Initialize Logging) |
| Phase entry | `phase_start` | After pre-phase hooks, before steps |
| Step entry | `step_start` | Before executing each step |
| Step exit | `step_complete` | After step execution (success or failure) |
| Artifact creation | `artifact_create` | When any artifact is created |
| Phase exit | `phase_complete` | After post-phase hooks |
| Workflow end | `workflow_complete` | At workflow completion |

### Workflow ID Format

```
workflow-{work_id}-{timestamp}
```

Example: `workflow-199-20251202T150000Z`

### Event Emission Pattern

At each event point:
1. Build event payload with context
2. Invoke workflow-event-emitter skill
3. Log emission to state (for resume scenarios)

### Implementation

Add to each event point in the workflow:

**Workflow Start** (after Step 3):
```
WORKFLOW_ID="workflow-${work_id}-$(date -u +%Y%m%dT%H%M%SZ)"
state.workflow_id = WORKFLOW_ID

emit_workflow_event("workflow_start", {
  "context": {
    "work_item_id": state.work_id,
    "branch": state.branch.name || null,
    "autonomy_level": state.metadata.autonomy_level
  }
})
```

**Phase Start** (before phase steps):
```
emit_workflow_event("phase_start", {
  "phase": phase_name,
  "steps": phase.steps.map(s => s.name)
})
```

**Step Start** (before step execution):
```
emit_workflow_event("step_start", {
  "phase": phase_name,
  "step": {
    "name": step.name,
    "skill": step.skill || null
  }
})
```

**Step Complete** (after step execution):
```
emit_workflow_event("step_complete", {
  "phase": phase_name,
  "step": {
    "name": step.name,
    "status": result.success ? "success" : "failure",
    "duration_ms": step_duration,
    "error": result.error || null
  },
  "artifacts": step_artifacts
})
```

**Artifact Create** (when artifacts created):
```
emit_workflow_event("artifact_create", {
  "artifact": {
    "type": artifact_type,
    "path": artifact_path,
    "metadata": artifact_metadata
  },
  "step": current_step.name
})
```

**Phase Complete** (after post-hooks):
```
emit_workflow_event("phase_complete", {
  "phase": phase_name,
  "status": phase_status,
  "duration_ms": phase_duration,
  "steps_completed": completed_steps.length,
  "artifacts_created": phase_artifacts.length
})
```

**Workflow Complete** (at workflow end):
```
emit_workflow_event("workflow_complete", {
  "status": workflow_status,
  "duration_ms": total_duration,
  "summary": {
    "phases_executed": completed_phases.length,
    "steps_executed": total_steps,
    "artifacts_created": all_artifacts.length,
    "retries_used": state.retries.evaluate || 0
  },
  "artifacts": all_artifacts
})
```
</EVENT_EMISSION>
```

#### 2.2 Modify Workflow Steps

Update each relevant section in the `<WORKFLOW>` to call `emit_workflow_event()`.

### Phase 3: Configure S3 Push for Workflow Logs

**Location**: `plugins/logs/types/workflow/`

Update the workflow log type configuration to support S3 push.

#### 3.1 Update workflow standards.md

Add S3 configuration section:

```markdown
## S3 Storage Configuration

Workflow logs can be pushed to S3 for cross-project access.

**Configuration** (in project's `.fractary/plugins/logs/config.json`):

```json
{
  "types": {
    "workflow": {
      "local_retention_days": 7,
      "cloud_storage": {
        "enabled": true,
        "provider": "s3",
        "bucket": "${ORG}.logs.${PROJECT}",
        "prefix": "workflow/{year}/{month}/",
        "format": "json"
      }
    }
  }
}
```

**S3 Path Pattern**:
```
s3://{bucket}/workflow/{year}/{month}/workflow-{work_id}-{timestamp}.json
```

**Example**:
```
s3://fractary.logs.claude-plugins/workflow/2025/12/workflow-199-20251202T150000Z.json
```
```

### Phase 4: Update faber-manager Skill Documentation

Add to the `<DOCUMENTATION>` section:

```markdown
## Workflow Event Logging

All workflow executions emit structured events for downstream consumption.

### Event Flow

```
workflow_start
├── phase_start (frame)
│   ├── step_start → step_complete
│   └── phase_complete
├── phase_start (architect)
│   ├── step_start → step_complete
│   ├── artifact_create (spec)
│   └── phase_complete
├── phase_start (build)
│   ├── step_start → step_complete
│   ├── artifact_create (branch)
│   ├── artifact_create (commits)
│   └── phase_complete
├── phase_start (evaluate)
│   ├── step_start → step_complete
│   └── phase_complete
├── phase_start (release)
│   ├── step_start → step_complete
│   ├── artifact_create (pr)
│   └── phase_complete
└── workflow_complete
```

### Consuming Events

Downstream systems can poll S3 for events:

```python
# Example: Poll for completed workflows
import boto3
import json

s3 = boto3.client('s3')
bucket = 'fractary.logs.claude-plugins'
prefix = f'workflow/{datetime.now().year}/{datetime.now().month}/'

response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
for obj in response.get('Contents', []):
    log = json.loads(s3.get_object(Bucket=bucket, Key=obj['Key'])['Body'].read())
    if log.get('event_type') == 'workflow_complete':
        print(f"Workflow {log['workflow_id']} completed: {log['payload']['status']}")
```

### Disabling Event Emission

To disable event emission (for development/testing):

```json
// .fractary/plugins/faber/config.json
{
  "logging": {
    "emit_workflow_events": false
  }
}
```
```

---

## Event Schema (Final)

Based on SPEC-00047 and adapted for this implementation:

### workflow_start

```json
{
  "event_type": "workflow_start",
  "workflow_id": "workflow-199-20251202T150000Z",
  "timestamp": "2025-12-02T15:00:00Z",
  "project": "claude-plugins",
  "environment": "development",
  "payload": {
    "context": {
      "work_item_id": "199",
      "branch": null,
      "autonomy_level": "guarded"
    }
  }
}
```

### phase_start

```json
{
  "event_type": "phase_start",
  "workflow_id": "workflow-199-20251202T150000Z",
  "timestamp": "2025-12-02T15:01:00Z",
  "project": "claude-plugins",
  "environment": "development",
  "payload": {
    "phase": "architect",
    "steps": ["generate-spec"]
  }
}
```

### step_start / step_complete

```json
{
  "event_type": "step_complete",
  "workflow_id": "workflow-199-20251202T150000Z",
  "timestamp": "2025-12-02T15:10:00Z",
  "project": "claude-plugins",
  "environment": "development",
  "payload": {
    "phase": "architect",
    "step": {
      "name": "generate-spec",
      "skill": "fractary-spec:spec-generator",
      "status": "success",
      "duration_ms": 45000,
      "error": null
    },
    "artifacts": [
      {
        "type": "spec",
        "path": "/specs/WORK-00199-automatic-manager-workflow-logging.md"
      }
    ]
  }
}
```

### artifact_create

```json
{
  "event_type": "artifact_create",
  "workflow_id": "workflow-199-20251202T150000Z",
  "timestamp": "2025-12-02T15:10:30Z",
  "project": "claude-plugins",
  "environment": "development",
  "payload": {
    "artifact": {
      "type": "spec",
      "path": "/specs/WORK-00199-automatic-manager-workflow-logging.md",
      "metadata": {
        "template": "feature",
        "work_id": "199"
      }
    },
    "step": "generate-spec"
  }
}
```

### workflow_complete

```json
{
  "event_type": "workflow_complete",
  "workflow_id": "workflow-199-20251202T150000Z",
  "timestamp": "2025-12-02T16:00:00Z",
  "project": "claude-plugins",
  "environment": "development",
  "payload": {
    "status": "success",
    "duration_ms": 3600000,
    "summary": {
      "phases_executed": 5,
      "steps_executed": 8,
      "artifacts_created": 4,
      "retries_used": 0
    },
    "artifacts": [
      {"type": "branch", "path": "feat/199-automatic-manager-workflow-logging"},
      {"type": "spec", "path": "/specs/WORK-00199-automatic-manager-workflow-logging.md"},
      {"type": "commit", "count": 3},
      {"type": "pr", "url": "https://github.com/fractary/claude-plugins/pull/200"}
    ]
  }
}
```

---

## Implementation Tasks

### Task 1: Create workflow-event-emitter Skill

- [ ] Create `plugins/logs/skills/workflow-event-emitter/SKILL.md`
- [ ] Create `plugins/logs/skills/workflow-event-emitter/scripts/emit-event.sh`
- [ ] Add to plugin manifest

### Task 2: Enhance faber-manager Skill

- [ ] Add `<EVENT_EMISSION>` section to SKILL.md
- [ ] Add `emit_workflow_event()` calls at each orchestration point
- [ ] Add `workflow_id` to state initialization
- [ ] Update `<DOCUMENTATION>` section

### Task 3: Update Workflow Log Type

- [ ] Add S3 configuration to `plugins/logs/types/workflow/standards.md`
- [ ] Create example configuration in `plugins/logs/config/`

### Task 4: Documentation

- [ ] Update faber README with event logging info
- [ ] Add cross-project consumption examples
- [ ] Document configuration options

### Task 5: Testing

- [ ] Test event emission during full workflow
- [ ] Test S3 push (if configured)
- [ ] Test resume scenario (events not duplicated)
- [ ] Test with event emission disabled

---

## Configuration

### Enable Event Emission (default: true)

```json
// .fractary/plugins/faber/config.json
{
  "logging": {
    "use_logs_plugin": true,
    "log_type": "workflow",
    "emit_workflow_events": true
  }
}
```

### Configure S3 Push

```json
// .fractary/plugins/logs/config.json
{
  "types": {
    "workflow": {
      "local_retention_days": 7,
      "cloud_storage": {
        "enabled": true,
        "provider": "s3",
        "bucket": "fractary.logs.claude-plugins",
        "prefix": "workflow/{year}/{month}/"
      }
    }
  }
}
```

---

## Benefits

| Benefit | Description |
|---------|-------------|
| **Automatic** | Events emitted without manual intervention at each orchestration point |
| **Consistent** | All projects using faber-manager get same event schema |
| **Reusable** | Framework enhancement benefits all projects |
| **Traceable** | Full workflow lineage available |
| **Cross-Project** | S3 enables downstream polling |
| **Configurable** | Can be disabled for testing |
| **Resume-Safe** | Events tracked in state to prevent duplicates |

---

## Future Enhancements

1. **Real-time Streaming** - Add SNS/SQS support for real-time event delivery
2. **Event Versioning** - Add schema versioning for backward compatibility
3. **Dashboard Integration** - Create unified dashboard consuming events from all projects
4. **Alerting** - Configure alerts for workflow failures
5. **Metrics Aggregation** - Aggregate metrics across workflows for reporting

---

## Related Documentation

- [SPEC-00047](./SPEC-00047-framework-workflow-event-logging.md) - Original cross-project proposal
- [fractary-logs workflow type](../plugins/logs/types/workflow/standards.md)
- [faber-manager skill](../plugins/faber/skills/faber-manager/SKILL.md)
- [Manager-as-orchestrator pattern](../docs/conversations/2025-10-22-cli-tool-reorganization-faber-details.md)

---

_Specification created for Issue #199 - Automatic manager workflow logging_
