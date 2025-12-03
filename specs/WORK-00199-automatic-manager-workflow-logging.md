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

Multiple projects in the Fractary ecosystem use the **manager-as-orchestrator pattern** to orchestrate workflow steps. This includes:

- **faber-manager** in the FABER workflow
- **Custom project managers** (e.g., `corthion-manager` in etl.corthion.ai)
- **Direct commands** that bypass the full FABER harness

Each project has historically implemented its own changelog/event logging mechanism, leading to:

1. **Inconsistent formats** across projects
2. **Duplicate effort** implementing logging in each project
3. **Missed events** when developers forget to log
4. **No cross-project visibility** - downstream systems can't easily consume upstream workflow events

**Key Insight**: Not all projects use the full FABER workflow harness. Many have custom directors and managers that work locally. We need a solution that works for BOTH:
- Projects using faber-manager
- Projects with custom manager skills

---

## Solution Overview

Create a **standalone workflow-event-emitter skill** in the fractary-logs plugin that ANY manager skill can use to emit structured workflow events.

### Two Integration Paths

1. **FABER Projects**: faber-manager skill automatically emits events (zero manual effort)
2. **Custom Projects**: Project manager skills integrate with workflow-event-emitter (simple integration guide)

### Core Primitive

The **workflow-event-emitter** skill is a standalone primitive that:
- Accepts event type and payload
- Generates workflow_id if not provided
- Writes to fractary-logs with `workflow` log type
- Optionally pushes to S3 for cross-project access

Any manager skill can invoke it directly - no FABER dependency required.

---

## Architecture

### Two Integration Paths

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PATH 1: FABER WORKFLOW (Automatic)                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  faber-manager Skill                                                        │
│     ├─→ emit_workflow_event("workflow_start", {...})    ← AUTOMATIC       │
│     ├─→ emit_workflow_event("phase_start", {...})       ← AUTOMATIC       │
│     ├─→ emit_workflow_event("step_complete", {...})     ← AUTOMATIC       │
│     └─→ emit_workflow_event("workflow_complete", {...}) ← AUTOMATIC       │
│                                                                             │
│  Projects using /faber:run get logging with ZERO additional effort         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PATH 2: CUSTOM PROJECT MANAGERS (Integration)            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Custom Manager Skill (e.g., corthion-manager)                             │
│     │                                                                       │
│     ├── At workflow start:                                                  │
│     │   Skill("fractary-logs:workflow-event-emitter",                      │
│     │         operation="emit", event_type="workflow_start", ...)          │
│     │                                                                       │
│     ├── At step completion:                                                 │
│     │   Skill("fractary-logs:workflow-event-emitter",                      │
│     │         operation="emit", event_type="step_complete", ...)           │
│     │                                                                       │
│     └── At workflow end:                                                    │
│         Skill("fractary-logs:workflow-event-emitter",                      │
│               operation="emit", event_type="workflow_complete", ...)       │
│                                                                             │
│  Projects using custom managers integrate with ~10 lines per event         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│              SHARED: workflow-event-emitter Skill (fractary-logs)           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  • Generates workflow_id if not provided                                    │
│  • Adds timestamp, project, environment automatically                       │
│  • Validates event schema                                                   │
│  • Writes to fractary-logs with `workflow` log type                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    fractary-logs Storage Layer                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  log-writer skill                                                           │
│  ├── Local: .fractary/logs/workflow/workflow-{id}-{timestamp}.json        │
│  └── Cloud: s3://{bucket}/workflow/{year}/{month}/ (if configured)        │
│                                                                             │
│  Uses existing `workflow` log type standards                                │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Downstream Consumers                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│  • Poll S3 for events from any project                                     │
│  • Filter by project, event_type, artifact_type                            │
│  • Trigger downstream workflows (e.g., Glue catalog updates)               │
│  • Future: Master dashboard aggregating all projects                        │
└─────────────────────────────────────────────────────────────────────────────┘
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
- [ ] **Update faber-agent BEST-PRACTICES.md** with workflow event logging guidance (Section 8)

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
| **Automatic (FABER)** | Projects using faber-manager get logging with zero effort |
| **Simple Integration (Custom)** | Custom managers integrate with ~10 lines per event |
| **Consistent Schema** | All projects use same event format regardless of manager type |
| **Standalone Primitive** | workflow-event-emitter works independently of FABER |
| **Traceable** | Full workflow lineage available |
| **Cross-Project** | S3 enables downstream polling from any project |
| **Configurable** | Can be disabled for testing |
| **Minimal Viable** | Start with just 3 events (start, artifact, complete) for 80% value |

---

## Custom Project Manager Integration Guide

This section provides guidance for projects that use custom manager skills (not faber-manager) to integrate with workflow event logging.

### When to Use This Guide

Use this guide if your project:
- Has a custom manager skill (e.g., `corthion-manager`, `myproject-manager`)
- Uses direct commands without the FABER harness
- Wants consistent workflow logging without adopting full FABER workflow

### Integration Pattern

Add event emission calls to your manager skill's workflow at these key points:

#### 1. At Workflow Start

Add to your manager skill's initialization section:

```markdown
<WORKFLOW>
## Phase 0: Initialize Workflow Logging

1. Generate workflow ID:
   ```
   WORKFLOW_ID="workflow-${entity_id}-$(date -u +%Y%m%dT%H%M%SZ)"
   ```

2. Emit workflow start event:
   ```
   Skill("fractary-logs:workflow-event-emitter", {
     "operation": "emit",
     "event_type": "workflow_start",
     "workflow_id": WORKFLOW_ID,
     "payload": {
       "context": {
         "entity_id": entity_id,
         "entity_type": "dataset",
         "action": requested_action
       }
     }
   })
   ```
</WORKFLOW>
```

#### 2. At Each Step Completion

Wrap your step execution with event emission:

```markdown
## Step: {step_name}

1. Emit step start (optional, for detailed tracking):
   ```
   Skill("fractary-logs:workflow-event-emitter", {
     "operation": "emit",
     "event_type": "step_start",
     "workflow_id": WORKFLOW_ID,
     "payload": {
       "step": {"name": "validate", "skill": "myproject-validator"}
     }
   })
   ```

2. Execute the step:
   ```
   Skill("myproject-validator", ...)
   ```

3. Emit step complete:
   ```
   Skill("fractary-logs:workflow-event-emitter", {
     "operation": "emit",
     "event_type": "step_complete",
     "workflow_id": WORKFLOW_ID,
     "payload": {
       "step": {
         "name": "validate",
         "status": "success",
         "duration_ms": step_duration
       },
       "artifacts": [...]  // if any created
     }
   })
   ```
```

#### 3. On Artifact Creation

When your workflow creates important artifacts:

```markdown
## After Creating Artifact

Skill("fractary-logs:workflow-event-emitter", {
  "operation": "emit",
  "event_type": "artifact_create",
  "workflow_id": WORKFLOW_ID,
  "payload": {
    "artifact": {
      "type": "dataset",
      "dataset": "ipeds",
      "table": "hd",
      "version": "2024",
      "path": "s3://bucket/path/to/data/",
      "row_count": 6072
    },
    "step": "load"
  }
})
```

This is the most important event for downstream consumers (like lake.corthonomy.ai).

#### 4. At Workflow End

Complete the workflow with a summary event:

```markdown
## Final Step: Complete Workflow

Skill("fractary-logs:workflow-event-emitter", {
  "operation": "emit",
  "event_type": "workflow_complete",
  "workflow_id": WORKFLOW_ID,
  "payload": {
    "status": workflow_status,  // "success" or "failure"
    "duration_ms": total_duration,
    "summary": {
      "steps_executed": 4,
      "steps_succeeded": 4,
      "artifacts_created": 2
    },
    "artifacts": all_artifacts_list,
    "downstream_impacts": [
      {
        "system": "lake.corthonomy.ai",
        "impact_type": "data_refresh",
        "action_required": "Update Glue catalog for ipeds_hd table"
      }
    ]
  }
})
```

### Minimal Integration (Recommended Start)

If full step-by-step logging is too verbose, start with just **three events**:

1. `workflow_start` - At the beginning
2. `artifact_create` - When important outputs are created
3. `workflow_complete` - At the end with summary

This provides 80% of the value with minimal integration effort.

### Example: ETL Manager Skill

Here's a complete example for an ETL project manager:

```markdown
# corthion-manager Skill

<WORKFLOW>

## Initialize
- Generate WORKFLOW_ID
- Emit workflow_start

## Phase: Extract
- Run extraction skill
- Emit step_complete

## Phase: Transform
- Run transformation skill
- Emit step_complete

## Phase: Load
- Run load skill
- Emit artifact_create for each dataset loaded
- Emit step_complete

## Phase: Validate
- Run validation skill
- Emit step_complete

## Complete
- Calculate summary
- Emit workflow_complete with downstream_impacts

</WORKFLOW>
```

### Configuration

Custom project managers should configure S3 push in their logs config:

```json
// .fractary/plugins/logs/config.json
{
  "types": {
    "workflow": {
      "local_retention_days": 0,
      "cloud_storage": {
        "enabled": true,
        "provider": "s3",
        "bucket": "${ORG}.logs.${PROJECT}",
        "prefix": "workflow/{year}/{month}/"
      }
    }
  }
}
```

Setting `local_retention_days: 0` means events go directly to S3 without local storage (useful for ETL projects that primarily serve downstream consumers).

### Updating BEST-PRACTICES.md

Add this to Section 8 (Required Plugin Integrations) in faber-agent's BEST-PRACTICES.md:

```markdown
### Workflow Event Logging

All manager skills SHOULD emit structured workflow events for downstream consumption.

**Integration Options:**

1. **Use FABER**: Projects using `/faber:run` get automatic logging
2. **Manual Integration**: Custom managers invoke `fractary-logs:workflow-event-emitter`

**Minimum Events:**
- `workflow_start` - At workflow initialization
- `artifact_create` - When important outputs are created
- `workflow_complete` - At workflow end with summary

**Reference:** See WORK-00199 spec for detailed integration guide.
```

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
- [faber-agent BEST-PRACTICES.md](../plugins/faber-agent/docs/BEST-PRACTICES.md) - Project manager patterns (Section 8 covers plugin integrations)
- [Manager-as-Agent Pattern](../plugins/faber-agent/docs/standards/manager-as-agent-pattern.md) - Why managers are agents
- [fractary-logs workflow type](../plugins/logs/types/workflow/standards.md) - Workflow log schema
- [faber-manager skill](../plugins/faber/skills/faber-manager/SKILL.md) - FABER workflow orchestration

---

_Specification created for Issue #199 - Automatic manager workflow logging_
