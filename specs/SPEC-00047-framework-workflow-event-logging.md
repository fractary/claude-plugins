# SPEC-00047: Framework-Level Workflow Event Logging for Cross-Project Communication

## Metadata

| Field | Value |
|-------|-------|
| **Spec ID** | SPEC-00047 |
| **Title** | Framework-Level Workflow Event Logging for Cross-Project Communication |
| **Type** | Feature |
| **Status** | Proposal |
| **Created** | 2025-12-02 |
| **Target Repos** | fractary-logs, fractary-faber-agent |
| **Consumers** | All fractary projects using manager-as-orchestrator pattern |

---

## Problem Statement

Multiple Corthos projects need to communicate workflow execution events to downstream systems:

- **etl.corthion.ai** → lake.corthonomy.ai (dataset updates)
- **Future projects** → Various consumers (workflow artifacts)

Currently, each project would need to manually implement changelog recording, which:
1. Creates inconsistent formats across projects
2. Requires duplicate effort
3. Misses events when developers forget to log

---

## Proposed Solution: Automatic Workflow Event Emission

### Core Concept

The **manager-as-orchestrator pattern** (used across fractary plugins) should automatically emit `workflow` log events during execution. This provides:

1. **Automatic tracking** - No manual logging required
2. **Consistent format** - All projects use same schema
3. **S3 storage** - Cross-project access via shared S3
4. **Downstream polling** - Consumers can poll for relevant events
5. **Master Dashboard** - S3 storage enables creation of a unified dashboard to track workflow activity across ALL Corthos projects in one place

### Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                    Manager Skill Execution                        │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. Workflow Start                                                │
│     └─→ Emit: workflow_start event                               │
│                                                                   │
│  2. Skill Invocation (loop)                                      │
│     ├─→ Emit: step_start event                                   │
│     │   └─ skill_name, phase, target                             │
│     │                                                            │
│     └─→ Emit: step_complete event                                │
│         └─ status, duration, artifacts                           │
│                                                                   │
│  3. Artifact Creation (conditional)                              │
│     └─→ Emit: artifact_create event                              │
│         └─ type, path, metadata                                  │
│                                                                   │
│  4. Workflow Complete                                            │
│     └─→ Emit: workflow_complete event                            │
│         └─ status, duration, summary                             │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                    fractary-logs Plugin                          │
├──────────────────────────────────────────────────────────────────┤
│  • Uses existing `workflow` log type                             │
│  • Writes to local + S3 based on config                          │
│  • Follows retention rules (local_retention_days: 0 for S3-only) │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                    S3 Storage                                     │
├──────────────────────────────────────────────────────────────────┤
│  s3://{org}.logs.{project}/workflow/{year}/{month}/              │
│    workflow-{work_id}-{timestamp}.json                           │
│                                                                   │
│  Cross-project accessible with proper IAM                        │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Downstream Consumer                            │
├──────────────────────────────────────────────────────────────────┤
│  • Polls S3 for artifact_create events                           │
│  • Filters by project, dataset, event_type                       │
│  • Triggers appropriate actions                                  │
│                                                                   │
│  Example: lake.corthonomy.ai                                     │
│  - Polls for artifact_create where artifact.type = "dataset"     │
│  - Triggers Glue table update                                    │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Master Dashboard (Future)                      │
├──────────────────────────────────────────────────────────────────┤
│  • Aggregates workflow events from all Corthos projects          │
│  • Unified view of ETL activity across the platform              │
│  • Real-time monitoring of workflow health                       │
│  • Cross-project dependency tracking                             │
└──────────────────────────────────────────────────────────────────┘
```

---

## Event Schema

### workflow_start

```json
{
  "event_type": "workflow_start",
  "workflow_id": "workflow-{identifier}-{timestamp}",
  "timestamp": "2025-12-02T10:00:00Z",
  "project": "etl.corthion.ai",
  "environment": "test",
  "context": {
    "work_item_id": "71",
    "branch": "feat/71-description",
    "action": "update",
    "targets": ["ipeds_hd", "ipeds_ic"]
  }
}
```

### step_start / step_complete

```json
{
  "event_type": "step_complete",
  "workflow_id": "workflow-71-20251202T100000Z",
  "timestamp": "2025-12-02T10:15:00Z",
  "step": {
    "name": "corthion-data-loader",
    "phase": "load",
    "target": "ipeds_hd",
    "status": "success",
    "duration_ms": 45230
  },
  "artifacts": [
    {
      "type": "dataset",
      "dataset": "ipeds",
      "table": "hd",
      "version": "2024",
      "path": "s3://test.etl.corthion.ai/curated/ipeds/hd/version=2024/",
      "row_count": 6072
    }
  ]
}
```

### artifact_create

Standalone event when artifacts are created outside skill execution:

```json
{
  "event_type": "artifact_create",
  "workflow_id": "workflow-71-20251202T100000Z",
  "timestamp": "2025-12-02T10:15:30Z",
  "artifact": {
    "type": "dataset",
    "dataset": "ipeds",
    "table": "hd",
    "version": "2024",
    "path": "s3://test.etl.corthion.ai/curated/ipeds/hd/version=2024/",
    "row_count": 6072,
    "schema_path": "src/datasets/ipeds/hd/SCHEMA.md"
  },
  "upstream": {
    "project": "etl.corthion.ai",
    "workflow_id": "workflow-71-20251202T100000Z"
  }
}
```

### workflow_complete

```json
{
  "event_type": "workflow_complete",
  "workflow_id": "workflow-71-20251202T100000Z",
  "timestamp": "2025-12-02T10:30:00Z",
  "status": "success",
  "duration_ms": 180000,
  "summary": {
    "steps_executed": 8,
    "steps_succeeded": 8,
    "steps_failed": 0,
    "artifacts_created": 5
  },
  "downstream_impacts": [
    {
      "system": "lake.corthonomy.ai",
      "impact_type": "data_refresh",
      "action_required": "Update Glue catalog for ipeds_hd, ipeds_ic tables"
    }
  ]
}
```

---

## Implementation Plan

### Phase 1: Event Emission in Manager Skills

**Location**: Each project's manager skill (e.g., `corthion-manager`)

Add event emission hooks:

```python
# In manager skill workflow orchestration

from fractary_logs import emit_workflow_event

class WorkflowManager:
    def execute_workflow(self, config):
        workflow_id = f"workflow-{config.work_id}-{timestamp}"

        # Emit start event
        emit_workflow_event("workflow_start", {
            "workflow_id": workflow_id,
            "context": config.to_dict()
        })

        for step in self.steps:
            # Emit step start
            emit_workflow_event("step_start", {
                "workflow_id": workflow_id,
                "step": {"name": step.name, "phase": step.phase}
            })

            result = step.execute()

            # Emit step complete with artifacts
            emit_workflow_event("step_complete", {
                "workflow_id": workflow_id,
                "step": {...},
                "artifacts": result.artifacts
            })

        # Emit workflow complete
        emit_workflow_event("workflow_complete", {...})
```

### Phase 2: fractary-logs Plugin Enhancement

**File**: `fractary-logs/skills/log-writer.py`

Add `emit_workflow_event()` helper:

```python
def emit_workflow_event(event_type: str, payload: dict):
    """Emit a workflow event to S3 storage."""

    event = {
        "event_type": event_type,
        "timestamp": datetime.utcnow().isoformat() + "Z",
        **payload
    }

    # Use workflow log type configuration
    log_writer.write(
        type="workflow",
        operation="etl-pipeline",
        message=json.dumps(event),
        format="json"
    )
```

### Phase 3: S3 Cross-Project Access

**Configuration**: Each project configures S3 bucket access:

```json
// .fractary/plugins/logs/config.json
{
  "types": {
    "workflow": {
      "local_retention_days": 0,
      "cloud_storage": {
        "enabled": true,
        "bucket": "{org}.logs.{project}",
        "prefix": "workflow/{year}/{month}/"
      }
    }
  },
  "cross_project_access": {
    "enabled": true,
    "read_buckets": [
      "corthos.logs.etl.corthion.ai"
    ]
  }
}
```

### Phase 4: Consumer Polling Implementation

**Example**: lake.corthonomy.ai polling script

```python
def poll_for_dataset_updates():
    """Poll etl.corthion.ai workflow logs for dataset updates."""

    s3 = boto3.client('s3')
    bucket = 'corthos.logs.etl.corthion.ai'
    prefix = f'workflow/{datetime.now().year}/{datetime.now().month}/'

    # Get workflow logs from last hour
    response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)

    for obj in response.get('Contents', []):
        log = json.loads(s3.get_object(Bucket=bucket, Key=obj['Key'])['Body'].read())

        # Filter for dataset artifacts
        if log.get('event_type') == 'artifact_create':
            artifact = log.get('artifact', {})
            if artifact.get('type') == 'dataset':
                update_glue_catalog(
                    dataset=artifact['dataset'],
                    table=artifact['table'],
                    version=artifact['version'],
                    s3_path=artifact['path']
                )
```

### Phase 5: Master Dashboard (Future)

**Concept**: A unified dashboard that aggregates workflow events from all Corthos projects.

**Benefits**:
- Single pane of glass for all ETL activity
- Cross-project dependency visualization
- Real-time health monitoring
- Historical trend analysis
- Alerting on workflow failures

**Implementation Approach**:
1. All projects emit workflow events to S3
2. Dashboard service polls S3 buckets from all projects
3. Events aggregated into time-series database
4. Web UI displays unified view

---

## Benefits

| Benefit | Description |
|---------|-------------|
| **Automatic** | Events emitted without manual intervention |
| **Consistent** | All projects use same event schema |
| **Reusable** | Framework enhancement benefits all projects |
| **Traceable** | Full workflow lineage available |
| **Cross-Project** | S3 enables downstream polling |
| **Configurable** | Retention and storage per project needs |
| **Master Dashboard** | S3 storage enables creation of a unified dashboard to track workflow activity across ALL Corthos projects in one place |

---

## Existing Infrastructure Leveraged

| Component | Status | Usage |
|-----------|--------|-------|
| `workflow` log type schema | EXISTS | Event structure |
| fractary-logs plugin | EXISTS | Writing/storage |
| S3 log storage | EXISTS | Cross-project access |
| faber-agent state | EXISTS | Supplement workflow context |

---

## Scope

### In Scope

1. Event emission helper in fractary-logs
2. Manager skill integration pattern documentation
3. S3 cross-project access configuration
4. Consumer polling example implementation

### Out of Scope

1. Real-time event streaming (SNS/SQS)
2. Event schema versioning
3. Automatic consumer registration
4. UI for event monitoring (initial phase)

---

## Next Steps

1. Create issue in `fractary-logs` repo for event emission helper
2. Create issue in `fractary-faber-agent` repo for manager integration
3. Document integration pattern for project manager skills
4. Implement in etl.corthion.ai as first consumer
5. Implement polling in lake.corthonomy.ai

---

## Related Documentation

- [fractary-logs workflow type standards](~/.claude/plugins/marketplaces/fractary/plugins/logs/types/workflow/standards.md)
- [Manager-as-orchestrator pattern](docs/architecture/ADR/ADR-00002-manager-as-orchestrator.md)
- [etl.corthion.ai CLAUDE.md](CLAUDE.md)
- [WORK-00071](specs/WORK-00071-cross-project-integration-updates.md) - Project-specific integration updates

---

_Specification created for Issue #71 - Cross-project communication strategy_
