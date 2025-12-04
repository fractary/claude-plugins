# FABER Event Gateway MCP Server

An MCP (Model Context Protocol) server that provides workflow event logging capabilities for the FABER workflow framework. This server enables structured event logging, run management, and event consolidation for FABER workflow executions.

## Features

- **Event Emission**: Log workflow events with rich metadata, artifacts, and error tracking
- **Run Management**: Create, query, and manage workflow runs with full state tracking
- **Event Consolidation**: Export events to JSONL format for archival or analysis
- **Resource Access**: Browse runs and events via MCP resources
- **Concurrent-Safe**: Atomic operations prevent race conditions in event ID generation

## Prerequisites

- Node.js >= 18.0.0
- npm or yarn

## Installation

```bash
cd plugins/faber/mcp-server
npm install
npm run build
```

## Configuration

The server uses environment variables for configuration:

| Variable | Default | Description |
|----------|---------|-------------|
| `FABER_RUNS_PATH` | `.fractary/plugins/faber/runs` | Base path for run storage |

## Usage

### Starting the Server

```bash
# Production (requires build)
npm start

# Development (with tsx)
npm run dev
```

The server communicates via stdio, making it suitable for integration with MCP clients.

### MCP Client Configuration

Add to your MCP client configuration (e.g., `~/.config/claude/mcp.json`):

```json
{
  "mcpServers": {
    "faber-event-gateway": {
      "command": "node",
      "args": ["/path/to/plugins/faber/mcp-server/dist/server.js"],
      "env": {
        "FABER_RUNS_PATH": ".fractary/plugins/faber/runs"
      }
    }
  }
}
```

## Tools

### emit_event

Emit a workflow event to a FABER run.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `run_id` | string | Yes | Full run identifier (org/project/uuid) |
| `type` | string | Yes | Event type (see Event Types below) |
| `phase` | string | No | Current workflow phase |
| `step` | string | No | Current step within phase |
| `status` | string | No | Event status (started, completed, failed, skipped) |
| `message` | string | No | Human-readable description |
| `metadata` | object | No | Event-specific metadata |
| `artifacts` | array | No | Artifacts created or modified |
| `duration_ms` | number | No | Duration in milliseconds |
| `error` | object | No | Error information with code and message |

**Example:**
```json
{
  "run_id": "fractary/claude-plugins/a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "type": "phase_start",
  "phase": "build",
  "status": "started",
  "message": "Starting build phase"
}
```

### get_run

Get run state and metadata.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `run_id` | string | Yes | Full run identifier |
| `include_events` | boolean | No | Include event count (default: false) |

### list_runs

List runs with optional filters.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `work_id` | string | No | Filter by work item ID |
| `status` | string | No | Filter by status |
| `org` | string | No | Filter by organization |
| `project` | string | No | Filter by project |
| `limit` | number | No | Maximum results (default: 20) |

### consolidate_events

Consolidate run events to JSONL format for archival.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| `run_id` | string | Yes | Run to consolidate |

## Resources

The server exposes runs and events as MCP resources:

| URI | Description |
|-----|-------------|
| `faber://runs` | List all workflow runs |
| `faber://runs/{run_id}` | Get specific run details |
| `faber://runs/{run_id}/events` | Get events for a run |

## Event Types

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
- `decision_point` - User decision required
- `retry_loop_enter` - Entering retry loop
- `retry_loop_exit` - Exiting retry loop
- `approval_request` - Approval requested
- `approval_granted` - Approval granted
- `approval_denied` - Approval denied
- `hook_execute` - Hook executed

## Directory Structure

Each run creates an isolated directory:

```
.fractary/plugins/faber/runs/
└── {org}/
    └── {project}/
        └── {uuid}/
            ├── state.json        # Current workflow state
            ├── metadata.json     # Run metadata
            ├── events.jsonl      # Consolidated events (after consolidation)
            └── events/
                ├── .next-id      # Sequence counter
                ├── 001-workflow_start.json
                ├── 002-phase_start.json
                └── ...
```

## Development

```bash
# Watch mode
npm run watch

# Run tests
npm test

# Run tests in watch mode
npm run test:watch

# Clean build artifacts
npm run clean
```

## Security Considerations

- **Path Traversal Protection**: Run IDs are validated to prevent directory traversal attacks
- **Atomic Operations**: Event ID generation uses atomic file rename to prevent race conditions
- **Input Validation**: All inputs are validated against JSON schemas

## Error Handling

The server distinguishes between recoverable and critical errors:

- **Exit Code 0**: Success
- **Exit Code 1**: Validation or input error (recoverable)
- **Exit Code 2**: State update failure (critical - requires intervention)

When state updates fail, the event is still written but the run state may be inconsistent. These cases require manual investigation.

## See Also

- [RUN-ID-SYSTEM.md](../docs/RUN-ID-SYSTEM.md) - Complete Run ID system documentation
- [SPEC-00108](../../specs/SPEC-00108-faber-run-id-event-logging.md) - Technical specification
