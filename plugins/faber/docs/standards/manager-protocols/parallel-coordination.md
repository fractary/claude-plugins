# Workflow: Parallel Run Coordination

This workflow defines how to coordinate multiple FABER runs executing in parallel, aggregating their feedback requests for efficient user interaction.

## Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| Coordinator State Schema | ✅ Implemented | JSON structure defined |
| Run State Tracking | ✅ Implemented | Via aggregate-runs.sh script |
| Aggregation Logic | ✅ Implemented | aggregate-runs.sh with JSON/markdown output |
| Aggregated Prompt Format | ✅ Implemented | Markdown format defined |
| Response Parsing | 📋 Documented | Pseudocode in protocol, needs real implementation |
| Response Distribution | 📋 Documented | Uses feedback-handler scripts |
| Run Resume | 📋 Documented | Uses faber-manager Task invocation |
| Coordinator Storage | 📋 Documented | Directory structure specified |

**Legend**: ✅ Implemented and tested | 📋 Documented/Designed (follow protocol)

## Overview

**Purpose**: When multiple workflow runs are active, aggregate feedback requests and distribute responses to enable efficient user interaction.

**Use Case**: User invokes FABER on multiple work items simultaneously (e.g., `/faber run 123,124,125`).

## Pre-Conditions

Before executing this protocol:
1. Multiple faber-manager instances are running in parallel (via Task agents or worktrees)
2. Each run has its own run_id and isolated state
3. Director/coordinator has list of all active run_ids

## Parallel Run States

Each run can be in one of these "stop" states:

| State | Description | Requires Feedback |
|-------|-------------|-------------------|
| `completed` | Workflow finished successfully | No |
| `awaiting_feedback` | Paused, waiting for user input | Yes |
| `error` | Failed, needs error_resolution decision | Yes |
| `cancelled` | User cancelled the run | No |

## Coordination Protocol

### Step 1: Track Active Runs

When starting parallel runs, maintain a coordinator state:

```json
{
  "coordinator_id": "coord-20251206-abc123",
  "started_at": "2025-12-06T18:00:00Z",
  "total_runs": 5,
  "runs": [
    {"run_id": "org/project/uuid-1", "work_id": "123", "status": "in_progress"},
    {"run_id": "org/project/uuid-2", "work_id": "124", "status": "in_progress"},
    {"run_id": "org/project/uuid-3", "work_id": "125", "status": "in_progress"},
    {"run_id": "org/project/uuid-4", "work_id": "126", "status": "in_progress"},
    {"run_id": "org/project/uuid-5", "work_id": "127", "status": "in_progress"}
  ]
}
```

### Step 2: Wait for Stop Points

Monitor all runs until each reaches a stop state:

```bash
# Poll each run's state
FOR each run IN coordinator.runs:
    state = read ".fractary/plugins/faber/runs/{run.run_id}/state.json"
    run.status = state.status
    run.last_checked = now()

    IF state.status IN ["completed", "awaiting_feedback", "error", "cancelled"]:
        run.stopped = true
        run.stop_details = extract_stop_details(state)

# Continue polling until all stopped
WHILE NOT all_runs_stopped(coordinator.runs):
    sleep(5 seconds)  # Polling interval
    refresh_run_states()
```

### Step 3: Aggregate Results

When all runs have stopped, build aggregation report:

```json
{
  "coordinator_id": "coord-20251206-abc123",
  "aggregated_at": "2025-12-06T18:30:00Z",
  "summary": {
    "total_runs": 5,
    "completed": 2,
    "awaiting_feedback": 2,
    "error": 1,
    "cancelled": 0
  },
  "runs": [
    {
      "run_id": "org/project/uuid-1",
      "work_id": "123",
      "status": "completed",
      "outcome": "success",
      "artifacts": {"pr_url": "https://github.com/..."}
    },
    {
      "run_id": "org/project/uuid-2",
      "work_id": "124",
      "status": "awaiting_feedback",
      "feedback_request": {
        "request_id": "fr-20251206-abc123",
        "type": "approval",
        "prompt": "Approve design for CSV export feature?",
        "options": ["approve", "request_changes", "reject"],
        "phase": "architect",
        "step": "design-review"
      }
    },
    {
      "run_id": "org/project/uuid-3",
      "work_id": "125",
      "status": "awaiting_feedback",
      "feedback_request": {
        "request_id": "fr-20251206-def456",
        "type": "error_resolution",
        "prompt": "Tests failed (3 failures). How to proceed?",
        "options": ["retry", "skip", "abort"],
        "phase": "evaluate",
        "step": "test"
      }
    },
    {
      "run_id": "org/project/uuid-4",
      "work_id": "126",
      "status": "error",
      "error": {
        "phase": "build",
        "step": "implement",
        "message": "Build compilation error in dashboard.ts",
        "retryable": true
      }
    },
    {
      "run_id": "org/project/uuid-5",
      "work_id": "127",
      "status": "completed",
      "outcome": "success",
      "artifacts": {"pr_url": "https://github.com/..."}
    }
  ]
}
```

### Step 4: Present Aggregated Prompt

Format the aggregation for user interaction:

```markdown
## Parallel Workflow Status

5 workflow runs completed initial execution:
- **2 completed** successfully
- **2 awaiting feedback** (see below)
- **1 failed** with error (see below)

---

### Completed Runs

| Work ID | Branch | Status | PR |
|---------|--------|--------|-----|
| #123 | feat/123-feature | Completed | [PR #45](https://...) |
| #127 | fix/127-bugfix | Completed | [PR #46](https://...) |

---

### Feedback Needed

**Run #124** (feat/124-add-csv-export):
- Phase: Architect → design-review
- Type: Approval
- Question: Approve design for CSV export feature?
- Options:
  1. **approve** - Continue to Build phase
  2. **request_changes** - Provide feedback for revision
  3. **reject** - Cancel this run

**Run #125** (fix/125-auth-bug):
- Phase: Evaluate → test
- Type: Error Resolution
- Error: Tests failed (3 failures)
- Options:
  1. **retry** - Run tests again
  2. **skip** - Skip tests and continue
  3. **abort** - Cancel this run

---

### Failed Runs

**Run #126** (feat/126-dashboard):
- Phase: Build → implement
- Error: Build compilation error in dashboard.ts
- Options:
  1. **retry** - Retry the failed step
  2. **abort** - Cancel this run

---

### Provide Feedback

Please specify your decisions:

Example format:
```
#124: approve
#125: retry
#126: abort
```
```

### Step 5: Parse User Responses

Extract feedback from user response:

```bash
# Parse response format: "#<work_id>: <response>"
# Also accept: "<work_id>: <response>" or "Run #<work_id>: <response>"

RESPONSE_PATTERN = /^#?(?:Run\s*#?)?(\d+):\s*(\w+)/gmi

FOR each match IN parse_responses(user_input):
    work_id = match.group(1)
    response = match.group(2).lower()

    # Find corresponding run
    run = find_run_by_work_id(coordinator.runs, work_id)

    IF run is null:
        WARNING: "Unknown work ID: #{work_id}"
        CONTINUE

    IF run.status NOT IN ["awaiting_feedback", "error"]:
        WARNING: "Run #{work_id} not awaiting feedback (status: {run.status})"
        CONTINUE

    # Validate response against options
    valid_options = get_valid_options(run)
    IF response NOT IN valid_options:
        ERROR: "Invalid response '{response}' for #{work_id}. Valid: {valid_options}"
        # Re-prompt for this run
        CONTINUE

    # Store parsed response
    run.feedback_response = {
        response: response,
        provided_by: get_current_user(),
        source: "cli",
        parsed_at: now()
    }
```

### Step 6: Distribute Responses to Runs

For each run with feedback, update state and trigger resume:

```bash
FOR each run IN coordinator.runs WHERE run.feedback_response EXISTS:

    # 1. Emit feedback_received event
    Bash: plugins/faber/skills/run-manager/scripts/emit-event.sh \
        --run-id "{run.run_id}" \
        --type "feedback_received" \
        --phase "{run.feedback_request.phase}" \
        --step "{run.feedback_request.step}" \
        --message "Feedback received via parallel coordination: {run.feedback_response.response}" \
        --metadata '{
            "coordinator_id": "{coordinator.coordinator_id}",
            "request_id": "{run.feedback_request.request_id}",
            "response": "{run.feedback_response.response}",
            "provided_by": "{run.feedback_response.provided_by}",
            "source": "parallel_coordination"
        }'

    # 2. Update run state
    Bash: plugins/faber/skills/feedback-handler/scripts/update-feedback-state.sh \
        --run-id "{run.run_id}" \
        --operation add-history \
        --request-id "{run.feedback_request.request_id}" \
        --type "{run.feedback_request.type}" \
        --response "{run.feedback_response.response}" \
        --user "{run.feedback_response.provided_by}" \
        --source "parallel_coordination"

    # 3. Clear awaiting status
    Bash: plugins/faber/skills/feedback-handler/scripts/update-feedback-state.sh \
        --run-id "{run.run_id}" \
        --operation clear-awaiting \
        --phase "{run.feedback_request.phase}" \
        --step "{run.feedback_request.step}"

    # 4. Queue for resume
    add_to_resume_queue(run.run_id, run.feedback_response.response)
```

### Step 7: Resume Individual Runs

Resume each run that received feedback:

```bash
FOR each run IN resume_queue:
    LOG "Resuming run {run.run_id} with action: {run.action}"

    # Spawn faber-manager to resume this run
    Task:
        subagent_type: "fractary-faber:faber-manager"
        prompt: |
            Resume workflow run {run.run_id}.

            User feedback: {run.action}
            Resume from: {run.phase}:{run.step}

            Continue executing workflow steps. Follow workflow definition.
            Do NOT diverge from the planned workflow.
        run_in_background: true

    run.resume_agent_id = task_result.agent_id
```

### Step 8: Monitor Resumed Runs

Optionally, continue monitoring until all runs complete:

```bash
# Loop until all pending runs are resolved
WHILE has_pending_runs(coordinator.runs):

    FOR each run IN coordinator.runs WHERE run.status == "in_progress":
        state = read_run_state(run.run_id)
        run.status = state.status

        IF state.status IN ["completed", "awaiting_feedback", "error"]:
            IF state.status == "completed":
                LOG "✓ Run {run.work_id} completed"
            ELIF state.status == "awaiting_feedback":
                # New feedback needed - add to next aggregation cycle
                LOG "! Run {run.work_id} needs additional feedback"
                run.feedback_request = state.feedback_request
            ELIF state.status == "error":
                LOG "✗ Run {run.work_id} failed"

    # If any new feedback needed, aggregate and prompt again
    IF has_awaiting_feedback(coordinator.runs):
        GOTO Step 4: Present Aggregated Prompt

    sleep(10 seconds)
```

## Coordinator State Storage

The coordinator state is stored at:
```
.fractary/plugins/faber/coordinators/{coordinator_id}/
├── state.json          # Coordinator state
├── runs.json           # All run details
└── aggregations/       # Historical aggregation reports
    ├── 001-initial.json
    └── 002-resumed.json
```

## Error Handling

| Error | Action |
|-------|--------|
| Run state not readable | Mark run as `unknown`, continue with others |
| Invalid response format | Re-prompt with format example |
| Response for unknown run | Warn, skip, continue |
| Run failed to resume | Log error, mark as `resume_failed` |
| Timeout waiting for runs | Prompt user to continue waiting or abort |

## Integration with Faber-Manager

The coordinator delegates all workflow execution to faber-manager. It only:
1. Tracks run states
2. Aggregates feedback requests
3. Parses user responses
4. Distributes feedback to individual runs
5. Triggers resume for each run

The faber-manager handles:
- Workflow step execution
- Context reconstitution
- Feedback handling within a single run
- Event emission

## See Also

- [context-reconstitution.md](./context-reconstitution.md) - Context loading protocol
- [feedback-resume.md](./feedback-resume.md) - Resume after feedback
- [RUN-ID-SYSTEM.md](../../RUN-ID-SYSTEM.md) - Run isolation
- [feedback-handler SKILL.md](../../../skills/feedback-handler/SKILL.md) - Feedback handling
