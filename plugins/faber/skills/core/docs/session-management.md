# Session Management

FABER uses sessions to track workflow state across the 5 phases (Frame → Architect → Build → Evaluate → Release).

## Session Lifecycle

### 1. Creation
Sessions are created when a workflow is initiated via `/fractary-faber:run` or the `faber` command.

```bash
session_json=$(./scripts/session-create.sh abc12345 123 engineering)
```

### 2. Updates
Sessions are updated as each stage progresses:

```bash
./scripts/session-update.sh abc12345 frame completed '{"work_type": "/feature"}'
./scripts/session-update.sh abc12345 architect started
./scripts/session-update.sh abc12345 architect completed '{"spec_file": "docs/specs/feature-123.md"}'
```

### 3. Completion
Sessions are marked complete when the Release stage finishes:

```bash
./scripts/session-update.sh abc12345 release completed '{"pr_url": "https://github.com/..."}'
```

### 4. Cleanup
Sessions are automatically cleaned up based on TTL (default: 168 hours = 1 week):

```toml
[session]
session_ttl_hours = 168
auto_cleanup_sessions = true
```

## Session Structure

```json
{
  "work_id": "abc12345",
  "issue_id": "123",
  "domain": "engineering",
  "project": "my-project",
  "issue_system": "github",
  "autonomy": "guarded",
  "created_at": "2025-01-22T10:00:00Z",
  "updated_at": "2025-01-22T11:30:00Z",
  "status": "active",
  "current_stage": "build",
  "stages": {
    "frame": {
      "status": "completed",
      "updated_at": "2025-01-22T10:05:00Z",
      "data": {
        "work_type": "/feature",
        "title": "Add export feature"
      }
    },
    "architect": {
      "status": "completed",
      "updated_at": "2025-01-22T10:15:00Z",
      "data": {
        "spec_file": "docs/specs/feature-123.md"
      }
    },
    "build": {
      "status": "in_progress",
      "updated_at": "2025-01-22T11:30:00Z",
      "data": {}
    },
    "evaluate": {
      "status": "pending"
    },
    "release": {
      "status": "pending"
    }
  },
  "metadata": {},
  "history": [
    {
      "stage": "initialized",
      "status": "created",
      "timestamp": "2025-01-22T10:00:00Z"
    },
    {
      "stage": "frame",
      "status": "started",
      "timestamp": "2025-01-22T10:01:00Z"
    },
    {
      "stage": "frame",
      "status": "completed",
      "timestamp": "2025-01-22T10:05:00Z",
      "data": {"work_type": "/feature"}
    }
    // ... more history entries
  ]
}
```

## Session Status Values

### Overall Session Status
- `active` - Workflow in progress
- `completed` - All stages completed successfully
- `failed` - One or more stages failed
- `cancelled` - Workflow cancelled by user

### Stage Status
- `pending` - Not yet started
- `started` - Stage has begun
- `in_progress` - Stage is executing
- `completed` - Stage finished successfully
- `failed` - Stage encountered an error

## Session Storage

Sessions are stored as JSON files in the configured session directory:

```
.faber/sessions/
  ├── abc12345.json
  ├── def67890.json
  └── ghi01234.json
```

### Storage Location

Configured in `.faber.config.toml`:

```toml
[session]
session_storage = ".faber/sessions"
```

## Recovery

Sessions can be queried to resume or debug failed workflows:

```bash
# Get session status
session_json=$(./scripts/session-status.sh abc12345)

# Check current stage
current_stage=$(echo "$session_json" | jq -r '.current_stage')

# Check stage statuses
echo "$session_json" | jq '.stages'

# View history
echo "$session_json" | jq '.history'
```

## Retry Logic

The Evaluate → Build retry loop is managed by the `director`. Sessions track retry counts:

```json
{
  "stages": {
    "evaluate": {
      "status": "completed",
      "retry_count": 2,
      "data": {
        "decision": "go",
        "retries_remaining": 1
      }
    }
  }
}
```

Maximum retries configured in `.faber.config.toml`:

```toml
[workflow]
max_evaluate_retries = 3
```

## Idempotency

Sessions use the work_id as an idempotency token:
- Attempting to create a session with an existing work_id fails
- Updates to the same session are idempotent
- Scripts can be safely retried on network failures

## Best Practices

1. **Always create sessions at workflow start**
2. **Update sessions after each major operation**
3. **Include relevant data in stage updates**
4. **Check session status before resuming workflows**
5. **Clean up old sessions periodically**
6. **Never manually edit session files**
