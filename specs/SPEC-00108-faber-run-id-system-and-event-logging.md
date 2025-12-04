---
org: fractary
system: claude-code
title: FABER Run ID System and Event Logging Architecture
description: Comprehensive specification for workflow run identification, event capture, logging infrastructure, and integration with centralized monitoring (Helm). Enables run re-execution, step-level resumption, parallel execution safety, and future analytics integration.
tags: [faber, run-id, workflow-logging, event-gateway, audit-trail, state-management, helm-integration]
created: 2025-12-04
updated: 2025-12-04
codex_sync_include: []
codex_sync_exclude: []
visibility: internal
---

# FABER Run ID System and Event Logging Architecture

**Specification ID:** SPEC-00108
**Version:** 1.0.0
**Status:** Draft
**Created:** 2025-12-04
**Author:** System Architecture
**Related Issues:** #217 (workflow run re-run and step status tracking)
**Related Specs:** 
- SPEC-00002 (FABER Architecture)
- SPEC-00047 (Framework Workflow Event Logging)
- SPEC-00007 (Helm System Specification)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Problem Statement](#problem-statement)
3. [Solution Overview](#solution-overview)
4. [Run ID System](#run-id-system)
5. [Per-Run File Isolation](#per-run-file-isolation)
6. [Workflow Event Logging](#workflow-event-logging)
7. [MCP Event Gateway Architecture](#mcp-event-gateway-architecture)
8. [State vs Logging Relationship](#state-vs-logging-relationship)
9. [S3 Archive Strategy](#s3-archive-strategy)
10. [Resume and Re-run Capabilities](#resume-and-re-run-capabilities)
11. [Helm Integration Points](#helm-integration-points)
12. [Implementation Phases](#implementation-phases)
13. [Configuration](#configuration)
14. [Examples & Workflows](#examples--workflows)
15. [Backward Compatibility](#backward-compatibility)
16. [Open Questions & Future Work](#open-questions--future-work)

---

## Executive Summary

### Purpose

This specification establishes a comprehensive framework for:

1. **Run Identification**: Unique, traceable identifiers for workflow executions
2. **Event Capture**: Comprehensive logging of all workflow activities
3. **State Management**: Clear separation between operational state and audit logs
4. **Resume Capability**: Step-level resumption from stored state
5. **Analytics Integration**: Foundation for Helm-style centralized visibility

### Key Features

- **Truly Unique Run IDs**: UUID-based format with org/project prefix (`{org}/{project}/{uuid}`)
- **Parallel Execution Safety**: Per-run isolated files prevent write conflicts
- **Event Gateway Pattern**: Local MCP server abstracts transport layer
- **Dual-State Tracking**: Operational state for workflow logic + audit logs for history
- **S3 Archival**: Organized structure for analytics and compliance
- **Future-Proof**: Designed for real-time dashboards without requiring them now

### Strategic Value

- **Run Accountability**: Every workflow execution is traceable and reproducible
- **Failure Recovery**: Resume from last successful step without re-executing completed work
- **Re-execution**: Re-run failed workflows or re-execute with different parameters
- **Compliance**: Complete audit trail for all workflow activities
- **Analytics Ready**: Data structure supports aggregation and reporting
- **Helm Integration**: Foundation for centralized workflow visibility without building it yet

---

## Problem Statement

### Current State Issues

1. **Workflow Instances Are Anonymous**
   - No way to distinguish between multiple runs of the same workflow
   - Failed runs cannot be resumed; must restart from beginning
   - No audit trail for what was attempted

2. **No Step-Level Resumption**
   - If build step fails after 2 hours of work, entire workflow must restart
   - No checkpoint/recovery mechanism
   - Wastes time and resources

3. **Parallel Execution Collisions**
   - Multiple managers running in parallel write to shared state files
   - No isolation between runs
   - Potential data corruption or overwrites

4. **Logging is Ad-Hoc**
   - Events captured inconsistently across phases
   - No standardized event format
   - Difficult to reconstruct what happened during a workflow

5. **No Central Visibility**
   - Cannot monitor multiple workflows in flight
   - No analytics on workflow performance
   - Cannot detect patterns in failures

6. **Missing Integration Points for Helm**
   - Helm (future monitoring system) requires structured events
   - Current logging not suitable for real-time dashboards
   - No way to query workflow history

### Business Impact

- **Reliability**: Failed workflows become "start over" situations
- **User Experience**: No visibility into what's happening or why
- **Operations**: Cannot diagnose issues across multiple concurrent runs
- **Analytics**: No data for performance optimization
- **Governance**: Incomplete audit trail for compliance

---

## Solution Overview

### Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│  Helm (Future Monitoring Dashboard)                     │
│  - Real-time workflow visibility                        │
│  - Analytics and aggregation                            │
│  - Performance trends                                   │
└────────────────┬────────────────────────────────────────┘
                 │ Consumes
                 ▼
┌─────────────────────────────────────────────────────────┐
│  Event Archive (S3)                                     │
│  - org/{project}/{run_id}/events/                      │
│  - Consolidation from per-run files                     │
│  - Analytics queries via Athena                         │
└────────────────┬────────────────────────────────────────┘
                 │ Stores
                 ▼
┌─────────────────────────────────────────────────────────┐
│  MCP Event Gateway (Local Server)                       │
│  - Central point for event routing                      │
│  - Abstract transport layer                             │
│  - Support multiple backends                           │
└────────────────┬────────────────────────────────────────┘
                 │ Routes to
      ┌──────────┴──────────┐
      ▼                     ▼
 Local Files            S3 Bucket
 (per-run)             (archive)
 Event streams         Consolidation
 State.json            Analytics
└────────────────────────────────────────────────────────┘
```

### Core Concepts

**Run ID**: Unique identifier for a workflow execution
- Format: `{org}/{project}/{uuid}`
- Example: `fractary/claude-plugins/550e8400-e29b-41d4-a716-446655440000`
- Generated at workflow start
- Immutable for the duration of the workflow

**Event**: Discrete activity occurrence during workflow
- Type: workflow_start, phase_start, step_start, step_complete, artifact_create, etc.
- Timestamp: ISO 8601 with millisecond precision
- Metadata: Context about what changed
- Immutable: Written once, never modified

**State**: Operational view of current workflow status
- File: `.fractary/plugins/faber/runs/{run_id}/state.json`
- Materialized view of latest events
- Used by workflow logic for decisions
- Can be reconstructed from events

**Log**: Source of truth for workflow history
- Location: `.fractary/plugins/faber/runs/{run_id}/events/`
- Per-run files: `{sequence}-{type}.json`
- Immutable after written
- Used for audit, recovery, and analytics

---

## Run ID System

### Design Rationale

A robust run ID system must:

1. **Guarantee Uniqueness**: No collisions across parallel executions
2. **Support Multi-Tenancy**: Filter by org/project for analytics
3. **Be Immutable**: Not change during workflow lifetime
4. **Be Traceable**: Connect workflow to issue, PR, and branches
5. **Support Analytics**: Partition data for efficient queries

### Run ID Format

```
{org}/{project}/{uuid}
```

**Components**:

| Component | Format | Example | Purpose |
|-----------|--------|---------|---------|
| `org` | kebab-case | `fractary` | Organization/workspace identifier |
| `project` | kebab-case | `claude-plugins` | Repository/project identifier |
| `uuid` | UUID v4 | `550e8400-e29b-41d4-a716-446655440000` | Unique instance identifier |

**Full Example**:
```
fractary/claude-plugins/550e8400-e29b-41d4-a716-446655440000
```

### Generation Algorithm

```bash
# 1. Collect context
org=$(git config --get fractary.org || echo "fractary")
project=$(basename $(git rev-parse --show-toplevel))
workspace_user=$(echo $USER | tr '[:upper:]' '[:lower:]')

# 2. Generate UUID v4 (random)
uuid=$(uuidgen | tr '[:upper:]' '[:lower:]')

# 3. Assemble run_id
run_id="${org}/${project}/${uuid}"

# 4. Log for traceability
echo "Starting workflow run: $run_id" >&2
```

**Key Points**:
- UUID v4 ensures cryptographic randomness
- No sequential IDs (avoid timing attacks, ensure true parallelism)
- Org/project context enables multi-tenant analytics
- No timestamps in ID (use event timestamps instead)

### Run ID Lifecycle

```
┌──────────────┐
│   Generate   │ ← At workflow start
│  UUID + org  │
└──────┬───────┘
       │
       ▼
┌──────────────────┐
│  Create dirs     │ ← Ensure isolation
│ /runs/{run_id}/  │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  Initialize      │ ← State + first event
│  state.json      │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  Execute phases  │ ← Write events
│  and steps       │   Update state
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  Archive logs    │ ← Upload to S3
│  to S3           │   Update index
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  Cleanup local   │ ← Keep state for
│  event files     │   potential resume
└──────────────────┘
```

### Run ID Reference Resolution

Workflows may reference runs by:

1. **Full ID**: `fractary/claude-plugins/550e8400-e29b-41d4-a716-446655440000`
2. **Abbreviated**: `550e8400-e29b-41d4-a716-446655440000` (auto-detect org/project)
3. **Latest**: `latest` (implies current org/project, resolves to most recent)

**Resolution Logic**:
```json
{
  "rules": [
    {
      "pattern": "{org}/{project}/{uuid}",
      "context": "full_id",
      "resolution": "Direct lookup"
    },
    {
      "pattern": "{uuid}",
      "context": "abbreviated",
      "resolution": "Scan current project for matching runs"
    },
    {
      "pattern": "latest",
      "context": "keyword",
      "resolution": "Scan runs dir, return most recent by start time"
    }
  ]
}
```

---

## Per-Run File Isolation

### Directory Structure

```
.fractary/plugins/faber/runs/
├── {org}/
│   └── {project}/
│       └── {uuid}/
│           ├── state.json              # Operational state
│           ├── events/
│           │   ├── 001-workflow_start.json
│           │   ├── 002-phase_start.json
│           │   ├── 003-step_start.json
│           │   ├── 004-step_complete.json
│           │   ├── 005-artifact_create.json
│           │   └── ...
│           └── metadata.json           # Run metadata
```

### File Purposes

#### state.json

**Purpose**: Operational view of workflow status for decision-making

**Usage**:
- Determine what to execute next
- Identify last completed step
- Enable resumption

**Format**:
```json
{
  "run_id": "fractary/claude-plugins/550e8400-e29b-41d4-a716-446655440000",
  "status": "in_progress",
  "current_phase": "build",
  "current_step": "implement",
  "phases": {
    "frame": {
      "status": "completed",
      "started_at": "2025-12-04T10:00:00Z",
      "completed_at": "2025-12-04T10:05:00Z",
      "steps": {
        "fetch-issue": {
          "status": "completed",
          "completed_at": "2025-12-04T10:05:00Z"
        }
      }
    },
    "architect": {
      "status": "completed",
      "steps": {
        "analyze-requirements": {
          "status": "completed",
          "completed_at": "2025-12-04T10:10:00Z"
        },
        "generate-spec": {
          "status": "completed",
          "completed_at": "2025-12-04T10:15:00Z",
          "spec_path": "/home/user/repo/specs/WORK-00217.md"
        }
      }
    },
    "build": {
      "status": "in_progress",
      "started_at": "2025-12-04T10:15:00Z",
      "steps": {
        "implement": {
          "status": "in_progress",
          "started_at": "2025-12-04T10:15:00Z"
        }
      }
    }
  },
  "last_event_id": 5,
  "error": null,
  "metadata": {
    "work_id": "217",
    "parameters": {
      "autonomy": "guarded",
      "workflow": "default"
    }
  }
}
```

**Key Properties**:
- `status`: workflow status (in_progress, completed, failed, cancelled)
- `current_phase` / `current_step`: For resumption
- `phases`: Phase-wise progress tracking
- `last_event_id`: For consistency checks
- `error`: If workflow failed, root cause

#### events/{sequence}-{type}.json

**Purpose**: Immutable audit trail of all activities

**Naming Convention**:
- `{sequence}`: 3-digit zero-padded sequence number (001, 002, 003...)
- `{type}`: Event type (workflow_start, phase_start, step_complete, etc.)
- Example: `001-workflow_start.json`, `042-step_complete.json`

**Format** (Generic):
```json
{
  "event_id": 1,
  "type": "workflow_start",
  "timestamp": "2025-12-04T10:00:00.000Z",
  "run_id": "fractary/claude-plugins/550e8400-e29b-41d4-a716-446655440000",
  "phase": null,
  "step": null,
  "user": "claude-code",
  "metadata": {
    "work_id": "217",
    "parameters": {
      "autonomy": "guarded",
      "workflow": "default",
      "phases": ["frame", "architect", "build"]
    },
    "trigger": "manual",
    "branch": "main"
  }
}
```

#### metadata.json

**Purpose**: Run-level metadata for quick lookup

**Format**:
```json
{
  "run_id": "fractary/claude-plugins/550e8400-e29b-41d4-a716-446655440000",
  "org": "fractary",
  "project": "claude-plugins",
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "status": "completed",
  "started_at": "2025-12-04T10:00:00Z",
  "completed_at": "2025-12-04T11:30:00Z",
  "duration_seconds": 5400,
  "work_id": "217",
  "issue_url": "https://github.com/fractary/claude-plugins/issues/217",
  "pr_url": "https://github.com/fractary/claude-plugins/pull/1234",
  "branch": "feat/217-run-id-system",
  "workflow": "default",
  "autonomy": "guarded",
  "parameters": {
    "target": "workflow run ID system",
    "phases": ["frame", "architect", "build"],
    "custom_instructions": "Focus on parallel execution safety"
  },
  "result": {
    "status": "success",
    "artifacts": [
      "/home/user/repo/specs/WORK-00217.md",
      "commit: abc1234"
    ]
  }
}
```

### Isolation Guarantees

**Per-Run Isolation Prevents**:

1. **Write Conflicts**: Each run has unique directory tree
2. **State Corruption**: No shared state.json between runs
3. **Event Loss**: Each run appends to its own event log
4. **Resume Conflicts**: State recovery doesn't affect other runs

**Multi-Run Scenarios**:

```
Scenario: 2 concurrent runs of same workflow

Run 1: fractary/claude-plugins/aaa...
  ├── state.json (Run 1 state only)
  └── events/001-workflow_start.json (Run 1 events only)

Run 2: fractary/claude-plugins/bbb...
  ├── state.json (Run 2 state only)
  └── events/001-workflow_start.json (Run 2 events only)

Result: Zero conflicts, parallel execution safe
```

---

## Workflow Event Logging

### Event Types

Comprehensive event taxonomy for complete workflow visibility:

| Event Type | Phase | Trigger | Metadata |
|-----------|-------|---------|----------|
| `workflow_start` | N/A | Workflow initialization | parameters, work_id, trigger |
| `workflow_complete` | N/A | Workflow success | status, duration, artifacts |
| `workflow_error` | N/A | Workflow failure | error, phase, step, remediation |
| `workflow_cancelled` | N/A | Manual cancellation | reason, by_user |
| `phase_start` | Any | Phase entry | phase_name, steps_count |
| `phase_skip` | Any | Phase skipped | phase_name, reason |
| `phase_error` | Any | Phase failure | phase_name, error, retries_remaining |
| `step_start` | Any | Step execution begins | phase_name, step_name, tool_invocation |
| `step_complete` | Any | Step execution succeeds | phase_name, step_name, duration, outputs |
| `step_error` | Any | Step execution fails | phase_name, step_name, error, retry_scheduled |
| `step_retry` | Any | Step retry attempt | phase_name, step_name, retry_number, reason |
| `artifact_create` | Build | Artifact creation | artifact_path, artifact_type, size_bytes |
| `artifact_modify` | Build | Artifact modification | artifact_path, change_type, diff_summary |
| `commit_create` | Build | Git commit | commit_hash, commit_message, files_changed |
| `branch_create` | Build | Git branch creation | branch_name, from_branch |
| `pr_create` | Release | PR creation | pr_number, pr_url, pr_title |
| `pr_merge` | Release | PR merge | pr_number, merge_strategy, merge_commit |
| `issue_comment` | Any | GitHub issue comment | issue_number, comment_id, comment_text_summary |
| `spec_generate` | Architect | Spec file creation | spec_path, spec_type, requirements_count |
| `spec_validate` | Evaluate | Spec validation | spec_path, validation_status, gaps |
| `test_run` | Evaluate | Test execution | test_type, passed_count, failed_count, coverage |
| `docs_update` | Release | Documentation update | doc_path, doc_type, sections_changed |
| `checkpoint` | Any | Manual checkpoint | checkpoint_name, checkpoint_data |
| `skill_invoke` | Any | Skill invocation | skill_name, skill_params, skill_output_summary |
| `agent_invoke` | Any | Agent delegation | agent_name, agent_request |
| `decision_point` | Any | Workflow decision | decision_type, options_evaluated, chosen_option |
| `retry_loop_enter` | Any | Enter retry logic | retry_policy, max_retries |
| `retry_loop_exit` | Any | Exit retry logic | retry_status, successful, retries_used |

### Event Schema

All events conform to this base schema:

```json
{
  "event_id": 1,
  "type": "step_complete",
  "timestamp": "2025-12-04T10:05:30.123Z",
  "run_id": "fractary/claude-plugins/550e8400-e29b-41d4-a716-446655440000",
  "phase": "frame",
  "step": "fetch-issue",
  "user": "claude-code",
  "source": "faber-manager",
  "status": "success",
  "duration_ms": 2500,
  "metadata": {
    "work_id": "217",
    "issue_url": "https://github.com/fractary/claude-plugins/issues/217",
    "issue_title": "Implement run ID system",
    "custom": {
      "files_fetched": 5,
      "comments_loaded": 12
    }
  },
  "error": null,
  "correlation_id": "corr-123",
  "retry_attempt": 0
}
```

**Common Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `event_id` | integer | Yes | Sequence in run (1, 2, 3...) |
| `type` | string | Yes | Event type from taxonomy |
| `timestamp` | string | Yes | ISO 8601 with milliseconds |
| `run_id` | string | Yes | Which workflow run |
| `phase` | string | No | Which phase (null for workflow-level events) |
| `step` | string | No | Which step (null for phase-level events) |
| `user` | string | Yes | Who triggered (user or system) |
| `source` | string | Yes | Which component created event |
| `status` | string | Yes | success, failure, pending, skipped |
| `duration_ms` | integer | No | Execution time in milliseconds |
| `metadata` | object | Yes | Event-specific details |
| `error` | object | No | If failed, error details |
| `correlation_id` | string | No | Links related events |
| `retry_attempt` | integer | No | Which retry attempt (0 = first) |

### Event Examples

#### Example 1: Step Complete Event

```json
{
  "event_id": 4,
  "type": "step_complete",
  "timestamp": "2025-12-04T10:05:30.123Z",
  "run_id": "fractary/claude-plugins/550e8400-e29b-41d4-a716-446655440000",
  "phase": "architect",
  "step": "generate-spec",
  "user": "claude-code",
  "source": "faber-manager",
  "status": "success",
  "duration_ms": 45000,
  "metadata": {
    "skill": "fractary-spec:spec-generator",
    "spec_path": "/home/user/repo/specs/WORK-00217.md",
    "spec_type": "feature",
    "requirements_count": 8,
    "acceptance_criteria_count": 5
  },
  "error": null,
  "correlation_id": "arch-gen-1",
  "retry_attempt": 0
}
```

#### Example 2: Step Error with Retry

```json
{
  "event_id": 7,
  "type": "step_error",
  "timestamp": "2025-12-04T10:12:15.456Z",
  "run_id": "fractary/claude-plugins/550e8400-e29b-41d4-a716-446655440000",
  "phase": "build",
  "step": "implement",
  "user": "claude-code",
  "source": "faber-manager",
  "status": "failure",
  "duration_ms": 120000,
  "metadata": {
    "skill": "faber-manager:build-executor",
    "retry_scheduled": true,
    "retry_delay_ms": 5000,
    "retry_number": 1,
    "reason": "Tool invocation failed - will retry"
  },
  "error": {
    "type": "ToolInvocationError",
    "message": "Bash command failed with exit code 1",
    "command": "npm test",
    "stdout": "...",
    "stderr": "TypeError: Cannot read property 'map' of undefined",
    "exit_code": 1
  },
  "correlation_id": "build-impl-1",
  "retry_attempt": 0
}
```

#### Example 3: Artifact Create Event

```json
{
  "event_id": 12,
  "type": "artifact_create",
  "timestamp": "2025-12-04T10:35:20.789Z",
  "run_id": "fractary/claude-plugins/550e8400-e29b-41d4-a716-446655440000",
  "phase": "build",
  "step": "implement",
  "user": "claude-code",
  "source": "bash",
  "status": "success",
  "duration_ms": null,
  "metadata": {
    "artifact_path": "/home/user/repo/plugins/faber/skills/run-manager/SKILL.md",
    "artifact_type": "skill_definition",
    "size_bytes": 28450,
    "lines_of_content": 612,
    "created_by_step": "implement"
  },
  "error": null,
  "correlation_id": "build-impl-1",
  "retry_attempt": 0
}
```

---

## MCP Event Gateway Architecture

### Purpose

The MCP (Model Context Protocol) Event Gateway serves as the **central, abstract point** for event routing. It:

1. **Decouples FABER from transport**: Events don't know where they go
2. **Supports multiple backends**: Local files, S3, future event streams
3. **Enables extensibility**: Add new backends without changing FABER
4. **Provides observability**: Monitor event flow through gateway
5. **Handles ordering**: Ensure events maintain sequence across backends

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ FABER Components (faber-manager, phase skills, step scripts)   │
│ - Generate events via standardized interface                   │
└────────────────────┬────────────────────────────────────────────┘
                     │ emit_event(event_data)
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ MCP Event Gateway (Local Server)                               │
│ - Receive and validate events                                  │
│ - Assign sequence numbers                                      │
│ - Route to configured backends                                │
│ - Handle ordering and reliability                             │
└────────────────────┬────────────────────────────────────────────┘
                     │
        ┌────────────┴──────────────┐
        │ Route to backends         │
        │ (based on config)         │
        ▼                           ▼
   ┌─────────────┐         ┌──────────────┐
   │ Local Files │         │ S3 Archive   │
   │ (per-run)   │         │ (backup)     │
   └─────────────┘         └──────────────┘
```

### MCP Server Implementation

**Service**: `fractary-faber-event-gateway`

**Features**:
- Listens on local Unix socket or TCP port
- Validates events before routing
- Provides querying interface
- Manages backend connections
- Handles backpressure and retries

**Resources** (MCP Format):

```json
{
  "resources": [
    {
      "uri": "faber://event/emit",
      "name": "Emit Event",
      "description": "Send event to gateway for routing"
    },
    {
      "uri": "faber://run/{run_id}/state",
      "name": "Get Run State",
      "description": "Retrieve current state of run"
    },
    {
      "uri": "faber://run/{run_id}/events",
      "name": "List Events",
      "description": "Query events for a run"
    }
  ]
}
```

### Event Emission Interface

FABER components emit events via:

```bash
# Bash script interface
emit_event() {
  local event_type="$1"
  local event_data="$2"
  
  # Call gateway via socket
  echo "$event_data" | \
    nc -U ~/.fractary/faber-gateway.sock \
    -c "POST /event" \
    -H "Content-Type: application/json"
}

# Usage
emit_event "step_complete" '{
  "phase": "build",
  "step": "implement",
  "status": "success",
  "duration_ms": 45000
}'
```

Or via Python/Node library:

```python
from fractary_faber import EventGateway

gateway = EventGateway()
gateway.emit(
    event_type="step_complete",
    phase="build",
    step="implement",
    status="success",
    duration_ms=45000
)
```

### Configuration

**Location**: `.fractary/plugins/faber/gateway.json`

```json
{
  "version": "1.0.0",
  "gateway": {
    "listen": "unix:///home/user/.fractary/faber-gateway.sock",
    "buffer_size": 1000,
    "flush_interval_ms": 5000
  },
  "backends": {
    "local_files": {
      "enabled": true,
      "priority": 1,
      "config": {
        "base_path": ".fractary/plugins/faber/runs",
        "flush_on_phase_complete": true
      }
    },
    "s3_archive": {
      "enabled": true,
      "priority": 2,
      "config": {
        "bucket": "fractary-workflow-logs",
        "region": "us-east-1",
        "prefix": "faber/runs",
        "consolidation_enabled": true,
        "consolidation_schedule": "0 2 * * *"
      }
    },
    "event_stream": {
      "enabled": false,
      "priority": 3,
      "config": {
        "service_url": "https://helm.fractary.io",
        "api_key_env": "HELM_API_KEY",
        "batch_size": 100
      }
    }
  }
}
```

### Backend Abstraction

Backends implement common interface:

```python
class EventBackend(ABC):
    @abstractmethod
    async def emit(self, event: Event) -> bool:
        """Emit event to backend. Return True if successful."""
        pass
    
    @abstractmethod
    async def query(self, run_id: str, filters: dict) -> List[Event]:
        """Query events from backend."""
        pass
    
    @abstractmethod
    async def flush(self, run_id: str) -> int:
        """Flush pending events. Return count flushed."""
        pass
```

**Local Files Backend**: Writes to per-run event files
**S3 Backend**: Uploads to S3 with consolidation
**Event Stream Backend** (future): Real-time streaming to Helm

---

## State vs Logging Relationship

### Clear Distinction

**State** and **Logs** serve different purposes and must be clearly separated:

| Aspect | State | Logs |
|--------|-------|------|
| **Purpose** | Operational view for decisions | Historical record for audit/recovery |
| **File** | `state.json` | `events/{seq}-{type}.json` |
| **Mutability** | Read + Write (updatable) | Write-once (immutable) |
| **Scope** | Current workflow snapshot | Complete history |
| **Used For** | Next step determination, resumption | Audit trail, debugging, analytics |
| **Retention** | Local (with backups) | S3 + local (archive) |
| **Query** | Direct file read | Event stream analysis |

### State as Materialized View

State.json is a **materialized view** of events—it can be reconstructed:

```
Events (source of truth)
  ↓
  Process all events for a run
  ↓
  Extract current state (latest of each event type)
  ↓
  Write to state.json
  ↓
State (derived view)
```

**Reconstruction Algorithm**:
```python
def reconstruct_state_from_events(run_id: str) -> dict:
    events = read_all_events(run_id)
    state = initialize_empty_state(run_id)
    
    for event in sorted(events, key=lambda e: e.event_id):
        if event.type == "phase_start":
            state["phases"][event.phase]["status"] = "in_progress"
        elif event.type == "phase_complete":
            state["phases"][event.phase]["status"] = "completed"
        elif event.type == "step_complete":
            state["phases"][event.phase]["steps"][event.step]["status"] = "completed"
        # ... etc
    
    return state
```

### Recovery from Events

If state.json is corrupted or lost:

1. **Detect corruption**: Checksum mismatch with events
2. **Reconstruct**: Use algorithm above to rebuild
3. **Validate**: Ensure reconstructed state is consistent
4. **Resume**: Use reconstructed state for next steps

### Event Durability Guarantees

Events are immutable and durable:

1. **Written immediately**: Event persisted before function returns
2. **Never modified**: No edits to event files
3. **Sequenced properly**: Sequence numbers prevent out-of-order reads
4. **Checksum protected**: Calculate hash of event for integrity
5. **Archived**: Copied to S3 for long-term retention

---

## S3 Archive Strategy

### Rationale

Local per-run events are ephemeral (subject to cleanup). S3 archive provides:

1. **Long-term retention**: Indefinite history for compliance
2. **Centralized access**: Single place to query all runs
3. **Analytics ready**: Partition structure supports Athena queries
4. **Cost optimization**: Archive older events to Glacier
5. **Compliance**: Immutable storage for audit trails

### Path Structure

```
s3://fractary-workflow-logs/
├── faber/
│   └── runs/
│       └── {org}/
│           └── {project}/
│               └── {uuid}/
│                   ├── state.json (final state)
│                   ├── metadata.json
│                   └── events.jsonl (consolidated)
```

**Full Example**:
```
s3://fractary-workflow-logs/faber/runs/fractary/claude-plugins/550e8400-e29b-41d4-a716-446655440000/
├── state.json
├── metadata.json
└── events.jsonl
```

### Consolidation Strategy

**Local Format**: Many small files (one event per file)
```
.fractary/plugins/faber/runs/{org}/{project}/{uuid}/events/
├── 001-workflow_start.json
├── 002-phase_start.json
├── 003-step_start.json
└── ...
```

**Archive Format**: Single JSONL file (one event per line)
```
s3://.../{uuid}/events.jsonl
{"event_id": 1, "type": "workflow_start", ...}
{"event_id": 2, "type": "phase_start", ...}
{"event_id": 3, "type": "step_start", ...}
```

**Consolidation Process**:

```bash
# 1. Collect all events from local files
# 2. Sort by event_id
# 3. Write to JSONL format (one event per line)
# 4. Upload to S3
# 5. Update metadata.json with archive_url
# 6. Delete local event files (keep state.json)
```

### Analytics Queries

With events.jsonl in S3, Athena can query:

```sql
-- Find all failed runs
SELECT metadata.run_id, COUNT(*) as error_count
FROM s3_events
WHERE type IN ('step_error', 'workflow_error')
GROUP BY metadata.run_id

-- Average phase duration
SELECT phase, AVG(duration_ms) as avg_duration
FROM s3_events
WHERE type = 'phase_complete'
GROUP BY phase

-- Failure patterns by workflow
SELECT metadata.parameters.workflow, metadata.parameters.autonomy, COUNT(*) as failure_count
FROM s3_events
WHERE type = 'workflow_error'
GROUP BY 1, 2
ORDER BY failure_count DESC
```

### Lifecycle Policies

```json
{
  "lifecycle_rules": [
    {
      "id": "archive_after_30_days",
      "filter": {
        "prefix": "faber/runs/"
      },
      "transitions": [
        {
          "days": 30,
          "storage_class": "GLACIER"
        },
        {
          "days": 90,
          "storage_class": "DEEP_ARCHIVE"
        }
      ],
      "expiration": {
        "days": 2555
      }
    }
  ]
}
```

---

## Resume and Re-run Capabilities

### Resume: Continue from Last Step

Resume picks up workflow execution from the last completed step without re-executing.

**Preconditions**:
- Run stopped (error, cancellation, or manual)
- State.json exists and is valid
- Run not yet archived

**Algorithm**:

```bash
# 1. Load state.json for run_id
state=$(cat .fractary/plugins/faber/runs/{run_id}/state.json)

# 2. Determine last completed step
last_phase=$(jq -r '.current_phase' <<< "$state")
last_step=$(jq -r '.current_step' <<< "$state")

# 3. Identify next phase/step to execute
if [[ $last_step == "complete" ]]; then
  # Phase completed, move to next phase
  next_phase=$(get_next_phase "$last_phase")
  next_step=$(get_first_step "$next_phase")
else
  # Step failed/incomplete, retry it
  next_phase=$last_phase
  next_step=$last_step
fi

# 4. Create new event: workflow_resumed
emit_event "workflow_resumed" "{ \
  run_id: '$run_id', \
  resumed_from_phase: '$last_phase', \
  resumed_from_step: '$last_step', \
  next_phase: '$next_phase', \
  next_step: '$next_step' \
}"

# 5. Continue with workflow from next step
execute_phase "$next_phase" --start-at "$next_step"
```

**Example**:

```
Original run:
  Frame → Architect → Build (implement failed at 2:35pm) → Cancel

Resume run:
  Load state: current_phase=build, current_step=implement
  Determine: Build already started, retry "implement" step
  Result: Execute only implement step, skip frame/architect
```

### Re-run: Execute with Different Parameters

Re-run executes the same workflow but with modified parameters or targets.

**Preconditions**:
- Original run completed (success or failure)
- Have completed original run's metadata
- Know what parameters changed

**Algorithm**:

```bash
# 1. Load original run's metadata
original_metadata=$(cat .fractary/plugins/faber/runs/{old_run_id}/metadata.json)

# 2. Generate new run_id
new_run_id=$(generate_run_id)

# 3. Copy initial state, but update parameters
new_state=$(jq \
  --arg new_run_id "$new_run_id" \
  --arg new_param "$new_value" \
  '.run_id = $new_run_id | .parameters.some_param = $new_param' \
  <<< "$original_metadata")

# 4. Create initial event
emit_event "workflow_rerun" "{ \
  original_run_id: '$old_run_id', \
  new_run_id: '$new_run_id', \
  parameter_changes: { \
    old: $(jq .parameters <<< "$original_metadata"), \
    new: $(jq .parameters <<< "$new_state") \
  } \
}"

# 5. Start fresh workflow with new run_id
/fractary-faber:run --work-id 217 --run-id "$new_run_id"
```

**Example**:

```
Original: /fractary-faber:run --work-id 217 --autonomy guarded
Result: Failed at evaluate phase due to test failure

Re-run: /fractary-faber:run --work-id 217 --run-id rerun-001 --autonomy assist
Result: New run_id, same work_id, different autonomy level
```

### Resume vs Re-run Decision

| Scenario | Correct Action | Reason |
|----------|---|---|
| Build step failed, fix code locally, continue | **Resume** | Same workflow, same parameters |
| Phase N failed, need to change approach in earlier phase | **Re-run** | Different parameters/instructions |
| Work completed, need to re-execute to verify | **Re-run** | New run for clean audit trail |
| Workflow cancelled mid-execution, want to continue | **Resume** | Same work, same parameters |

### Run ID in Commands

```bash
# Resume specific run
/fractary-faber:run --work-id 217 --resume 550e8400-e29b-41d4-a716-446655440000

# Abbreviated resume (auto-detect project)
/fractary-faber:run --work-id 217 --resume 550e8400-e29b-41d4-a716-446655440000

# Re-run with new run_id (new audit trail)
/fractary-faber:run --work-id 217 --rerun 550e8400-e29b-41d4-a716-446655440000

# Re-run with parameter changes
/fractary-faber:run --work-id 217 --rerun 550e8400-e29b-41d4-a716-446655440000 --autonomy assist
```

---

## Helm Integration Points

### Current State (This Spec)

**What Helm will consume:**
1. **Event streams**: `events.jsonl` files in S3
2. **Run metadata**: Consolidated metadata for quick lookup
3. **State snapshots**: Final state.json for workflow outcomes

**Integration touchpoints**:
- Event schema is extensible for future Helm fields
- Run ID structure supports multi-tenant analytics
- S3 path structure enables partition-based queries
- Metadata includes work-id for traceability

### Future State (Helm Implementation)

**Not included in this spec**, but architecture supports:

1. **Real-time Dashboard**:
   - Helm consumes from event-stream backend
   - Real-time phase/step progress
   - Live failure alerts

2. **Historical Analytics**:
   - Athena queries on archived events.jsonl
   - Trend analysis across workflows
   - Performance metrics by workflow/autonomy level

3. **Centralized Logging**:
   - Helm receives stream from `event_stream` backend
   - Aggregates logs from multiple projects
   - Full-text search across all runs

4. **Workflow Replay**:
   - Helm reconstructs workflow visually from events
   - Step-by-step execution timeline
   - Artifact linkage

### Configuration for Helm Integration

In `.fractary/plugins/faber/gateway.json`:

```json
{
  "backends": {
    "event_stream": {
      "enabled": false,
      "priority": 3,
      "config": {
        "service_url": "https://helm.fractary.io",
        "api_key_env": "HELM_API_KEY",
        "batch_size": 100,
        "retry_policy": {
          "max_retries": 3,
          "backoff_ms": 1000
        }
      }
    }
  }
}
```

**Future**: Enable by setting `enabled: true` and providing `HELM_API_KEY`

### Event API Contract for Helm

Events sent to Helm follow same schema with optional Helm-specific fields:

```json
{
  "event_id": 42,
  "type": "step_complete",
  "timestamp": "2025-12-04T10:35:20.789Z",
  "run_id": "fractary/claude-plugins/550e8400-e29b-41d4-a716-446655440000",
  "phase": "build",
  "step": "implement",
  
  ... standard fields ...
  
  "helm": {
    "dashboard_url": "https://helm.fractary.io/runs/550e8400-e29b-41d4-a716-446655440000",
    "ui_component": "step-status",
    "ui_state": "completed",
    "badges": ["success", "build-phase"],
    "notification": {
      "severity": "info",
      "title": "Build: Implement step completed"
    }
  }
}
```

---

## Implementation Phases

### Phase 1: Run ID System Foundation (Week 1-2)

**Deliverables**:
- [x] Run ID generation with UUID + org/project prefix
- [x] Per-run directory structure under `.fractary/plugins/faber/runs/`
- [x] Initialization of run directories on workflow start
- [x] Documentation of Run ID format and lifecycle

**Components**:
- Run ID generation utility (bash + Python)
- Directory initialization script
- Tests for collision detection

**Entry Point**: `faber-director` before phase execution

### Phase 2: State and Event File Format (Week 2-3)

**Deliverables**:
- [x] state.json schema and writer
- [x] Event file format (sequence + type naming)
- [x] Event schema with all event types
- [x] Metadata.json structure

**Components**:
- Event builder (validates and serializes events)
- State manager (reads/writes state.json)
- Event file writer (creates numbered event files)
- Reconstruction algorithm (state from events)

**Integration Points**:
- Phase skills emit events at key points
- Step scripts record artifacts via events

### Phase 3: MCP Event Gateway (Week 3-4)

**Deliverables**:
- [x] MCP server setup (local Unix socket)
- [x] Event validation before routing
- [x] Local files backend (write to per-run directories)
- [x] Backend abstraction interface

**Components**:
- Gateway server (Python MCP implementation)
- Event validation (JSON schema)
- Local backend
- Configuration loading

**Integration Points**:
- faber-manager calls gateway for all events
- Phase skills use gateway instead of direct files

### Phase 4: Local Resume Capability (Week 4-5)

**Deliverables**:
- [x] Resume command: `--resume {run_id}`
- [x] State reconstruction from events
- [x] Step-level resumption logic
- [x] Validation that resumed run matches original

**Components**:
- Resume loader (reads state, determines next step)
- Step executor (skips completed steps)
- Tests for resume scenarios

**Integration Points**:
- `faber-director` processes `--resume` flag
- Workflow manager respects skipped steps

### Phase 5: S3 Archive Backend (Week 5-6)

**Deliverables**:
- [x] S3 backend implementation (write events.jsonl)
- [x] Consolidation process (per-run files → JSONL)
- [x] Archive index in S3
- [x] Local cleanup after successful archive

**Components**:
- S3 backend class
- Event consolidation script
- Archive completion logic
- S3 lifecycle policies

**Integration Points**:
- Gateway routes events to S3 backend
- Phase completion triggers archive
- Release phase handles cleanup

### Phase 6: Re-run and Advanced Resume (Week 6-7)

**Deliverables**:
- [x] Re-run command: `--rerun {run_id} [new-params]`
- [x] Re-run metadata handling
- [x] Validation that re-run parameters differ appropriately
- [x] Re-run vs Resume decision matrix

**Components**:
- Re-run loader (creates new run_id)
- Parameter differ (detects changes)
- Validation logic
- Abort conditions

**Integration Points**:
- `faber-director` processes `--rerun` flag
- Metadata.json records re-run relationships

### Phase 7: Helm Integration Foundation (Week 7-8)

**Deliverables**:
- [x] Event stream backend skeleton (disabled by default)
- [x] Configuration for Helm service URL
- [x] Helm-specific event fields (optional)
- [x] Documentation for future activation

**Components**:
- Event stream backend class
- Helm-specific event envelope
- Configuration schema
- Activation instructions

**Integration Points**:
- Gateway config supports event-stream backend
- No actual Helm service calls yet

### Phase 8: Testing and Documentation (Week 8)

**Deliverables**:
- [x] Integration tests for full workflow
- [x] Resume/re-run scenario tests
- [x] Performance tests (event throughput)
- [x] Complete documentation
- [x] Migration guide from v2.0 → v2.1

**Components**:
- Test suite (pytest)
- Documentation (all workflows)
- Examples (resume, re-run, resume failed run)

---

## Configuration

### Main Gateway Configuration

**File**: `.fractary/plugins/faber/gateway.json`

```json
{
  "version": "1.0.0",
  "run_id": {
    "format": "{org}/{project}/{uuid}",
    "uuid_version": 4,
    "auto_detect_org_project": true
  },
  "gateway": {
    "listen": "unix:///home/user/.fractary/faber-gateway.sock",
    "tcp_port": null,
    "buffer_size": 1000,
    "flush_interval_ms": 5000,
    "enable_metrics": true,
    "metrics_port": 9090
  },
  "storage": {
    "runs_base_path": ".fractary/plugins/faber/runs",
    "state_file": "state.json",
    "metadata_file": "metadata.json",
    "events_dir": "events"
  },
  "backends": {
    "local_files": {
      "enabled": true,
      "priority": 1,
      "retry_policy": {
        "max_retries": 3,
        "backoff_ms": 1000
      },
      "config": {
        "base_path": ".fractary/plugins/faber/runs",
        "flush_on_phase_complete": true,
        "flush_on_workflow_complete": true
      }
    },
    "s3_archive": {
      "enabled": true,
      "priority": 2,
      "retry_policy": {
        "max_retries": 5,
        "backoff_ms": 2000
      },
      "config": {
        "bucket": "fractary-workflow-logs",
        "region": "us-east-1",
        "prefix": "faber/runs",
        "consolidation_enabled": true,
        "consolidation_schedule": "0 2 * * *",
        "cleanup_local_after_archive": true,
        "cleanup_delay_hours": 24
      }
    },
    "event_stream": {
      "enabled": false,
      "priority": 3,
      "retry_policy": {
        "max_retries": 3,
        "backoff_ms": 1000
      },
      "config": {
        "service_url": "https://helm.fractary.io",
        "api_key_env": "HELM_API_KEY",
        "batch_size": 100,
        "batch_timeout_ms": 10000
      }
    }
  },
  "durability": {
    "fsync_enabled": true,
    "checksum_events": true,
    "checksum_algorithm": "sha256"
  }
}
```

### Integration with FABER Configuration

**File**: `.fractary/plugins/faber/config.json`

```json
{
  "schema_version": "2.0",
  "run_tracking": {
    "enabled": true,
    "gateway_config": "./gateway.json",
    "capture_initial_parameters": true,
    "capture_initial_branch": true,
    "track_artifacts": true
  },
  "workflows": [
    {
      "id": "default",
      "file": "./workflows/default.json",
      "description": "Standard FABER workflow"
    }
  ]
}
```

---

## Examples & Workflows

### Example 1: Complete Workflow with Run Tracking

```bash
# 1. User invokes workflow
/fractary-faber:run --work-id 217 --autonomy guarded

# Output:
# RUN-ID: fractary/claude-plugins/550e8400-e29b-41d4-a716-446655440000
# Status: STARTED

# 2. faber-director generates run_id and emits event
Event: workflow_start
  run_id: fractary/claude-plugins/550e8400-e29b-41d4-a716-446655440000
  work_id: 217
  autonomy: guarded

# 3. Phase skills emit phase/step events
Event: phase_start (phase=frame)
Event: step_start (step=fetch-issue)
Event: step_complete (step=fetch-issue, duration=2500ms)
Event: phase_complete (phase=frame)

# 4. Phase storage structure
.fractary/plugins/faber/runs/
└── fractary/claude-plugins/550e8400-e29b-41d4-a716-446655440000/
    ├── state.json (updated after each event)
    ├── metadata.json
    └── events/
        ├── 001-workflow_start.json
        ├── 002-phase_start.json
        ├── 003-step_start.json
        ├── 004-step_complete.json
        └── ...

# 5. At completion, archive to S3
s3://fractary-workflow-logs/faber/runs/
└── fractary/claude-plugins/550e8400-e29b-41d4-a716-446655440000/
    ├── state.json (final state)
    ├── metadata.json
    └── events.jsonl (consolidated)
```

### Example 2: Resume from Failed Step

```bash
# Initial run hits error during build
.fractary/plugins/faber/runs/.../{uuid}/
├── state.json (current_phase=build, current_step=implement)
├── events/ (partial)
│   ├── 001-workflow_start.json
│   ├── ...
│   ├── 015-step_error.json (implement failed)
│   └── 016-workflow_error.json

# User sees failure, fixes code, resumes
/fractary-faber:run --work-id 217 --resume 550e8400-e29b-41d4-a716-446655440000

# 1. Load state for 550e8400...
#    current_phase: build
#    current_step: implement
#    status: failed

# 2. Emit resume event
Event: workflow_resumed
  original_run_id: 550e8400-e29b-41d4-a716-446655440000
  resumed_from_phase: build
  resumed_from_step: implement
  next_phase: build
  next_step: implement

# 3. Execute only implement step (skip frame/architect/earlier-build-steps)
# Result: Build phase completes, continues to evaluate/release

# 4. Final state
state.json:
  status: completed
  phases:
    build:
      status: completed
      steps:
        implement:
          attempts: [failed, success]
          status: completed
```

### Example 3: Re-run with Different Parameters

```bash
# Original run completed but results not satisfactory
/fractary-faber:run --work-id 217 --autonomy guarded
# Result: Workflow completed but manual review suggests changes

# User initiates re-run with different autonomy
/fractary-faber:run --work-id 217 --rerun 550e8400-e29b-41d4-a716-446655440000 --autonomy assist

# 1. Generate new run_id
new_run_id: fractary/claude-plugins/aaa1aaa2-aaa3-aaa4-aaa5-aaa6aaa7aaa8

# 2. Emit re-run event
Event: workflow_rerun
  original_run_id: 550e8400-e29b-41d4-a716-446655440000
  new_run_id: aaa1aaa2-aaa3-aaa4-aaa5-aaa6aaa7aaa8
  parameter_changes:
    autonomy: guarded → assist

# 3. Execute fresh workflow with new run_id and autonomy
# Result: Separate audit trail for investigation

# 4. Both runs visible in S3
s3://fractary-workflow-logs/faber/runs/fractary/claude-plugins/
├── 550e8400.../
│   ├── state.json (original: autonomy=guarded)
│   └── events.jsonl
├── aaa1aaa2.../
│   ├── state.json (re-run: autonomy=assist)
│   └── events.jsonl
```

### Example 4: Query Events via Athena

```sql
-- All runs for issue 217
SELECT run_id, status, started_at, completed_at, duration_seconds
FROM s3_object_columns 'faber/runs/fractary/claude-plugins/*/metadata.json'
WHERE work_id = '217'
ORDER BY started_at DESC

-- Failed runs needing investigation
SELECT 
  run_id,
  metadata.parameters.autonomy,
  error.type,
  error.message,
  COUNT(*) as error_count
FROM s3_object_columns 'faber/runs/fractary/claude-plugins/*/events.jsonl'
WHERE type IN ('step_error', 'workflow_error')
GROUP BY 1, 2, 3, 4
ORDER BY error_count DESC

-- Build phase performance trends
SELECT 
  DATE(timestamp) as execution_date,
  AVG(duration_ms) as avg_build_time,
  MAX(duration_ms) as max_build_time,
  COUNT(*) as build_count
FROM s3_object_columns 'faber/runs/fractary/claude-plugins/*/events.jsonl'
WHERE phase = 'build' AND type = 'phase_complete'
GROUP BY 1
ORDER BY 1
```

---

## Backward Compatibility

### Migration from v2.0 (No Run IDs)

**Current v2.0 Behavior**:
- Single state.json at `.fractary/plugins/faber/state.json`
- No event logging
- No support for multiple concurrent runs

**Migration Strategy**:

1. **Detection**: Check for legacy v2.0 config
2. **Initiation**: Generate first run_id when v2.1 starts
3. **Import**: Treat v2.0 state.json as first run's state
4. **Archive**: Keep v2.0 state as backup

**Migration Code**:

```bash
if [[ -f ".fractary/plugins/faber/state.json" && ! -f ".fractary/plugins/faber/gateway.json" ]]; then
  # Legacy v2.0 detected
  echo "Detected legacy FABER v2.0 configuration"
  
  # Initialize v2.1 gateway
  cp templates/gateway.json .fractary/plugins/faber/gateway.json
  
  # Generate first run_id
  run_id=$(generate_run_id)
  
  # Migrate state
  mkdir -p ".fractary/plugins/faber/runs/${run_id}"
  cp ".fractary/plugins/faber/state.json" ".fractary/plugins/faber/runs/${run_id}/state.json"
  
  # Archive v2.0 state
  cp ".fractary/plugins/faber/state.json" ".fractary/plugins/faber/state.json.v2.0.backup"
  
  # Initialize first event
  emit_event "workflow_migrated" "{ \
    source_version: 'v2.0', \
    target_version: 'v2.1', \
    run_id: '$run_id' \
  }"
  
  echo "Migration complete. Run ID: $run_id"
fi
```

### Opt-in for v2.0 Users

New projects use v2.1 by default. Existing v2.0 projects:

1. **Automatic**: First workflow execution auto-triggers migration
2. **Manual**: `faber init --migrate` explicitly triggers
3. **Dual-run**: Can keep v2.0 state.json alongside v2.1 runs (read-only)

---

## Open Questions & Future Work

### Immediate (Q1 2026)

1. **Cluster Coordination**: If FABER runs on distributed agents, how to coordinate run_ids?
   - Proposed: Central run ID service (future)
   - Or: Seed cluster node in config

2. **Event Ordering at Scale**: With parallel steps, how to maintain global ordering?
   - Proposed: Phase-level sequence with per-step sub-sequence
   - Or: Logical clock (Lamport timestamps)

3. **Resume Safety Guarantees**: What if step has side effects?
   - Proposed: Idempotency checks (step declares if idempotent)
   - Or: Automatic side-effect detection via event inspection

### Medium-term (Q2-Q3 2026)

1. **Event Filtering & Privacy**: Some events contain sensitive data
   - Proposed: Field-level encryption for sensitive fields
   - Or: Event classification with redaction rules

2. **Multi-project Aggregation**: View runs across multiple repos in Helm
   - Proposed: Federated event stream backend
   - Or: Central event collection service

3. **Workflow Recommendations**: Learn from event history
   - Proposed: ML model on historical event data
   - Or: Simple pattern detection (phase duration alerts)

### Long-term (Q4 2026+)

1. **Helm Real-time Dashboard**: Full implementation of centralized visibility
   - Proposed: WebSocket event stream + React dashboard
   - Or: WebSub push notifications to subscribers

2. **Event Replay Engine**: Reconstruct workflow state at any point in time
   - Proposed: Time-travel debugging (select timestamp, see state then)
   - Or: Event filtering (view only certain event types)

3. **Workflow Evolution Tracking**: How workflows change over time
   - Proposed: Version run parameters/workflow config
   - Or: Track workflow changes between runs

### Questions Needing Clarification

1. **Retention Policy**: How long to keep local runs before archival?
   - Option A: 7 days (then archive to S3)
   - Option B: 30 days (balance local disk space)
   - Option C: Configurable per org

2. **Resume Limits**: How many resume attempts before forcing re-run?
   - Option A: Unlimited
   - Option B: 5 attempts per step
   - Option C: Time-based (no resume after 7 days)

3. **Privacy**: Can Helm access events for runs on private repos?
   - Option A: Require opt-in per repo
   - Option B: Auto-enable for org repos
   - Option C: Events never leave local machine

---

## Appendix: Reference Implementation

### Run ID Utility

**File**: `plugins/faber/skills/run-manager/scripts/generate-run-id.sh`

```bash
#!/bin/bash
# Generate unique run ID in format: {org}/{project}/{uuid}

set -e

# Detect org and project
ORG="${FABER_ORG:-fractary}"
PROJECT="${FABER_PROJECT:-$(basename "$(git rev-parse --show-toplevel)")}"

# Generate UUID v4
if command -v uuidgen >/dev/null; then
  UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
elif command -v python3 >/dev/null; then
  UUID=$(python3 -c "import uuid; print(str(uuid.uuid4()))")
else
  echo "Error: Neither uuidgen nor python3 found" >&2
  exit 1
fi

# Assemble run_id
RUN_ID="${ORG}/${PROJECT}/${UUID}"

# Validate format
if [[ ! $RUN_ID =~ ^[a-z0-9-]+/[a-z0-9-]+/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]]; then
  echo "Error: Generated invalid run_id format: $RUN_ID" >&2
  exit 1
fi

echo "$RUN_ID"
```

### Event Emission Utility

**File**: `plugins/faber/skills/run-manager/scripts/emit-event.sh`

```bash
#!/bin/bash
# Emit event to MCP gateway

set -e

RUN_ID="$1"
EVENT_TYPE="$2"
EVENT_DATA="$3"

# Construct event
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
EVENT_ID=$(cat ".fractary/plugins/faber/runs/${RUN_ID}/events/.next-id" 2>/dev/null || echo "1")

EVENT_JSON=$(jq -n \
  --arg run_id "$RUN_ID" \
  --arg type "$EVENT_TYPE" \
  --arg timestamp "$TIMESTAMP" \
  --argjson event_id "$EVENT_ID" \
  --arg user "${USER:-system}" \
  --argjson metadata "$EVENT_DATA" \
  '{
    event_id: $event_id,
    type: $type,
    timestamp: $timestamp,
    run_id: $run_id,
    user: $user,
    metadata: $metadata
  }')

# Write to local file
EVENT_FILE=".fractary/plugins/faber/runs/${RUN_ID}/events/$(printf '%03d' $EVENT_ID)-${EVENT_TYPE}.json"
mkdir -p "$(dirname "$EVENT_FILE")"
echo "$EVENT_JSON" > "$EVENT_FILE"

# Update next event ID
echo $((EVENT_ID + 1)) > ".fractary/plugins/faber/runs/${RUN_ID}/events/.next-id"

echo "Event emitted: $EVENT_TYPE (ID: $EVENT_ID)" >&2
```

---

**End of SPEC-00108**

---

## Revision History

| Date | Author | Status | Changes |
|------|--------|--------|---------|
| 2025-12-04 | System Architecture | Draft | Initial specification |

