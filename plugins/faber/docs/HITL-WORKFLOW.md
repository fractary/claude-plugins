# FABER Human-in-the-Loop (HITL) Workflow Guide

Complete guide to human-in-the-loop feedback collection and workflow resumption in FABER.

## Overview

FABER supports human-in-the-loop (HITL) feedback at any point in the workflow. This enables:

1. **Decision Gates**: Pause workflow for user approval before critical actions
2. **Error Resolution**: Allow user to decide how to handle failures
3. **Clarification**: Request additional information when ambiguous
4. **Review**: Present artifacts for user review before proceeding

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         FABER Workflow                               │
│                                                                      │
│  ┌─────────┐    ┌───────────┐    ┌───────┐    ┌──────────┐    ┌────┐│
│  │  Frame  │───▶│ Architect │───▶│ Build │───▶│ Evaluate │───▶│Rel.││
│  └─────────┘    └─────┬─────┘    └───────┘    └────┬─────┘    └────┘│
│                       │                            │                 │
│                  [Decision]                   [Error?]               │
│                   Point                        Retry?                │
│                       │                            │                 │
└───────────────────────┼────────────────────────────┼─────────────────┘
                        │                            │
                        ▼                            ▼
              ┌──────────────────────────────────────────────────┐
              │              Feedback Handler                     │
              │  - Emit decision_point event                      │
              │  - Update state to awaiting_feedback              │
              │  - Post to issue (if work_id present)             │
              │  - Present CLI prompt                             │
              └───────────────────────┬──────────────────────────┘
                                      │
                                      ▼
              ┌──────────────────────────────────────────────────┐
              │           User Feedback Channels                  │
              │                                                   │
              │  ┌────────────┐    ┌────────────────────────┐    │
              │  │    CLI     │    │    Issue Comment       │    │
              │  │  (inline)  │    │  (async, @faber)       │    │
              │  └────────────┘    └────────────────────────┘    │
              └───────────────────────┬──────────────────────────┘
                                      │
                                      ▼
              ┌──────────────────────────────────────────────────┐
              │              Feedback Resume                      │
              │  - Emit feedback_received event                   │
              │  - Update state to in_progress                    │
              │  - Re-invoke faber-manager                        │
              │  - Continue from resume point                     │
              └──────────────────────────────────────────────────┘
```

## Feedback Types

| Type | Description | Options | Use Case |
|------|-------------|---------|----------|
| `approval` | Binary yes/no decision | `approve`, `reject` | Gate before release |
| `confirmation` | Confirm action | `confirm`, `cancel` | Destructive operations |
| `selection` | Choose from list | Custom | Select approach |
| `clarification` | Request info | Free text | Ambiguous requirements |
| `review` | Review with changes | `approve`, `request_changes`, `reject` | Spec/PR review |
| `error_resolution` | Handle failure | `retry`, `skip`, `abort` | Error recovery |

## Feedback Collection

### CLI Inline Prompt

When running in CLI, feedback is collected inline:

```
🎯 FABER: Feedback Required
───────────────────────────────────────

Phase: Architect → design-review
Type: Approval

Please review the architectural design and approve to proceed.

**Summary**: 3-layer architecture with handler pattern
**Artifact**: specs/WORK-00258-design.md

Options:
  1. approve - Continue to Build phase
  2. request_changes - Provide feedback for revision
  3. reject - Cancel this workflow

Your choice: _
```

### Issue Comment

When feedback is needed asynchronously, a comment is posted to the issue:

```markdown
## Feedback Requested

**Workflow Run**: `fractary/claude-plugins/abc-123-...`
**Phase**: Architect
**Step**: design-review
**Requested**: 2025-12-06 18:00 UTC

### Decision Needed

Please review the architectural design and approve to proceed.

**Summary**:
3-layer architecture with handler pattern

**Artifact**: [WORK-00258-design.md](/specs/WORK-00258-design.md)

### Options

1. **approve** - Continue to Build phase
2. **request_changes** - Provide feedback for revision
3. **reject** - Cancel this workflow run

### How to Respond

Reply to this issue with your decision. Include `@faber resume` in your comment to trigger workflow continuation.

**Example response:**
```
I approve this design. The approach looks good.

@faber resume
```

---
_This feedback request will remain open until addressed._
_Run ID: `abc-123-...` | Request ID: `fr-20251206-a1b2c3`_
```

## Context Reconstitution

Every time a workflow resumes (new session, after feedback, etc.), context is reconstituted:

### Protocol (Step 0)

1. **Load Run State** - Read `state.json` and `metadata.json`
2. **Load Specification** - Re-read spec file into context
3. **Load Issue Details** - Fetch issue title, description, comments
4. **Inspect Branch State** - Check recent commits on branch
5. **Review Recent Events** - Load last 20 events from event log
6. **Check for Pending Feedback** - If `awaiting_feedback`, process feedback first
7. **Determine Resume Point** - Identify where to continue

### Why Always Reconstitute?

Sessions are treated as ephemeral. We never assume prior context exists because:
- User may resume in a new terminal
- Session may have been summarized
- User may resume from a different machine
- Cross-environment workflows (issue → CLI)

## Feedback Resume

After user provides feedback, the faber-manager must resume correctly:

### Resume Protocol

1. **Validate Feedback** - Ensure response matches expected options
2. **Log Event** - Emit `feedback_received` event
3. **Update State** - Clear `feedback_request`, add to `feedback_history`
4. **Emit Approval** - If approval type, emit `approval_granted`
5. **Process Action** - Determine next action based on response
6. **Re-invoke Manager** - Explicitly re-invoke faber-manager

### Actions

| Response | Action | Effect |
|----------|--------|--------|
| `approve` | `continue` | Proceed to next step |
| `reject` | `abort` | Cancel workflow |
| `request_changes` | `revise` | Re-execute step with feedback |
| `retry` | `retry` | Re-execute failed step |
| `skip` | `skip` | Mark step skipped, proceed |
| `abort` | `abort` | Cancel workflow |

### Divergence Prevention

**CRITICAL**: After feedback, faber-manager must continue the planned workflow. It must NOT:
- Improvise new steps
- Deviate from workflow definition
- Suggest alternatives
- Ask clarifying questions (unless at another decision point)

The resume instruction explicitly states:
```
Resume workflow run {run_id} from step {phase}:{step}.
User feedback received: {feedback}.
Continue executing workflow steps. Follow workflow definition.
Do NOT diverge from the planned workflow.
```

## Parallel Run Coordination

When multiple FABER runs execute simultaneously:

### Flow

1. **Track Runs** - Coordinator maintains list of all run IDs
2. **Wait for Stops** - Monitor until all runs reach a stop state
3. **Aggregate** - Collect all pending feedback requests
4. **Present** - Show single aggregated prompt to user
5. **Parse** - Extract responses for each run
6. **Distribute** - Route feedback to individual runs
7. **Resume** - Trigger resume for each run

### Aggregated Prompt

```
## Parallel Workflow Status

5 workflow runs completed initial execution:
- 2 completed successfully
- 2 awaiting feedback (see below)
- 1 failed with error (see below)

### Feedback Needed

**Run #124** (feat/124-add-csv-export):
- Type: Approval
- Question: Approve design for CSV export feature?
- Options: [1] approve [2] request_changes [3] reject

**Run #125** (fix/125-auth-bug):
- Type: Error Resolution
- Error: Tests failed (3 failures)
- Options: [1] retry [2] skip [3] abort

### Provide Feedback

Example format:
#124: approve
#125: retry
```

## State Management

### Run State Fields

```json
{
  "status": "awaiting_feedback",
  "feedback_request": {
    "request_id": "fr-20251206-a1b2c3",
    "type": "approval",
    "prompt": "Please review...",
    "options": ["approve", "reject", "request_changes"],
    "context": { ... },
    "requested_at": "2025-12-06T18:00:00Z",
    "notification_sent": {
      "cli": true,
      "issue_comment": true,
      "comment_url": "https://..."
    }
  },
  "resume_point": {
    "phase": "architect",
    "step": "design-review",
    "step_index": 2
  },
  "feedback_history": [ ... ]
}
```

### Status Values

| Status | Description |
|--------|-------------|
| `pending` | Run created, not started |
| `in_progress` | Actively executing |
| `awaiting_feedback` | Paused for user input |
| `completed` | Finished successfully |
| `failed` | Failed with error |
| `cancelled` | Cancelled by user |

## Event Types

### feedback_request

Emitted when feedback is needed:

```json
{
  "event_id": 15,
  "type": "feedback_request",
  "timestamp": "2025-12-06T18:00:00Z",
  "run_id": "org/project/uuid",
  "phase": "architect",
  "step": "design-review",
  "message": "Awaiting feedback: Please review the design",
  "metadata": {
    "request_id": "fr-20251206-a1b2c3",
    "type": "approval",
    "options": ["approve", "reject", "request_changes"]
  }
}
```

### feedback_received

Emitted when user responds:

```json
{
  "event_id": 16,
  "type": "feedback_received",
  "timestamp": "2025-12-06T18:15:00Z",
  "run_id": "org/project/uuid",
  "phase": "architect",
  "step": "design-review",
  "message": "Feedback received: approve",
  "metadata": {
    "request_id": "fr-20251206-a1b2c3",
    "response": "approve",
    "provided_by": {
      "user": "jmcwilliam",
      "source": "cli"
    }
  }
}
```

## Scripts Reference

### feedback-handler/scripts/

| Script | Purpose |
|--------|---------|
| `generate-request-id.sh` | Generate unique feedback request ID |
| `format-feedback-comment.sh` | Format feedback as markdown comment |
| `update-feedback-state.sh` | Update state with feedback details |
| `get-user-identity.sh` | Get user identity for attribution |

### run-manager/scripts/

| Script | Purpose |
|--------|---------|
| `emit-event.sh` | Emit workflow events (including feedback events) |
| `aggregate-runs.sh` | Aggregate status of multiple runs |

## Configuration

Feedback behavior is configured per-workflow:

```json
{
  "autonomy": {
    "level": "guarded",
    "require_approval_for": ["release"]
  },
  "phases": {
    "architect": {
      "steps": [
        {
          "name": "design-review",
          "requires_approval": true,
          "approval_type": "review"
        }
      ]
    }
  }
}
```

## Future: @faber Integration

The `@faber` trigger in issue comments is planned for future implementation:

```markdown
## Commands

- `@faber resume` - Resume workflow with preceding comment as feedback
- `@faber resume --run {id}` - Resume specific run
- `@faber status` - Post current status as comment
- `@faber cancel` - Cancel pending request

## Trigger Options

1. GitHub webhook on `issue_comment` event
2. GitHub Action triggered on @faber mention
3. Polling mechanism checking for new comments
```

## Troubleshooting

### Workflow Not Resuming

1. Check run state: `jq '.status' .fractary/plugins/faber/runs/{run_id}/state.json`
2. Verify `awaiting_feedback` status
3. Check `feedback_request` object exists
4. Ensure response matches expected options

### Feedback Not Captured

1. Check event log for `feedback_received` event
2. Verify `feedback_history` array in state
3. Check `provided_by` attribution

### Issue Comment Not Posted

1. Verify `work_id` is present in run
2. Check work plugin configuration
3. Verify GitHub token has comment permissions
4. Check `notification_sent.issue_comment` in state

## See Also

- [STATE-TRACKING.md](./STATE-TRACKING.md) - Dual-state tracking with feedback fields
- [RUN-ID-SYSTEM.md](./RUN-ID-SYSTEM.md) - Run isolation and event logging
- [AUTONOMY.md](./AUTONOMY.md) - Autonomy levels and approval gates
- `skills/feedback-handler/SKILL.md` - Feedback handler skill documentation
- [context-reconstitution.md](./standards/manager-protocols/context-reconstitution.md) - Context loading protocol
- [feedback-resume.md](./standards/manager-protocols/feedback-resume.md) - Resume protocol
- [parallel-coordination.md](./standards/manager-protocols/parallel-coordination.md) - Multi-run coordination
