# FABER Run ID System

The Run ID system provides per-run isolation, event logging, and resume/re-run capabilities for FABER workflows.

## Overview

Every FABER workflow execution is assigned a unique Run ID that isolates its state, artifacts, and event history. This enables:

- **Parallel Execution**: Multiple runs can proceed without interference
- **Complete History**: All events are preserved for debugging and auditing
- **Resume Capability**: Failed or paused runs can be resumed from the exact failure point
- **Re-run Capability**: Runs can be re-executed with different parameters
- **S3 Archival**: Events can be archived to S3 for long-term storage

## Run ID Format

```
{org}/{project}/{uuid}
```

- **org**: Organization name (auto-detected from git remote)
- **project**: Project name (auto-detected from git repository name)
- **uuid**: UUID v4 for uniqueness

**Examples**:
```
fractary/claude-plugins/a1b2c3d4-e5f6-7890-abcd-ef1234567890
acme-corp/payment-service/12345678-1234-1234-1234-123456789abc
```

### Auto-Detection

The org and project are automatically detected:

1. **Org**: Extracted from `git remote origin` URL
   - SSH: `git@github.com:org/repo.git` → `org`
   - HTTPS: `https://github.com/org/repo.git` → `org`
   - Fallback: `local`

2. **Project**: From git repository name or current directory
   - Git root: `$(basename $(git rev-parse --show-toplevel))`
   - Fallback: `$(basename $PWD)`

## Directory Structure

Each run gets its own isolated directory:

```
.fractary/plugins/faber/runs/
└── {org}/
    └── {project}/
        └── {uuid}/
            ├── state.json        # Current workflow state
            ├── metadata.json     # Run metadata (work_id, target, etc.)
            └── events/
                ├── .next-id      # Sequence counter
                ├── 001-workflow_start.json
                ├── 002-phase_start.json
                ├── 003-step_start.json
                └── ...
```

### state.json

Current workflow state (materialized view of events):

```json
{
  "run_id": "fractary/claude-plugins/a1b2c3d4-...",
  "work_id": "158",
  "status": "in_progress",
  "current_phase": "build",
  "last_event_id": 15,
  "workflow_version": "2.1",
  "phases": {
    "frame": { "status": "completed", "steps": [...] },
    "architect": { "status": "completed", "steps": [...] },
    "build": { "status": "in_progress", "steps": [...] },
    "evaluate": { "status": "pending", "steps": [] },
    "release": { "status": "pending", "steps": [] }
  },
  "artifacts": {
    "spec_path": ".faber/specs/SPEC-00158-feature.md",
    "branch_name": "feat/158-implement-feature"
  }
}
```

**Status Values**:
- `pending` - Run created but not started
- `in_progress` - Workflow actively executing
- `awaiting_feedback` - Paused, waiting for user feedback (HITL)
- `completed` - Workflow finished successfully
- `failed` - Workflow failed with error
- `cancelled` - Workflow cancelled by user

**HITL Feedback Request** (present when `status == "awaiting_feedback"`):
```json
{
  "feedback_request": {
    "request_id": "fr-20251206-a1b2c3",
    "type": "approval",
    "prompt": "Please review the design and approve to proceed.",
    "options": ["approve", "reject", "request_changes"],
    "context": {
      "artifact_path": "/specs/SPEC-00158-design.md",
      "summary": "3-layer architecture with handler pattern"
    },
    "requested_at": "2025-12-06T18:00:00Z",
    "notification_sent": {
      "cli": true,
      "issue_comment": true,
      "comment_url": "https://github.com/org/repo/issues/158#issuecomment-xyz"
    }
  },
  "resume_point": {
    "phase": "architect",
    "step": "design-review",
    "step_index": 2
  }
}
```

### metadata.json

Immutable run metadata:

```json
{
  "run_id": "fractary/claude-plugins/a1b2c3d4-...",
  "work_id": "158",
  "target": "customer-analytics-v2",
  "workflow_id": "default",
  "autonomy": "guarded",
  "phases": ["frame", "architect", "build", "evaluate", "release"],
  "created_at": "2025-12-04T10:30:00Z",
  "created_by": "claude",
  "relationships": {
    "rerun_of": null
  }
}
```

## Event Types

The Run ID system supports 25+ event types:

### Workflow Events
- `workflow_start` - Workflow begins
- `workflow_complete` - Workflow finished successfully
- `workflow_error` - Workflow failed
- `workflow_cancelled` - Workflow cancelled by user
- `workflow_resumed` - Workflow resumed from previous run
- `workflow_rerun` - New run based on previous run

### Phase Events
- `phase_start` - Phase begins
- `phase_skip` - Phase skipped
- `phase_complete` - Phase finished successfully
- `phase_error` - Phase failed

### Step Events
- `step_start` - Step begins
- `step_complete` - Step finished successfully
- `step_error` - Step failed
- `step_retry` - Step being retried
- `step_skip` - Step skipped (by user decision or configuration)

### Feedback Events (HITL)
- `feedback_request` - Feedback requested from user (decision point)
- `feedback_received` - User provided feedback response
- `decision_point` - Workflow paused awaiting user decision
- `approval_request` - Approval requested at autonomy gate
- `approval_granted` - User approved continuation
- `approval_denied` - User denied/rejected action

### Retry Events
- `retry_loop_enter` - Entering retry loop (evaluate phase)
- `retry_loop_exit` - Exiting retry loop

### Artifact Events
- `artifact_create` - Artifact created
- `artifact_modify` - Artifact modified

### Git Events
- `commit_create` - Git commit created
- `branch_create` - Git branch created
- `pr_create` - Pull request created
- `pr_merge` - Pull request merged

### Other Events
- `spec_generate` - Specification generated
- `spec_validate` - Specification validated
- `test_run` - Tests executed
- `docs_update` - Documentation updated
- `checkpoint` - Manual checkpoint
- `skill_invoke` - Skill invoked
- `agent_invoke` - Agent invoked
- `hook_execute` - Hook executed

## Event Schema

Each event follows a common schema:

```json
{
  "event_id": 15,
  "type": "step_complete",
  "timestamp": "2025-12-04T10:35:42.123Z",
  "run_id": "fractary/claude-plugins/a1b2c3d4-...",
  "phase": "build",
  "step": "implement",
  "status": "completed",
  "message": "Implementation completed successfully",
  "user": "claude",
  "source": "faber-manager",
  "metadata": {
    "files_changed": 5,
    "lines_added": 150,
    "lines_removed": 20
  }
}
```

## Usage

### Starting a New Run

```bash
# Target with work ID
/fractary-faber:run customer-analytics --work-id 158

# Work ID only (target inferred)
/fractary-faber:run --work-id 158
```

A new run ID is generated automatically.

### Resuming a Run

```bash
# Resume from where it failed
/fractary-faber:run --resume fractary/claude-plugins/a1b2c3d4-...

# Resume from a specific step
/fractary-faber:run --resume fractary/claude-plugins/a1b2c3d4-... --step build:implement
```

Resume:
- Loads state from the specified run
- Skips completed phases/steps
- Continues from the first incomplete step
- Uses the same run_id (no new ID generated)

### Re-running with Changes

```bash
# Re-run with different autonomy
/fractary-faber:run --rerun fractary/claude-plugins/a1b2c3d4-... --autonomy autonomous

# Re-run specific phases only
/fractary-faber:run --rerun fractary/claude-plugins/a1b2c3d4-... --phase build,evaluate
```

Re-run:
- Creates a **new run ID** with `rerun_of` relationship to original
- Inherits work_id and target from original
- Applies parameter overrides (autonomy, phases)
- Emits `workflow_rerun` event

### Viewing Run Status

```bash
# View current/recent runs
/fractary-faber:status

# View specific run
/fractary-faber:status --run-id fractary/claude-plugins/a1b2c3d4-...
```

## Event Gateway

Events are routed through the FABER Event Gateway, configured in `.fractary/plugins/faber/gateway.json`:

```json
{
  "version": "1.0",
  "backends": {
    "local_files": {
      "enabled": true,
      "config": {
        "base_path": ".fractary/plugins/faber/runs",
        "sync_writes": true
      }
    },
    "s3_archive": {
      "enabled": false,
      "config": {
        "bucket": "fractary-workflow-logs",
        "prefix": "faber/runs/",
        "region": "us-east-1",
        "consolidate_on_complete": true
      }
    }
  }
}
```

### Local Files Backend

- Default backend, always enabled
- Writes events to per-run `events/` directory
- Uses atomic file operations with sequence numbering
- Syncs to disk for durability

### S3 Archive Backend (Optional)

- Archives completed runs to S3
- Consolidates events to JSONL format for efficient storage
- Configurable cleanup of local files after archive
- Supports event retention policies

To enable:
```json
{
  "backends": {
    "s3_archive": {
      "enabled": true,
      "config": {
        "bucket": "your-bucket-name"
      }
    }
  }
}
```

## Scripts Reference

### generate-run-id.sh

Generate a new run ID:

```bash
# Auto-detect org and project
./scripts/generate-run-id.sh
# Output: fractary/claude-plugins/a1b2c3d4-...

# Explicit org and project
./scripts/generate-run-id.sh --org acme --project api
# Output: acme/api/a1b2c3d4-...

# UUID only
./scripts/generate-run-id.sh --uuid-only
# Output: a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

### init-run-directory.sh

Initialize a run directory:

```bash
./scripts/init-run-directory.sh \
  --run-id "fractary/claude-plugins/a1b2c3d4-..." \
  --work-id "158" \
  --target "customer-analytics" \
  --workflow "default" \
  --autonomy "guarded"
```

### emit-event.sh

Emit an event:

```bash
./scripts/emit-event.sh \
  --run-id "fractary/claude-plugins/a1b2c3d4-..." \
  --type "phase_start" \
  --phase "build" \
  --status "started" \
  --message "Starting build phase"
```

### resume-run.sh

Prepare resume context:

```bash
./scripts/resume-run.sh --run-id "fractary/claude-plugins/a1b2c3d4-..."
# Returns JSON with completed_phases, current_phase, current_step, artifacts
```

### rerun-run.sh

Create a re-run:

```bash
./scripts/rerun-run.sh \
  --run-id "fractary/claude-plugins/a1b2c3d4-..." \
  --autonomy "autonomous"
# Returns JSON with new run_id and rerun context
```

## Troubleshooting

### Run Directory Not Found

```
Error: Run directory not found: .fractary/plugins/faber/runs/org/project/uuid
```

The run ID may be incorrect, or the run was cleaned up. Check available runs:
```bash
ls -la .fractary/plugins/faber/runs/
```

### Cannot Resume Completed Run

```
Error: Cannot resume a completed run. Use --rerun to start a new run.
```

Completed runs cannot be resumed. Use `--rerun` to create a new run based on the original.

### Event Sequence Mismatch

If events appear out of order, the `.next-id` file may be corrupted. Reconstruct it:
```bash
# Find highest event ID
ls .fractary/plugins/faber/runs/{run_id}/events/ | grep -E '^[0-9]+' | sort -n | tail -1
# Update .next-id to next value
```

## Best Practices

1. **Let Run IDs be auto-generated**: Don't manually construct run IDs
2. **Use resume for failures**: Resume continues the same run without duplication
3. **Use re-run for changes**: Re-run creates a linked but independent run
4. **Archive completed runs**: Enable S3 backend for long-term storage
5. **Clean up old runs**: Set retention policies to manage disk space

## See Also

- [CONFIGURATION.md](./configuration.md) - FABER configuration guide
- [STATE-TRACKING.md](./STATE-TRACKING.md) - State management details
- [SPEC-00108](../../specs/SPEC-00108-faber-run-id-event-logging.md) - Technical specification
