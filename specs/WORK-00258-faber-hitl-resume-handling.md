---
spec_id: WORK-00258-faber-hitl-resume-handling
work_id: 258
issue_url: https://github.com/fractary/claude-plugins/issues/258
title: Better faber workflow HITL / resume handling via issue/work management
type: feature
status: implemented
created: 2025-12-06
updated: 2025-12-06
author: jmcwilliam
validated: false
source: conversation+issue
---

# Feature Specification: FABER Workflow HITL and Resume Handling

**Issue**: [#258](https://github.com/fractary/claude-plugins/issues/258)
**Type**: Feature
**Status**: Draft
**Created**: 2025-12-06
**Updated**: 2025-12-06

## Summary

Enhance the FABER workflow framework to improve human-in-the-loop (HITL) feedback collection and workflow resumption. This extends the existing autonomy model by:

1. Improving how feedback is solicited (CLI inline prompts AND issue comments)
2. Ensuring the faber-manager agent properly resumes workflow execution after feedback
3. Supporting context reconstitution across session restarts
4. Planning for future `@faber` trigger integration in issue comments

**Scope Clarification**: This issue does NOT modify the autonomy model itself. It extends how users can respond to feedback requests and ensures proper workflow continuation.

## Problem Statement

Currently, when FABER workflows require human feedback:

1. **CLI Context**: Feedback prompts work, but after response the faber-manager may not properly re-engage to continue the workflow - Claude may diverge into freeform operation
2. **Issue Context**: No mechanism exists to post feedback requests to issue comments and collect responses there
3. **Session Continuity**: When a new Claude session resumes a workflow, insufficient context is loaded to continue effectively
4. **Parallel Runs**: When multiple workflow runs are active, feedback coordination across runs is undefined

## Existing Infrastructure (Leverage, Don't Replace)

### Run ID System (Already Implemented)
Per-run isolation exists at:
```
.fractary/plugins/faber/runs/{org}/{project}/{uuid}/
├── state.json        # Per-run workflow state
├── metadata.json     # Run metadata
└── events/           # Event log
    ├── 001-workflow_start.json
    ├── 002-phase_start.json
    └── ...
```

### Existing Event Types
The run-manager already supports these relevant events:
- `decision_point` - User decision required
- `approval_requested` - Waiting for user approval
- `approval_granted` - User approved continuation
- `workflow_resumed` - Workflow resumed from previous run

### Autonomy Model (Extend, Don't Modify)
The existing check-in system (`per-step`, `per-phase`, `end-only`) and tolerance thresholds remain unchanged. This spec adds:
- Better feedback solicitation channels
- Guaranteed faber-manager re-engagement after feedback
- Context reconstitution for cross-session resume

## User Stories

### US1: CLI Workflow Resume with Faber-Manager Re-engagement
**As a** developer using FABER via CLI
**I want** the faber-manager to properly take back control after I provide feedback
**So that** the workflow continues its planned path without Claude diverging into freeform operation

**Acceptance Criteria**:
- [ ] Workflow pauses at feedback points with clear indication of what's needed
- [ ] User feedback is captured and associated with the requesting step
- [ ] Faber-manager agent is explicitly re-invoked after feedback
- [ ] Workflow resumes from the exact step that requested feedback
- [ ] Workflow does not diverge into freeform operation after feedback

### US2: Issue-Based Feedback Collection
**As a** developer managing work via GitHub Issues
**I want** FABER to post feedback requests as issue comments
**So that** I can review and respond asynchronously through my issue tracker

**Acceptance Criteria**:
- [ ] FABER posts a formatted comment when feedback is needed
- [ ] Comment includes context about what decision is needed and why
- [ ] Comment includes example command to resume workflow
- [ ] Feedback request is tracked in run state as pending

### US3: Context Reconstitution on Resume
**As a** developer resuming a workflow in a new Claude session
**I want** FABER to automatically load necessary context
**So that** the resumed workflow has sufficient understanding to continue effectively

**Acceptance Criteria**:
- [ ] On resume, spec file is re-read into context
- [ ] Issue details are re-fetched
- [ ] Recent commits on the branch are inspected
- [ ] Run state and events are loaded
- [ ] Workflow continues from correct step with full context

### US4: Parallel Run Feedback Coordination
**As a** developer running multiple FABER workflows in parallel
**I want** feedback to be aggregated and distributed correctly
**So that** I can provide feedback for all runs efficiently

**Acceptance Criteria**:
- [ ] Director waits for all parallel manager runs to reach a stop point
- [ ] All pending feedback requests are aggregated into single report
- [ ] User can respond to all feedback in one interaction
- [ ] Responses are routed to correct individual runs for resume

## Functional Requirements

- **FR1**: Faber-manager must be explicitly re-invoked after user provides feedback (no freeform divergence)
- **FR2**: Feedback requests must be postable as GitHub issue comments via work plugin
- **FR3**: Issue comments must include structured feedback request with context and example commands
- **FR4**: Run state must track `awaiting_feedback` status with request details
- **FR5**: Resume must load: spec, issue details, branch commits, run state, events
- **FR6**: `decision_point` events must include sufficient metadata for context reconstruction
- **FR7**: Parallel runs must aggregate feedback requests before prompting user
- **FR8**: Director must coordinate resume of multiple runs after feedback received
- **FR9**: Feedback responses must be logged with attribution (user, source, timestamp)
- **FR10**: Session design assumes ephemeral - always reconstitute context on resume

## Non-Functional Requirements

- **NFR1**: Context reconstitution must complete within 10 seconds
- **NFR2**: Run state must persist across Claude session restarts
- **NFR3**: Feedback requests must remain valid indefinitely (no auto-timeout for now)
- **NFR4**: System must handle 10+ parallel runs with independent feedback tracking

## Technical Design

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                       FABER Director                                 │
│  (Coordinates multiple parallel manager runs)                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐      │
│  │ Faber Manager   │  │ Faber Manager   │  │ Faber Manager   │      │
│  │ Run: abc-123    │  │ Run: def-456    │  │ Run: ghi-789    │      │
│  │ Status: running │  │ Status: await   │  │ Status: complete│      │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘      │
│           │                    │                    │                │
│           ▼                    ▼                    ▼                │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              Feedback Aggregation Layer                       │   │
│  │  - Collects all pending feedback requests                     │   │
│  │  - Waits for all runs to reach stop point                     │   │
│  │  - Aggregates into single user prompt                         │   │
│  │  - Routes responses to individual runs                        │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              │                                       │
└──────────────────────────────│───────────────────────────────────────┘
                               │
          ┌────────────────────┼────────────────────┐
          ▼                    ▼                    ▼
   ┌────────────┐       ┌────────────┐       ┌────────────────┐
   │    CLI     │       │   Issue    │       │  Future:       │
   │  Inline    │       │  Comment   │       │  Slack/Email   │
   │  Prompt    │       │  (async)   │       │  Notification  │
   └────────────┘       └────────────┘       └────────────────┘
```

### Faber-Manager Re-engagement Protocol

**Problem**: After user provides feedback, Claude may diverge instead of faber-manager resuming workflow.

**Solution**: Explicit re-invocation pattern with context injection.

```markdown
## After Feedback Received

1. Log feedback received event
2. Store feedback in run state
3. **CRITICAL**: Re-invoke faber-manager with explicit instruction:

   "Resume workflow run {run_id} from step {phase}:{step}.
   User feedback received: {feedback_summary}
   Continue executing workflow steps. Do not diverge from workflow."

4. Faber-manager loads run state
5. Faber-manager continues from exact step
6. If workflow complete, emit workflow_complete event
```

**Implementation in faber-manager.md**:
```markdown
## Resuming After Feedback

When resuming after a decision_point:
1. Load run state from .fractary/plugins/faber/runs/{run_id}/state.json
2. Verify status is "awaiting_feedback" with matching request_id
3. Update status to "in_progress"
4. Emit "approval_granted" event with feedback details
5. Continue from resume_point.phase:resume_point.step
6. Execute remaining workflow steps

CRITICAL: Do NOT improvise or deviate. Follow workflow definition.
```

### Run State Extension for Feedback

Extend per-run `state.json` to track pending feedback:

```json
{
  "run_id": "fractary/claude-plugins/abc-123-...",
  "work_id": "258",
  "status": "awaiting_feedback",
  "current_phase": "architect",
  "current_step": "design-review",
  "feedback_request": {
    "request_id": "fr-20251206-001",
    "type": "approval",
    "prompt": "Please review the architectural design and approve to proceed.",
    "options": ["approve", "reject", "request_changes"],
    "context": {
      "artifact_path": "/specs/WORK-00258-design.md",
      "summary": "Design proposes 3-layer architecture with handler pattern"
    },
    "requested_at": "2025-12-06T18:00:00Z",
    "notification_sent": {
      "cli": false,
      "issue_comment": true,
      "comment_url": "https://github.com/fractary/claude-plugins/issues/258#issuecomment-xyz"
    }
  },
  "resume_point": {
    "phase": "architect",
    "step": "design-review",
    "step_index": 2
  }
}
```

### Feedback Types Taxonomy

| Type | Description | Options | Use Case |
|------|-------------|---------|----------|
| `approval` | Binary approval decision | approve, reject | Gate before release phase |
| `confirmation` | Confirm an action | confirm, cancel | Destructive operations |
| `selection` | Choose from options | [custom list] | Select implementation approach |
| `clarification` | Request more info | [free text] | Ambiguous requirements |
| `review` | Review with feedback | approve, request_changes | Spec/PR review |
| `error_resolution` | Error occurred, decide action | retry, skip, abort | Error recovery |

### Issue Comment Format for Feedback Requests

When feedback is needed and user is not in CLI:

```markdown
## Feedback Requested

**Workflow Run**: `fractary/claude-plugins/abc-123-...`
**Phase**: Architect
**Step**: design-review
**Requested**: 2025-12-06 18:00 UTC

### Decision Needed

Please review the architectural design and approve to proceed.

**Design Summary**:
- 3-layer architecture with handler pattern
- Extends existing autonomy model (no breaking changes)
- See: [WORK-00258-faber-hitl-resume-handling.md](/specs/WORK-00258-faber-hitl-resume-handling.md)

### Options

1. **Approve** - Continue to Build phase
2. **Request Changes** - Provide feedback for revision
3. **Reject** - Cancel this workflow run

### How to Respond

Reply to this issue with your decision. Include `@faber resume` in your comment to trigger workflow continuation.

Example:
```
I approve this design. The approach looks good.

@faber resume
```

---
_This feedback request will remain open until addressed. Run ID: `abc-123-...`_
```

### Context Reconstitution Protocol

Every time faber-manager starts or resumes (regardless of context):

```markdown
## Step 0: Context Reconstitution

Before executing any workflow steps, ALWAYS:

1. **Load Run State**
   - Read: .fractary/plugins/faber/runs/{run_id}/state.json
   - Read: .fractary/plugins/faber/runs/{run_id}/metadata.json
   - Verify run exists and is valid

2. **Load Specification** (if exists)
   - Path from: state.artifacts.spec_path
   - Read full spec into context
   - Note: spec contains requirements, design, acceptance criteria

3. **Load Issue Details** (if work_id present)
   - Fetch issue via: /fractary-work:issue-fetch {work_id}
   - Include: title, description, all comments
   - Note: may contain additional context, decisions, updates

4. **Inspect Branch State** (if branch exists)
   - Branch from: state.artifacts.branch_name
   - Run: git log --oneline -10 {branch}
   - Understand: what has been implemented so far

5. **Review Recent Events**
   - Read last 20 events from: runs/{run_id}/events/
   - Understand: what happened, any errors, decisions made

6. **Determine Resume Point**
   - If status == "awaiting_feedback": resume after feedback step
   - If status == "in_progress": resume from current_step
   - If status == "error": determine if retryable

This reconstitution ensures continuity regardless of whether:
- Same session continuing
- New session resuming
- Different environment (e.g., started in issue, continued in CLI)
```

### Parallel Run Coordination (Director Level)

When director spawns multiple manager runs:

```markdown
## Director Parallel Coordination

1. **Spawn Phase**
   - Generate run_id for each target
   - Spawn faber-manager for each in parallel
   - Track all run_ids in director state

2. **Wait for Stop Points**
   - Monitor all runs until each reaches a "stop" state:
     - completed: workflow finished successfully
     - awaiting_feedback: needs user input
     - error: failed and needs decision
     - cancelled: user cancelled

3. **Aggregate Results**
   When all runs have stopped:
   ```json
   {
     "total_runs": 5,
     "completed": 2,
     "awaiting_feedback": 2,
     "error": 1,
     "runs": [
       {"run_id": "...", "status": "completed", "work_id": "123"},
       {"run_id": "...", "status": "awaiting_feedback", "feedback_type": "approval", "work_id": "124"},
       {"run_id": "...", "status": "awaiting_feedback", "feedback_type": "error_resolution", "work_id": "125"},
       {"run_id": "...", "status": "error", "error": "Test failures", "work_id": "126"},
       {"run_id": "...", "status": "completed", "work_id": "127"}
     ]
   }
   ```

4. **Present Aggregated Prompt**
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
   - Options: [1] Approve [2] Request Changes [3] Reject

   **Run #125** (fix/125-auth-bug):
   - Type: Error Resolution
   - Error: Tests failed (3 failures)
   - Options: [1] Retry [2] Skip tests [3] Abort run

   **Run #126** (feat/126-dashboard):
   - Status: Failed
   - Error: Build compilation error in dashboard.ts
   - Options: [1] Retry run [2] Abort run

   Please provide feedback for each run:
   ```

5. **Parse and Distribute Responses**
   - Match responses to run_ids
   - Update each run's state with feedback
   - Resume individual runs with their specific feedback
```

### Future: @faber Integration Planning

While implementing `@faber` comment parsing is out of scope, design for it:

```markdown
## @faber Command Syntax (Future)

Supported in issue comments:

- `@faber resume` - Resume workflow with preceding comment as feedback
- `@faber resume --run {run_id}` - Resume specific run
- `@faber status` - Post current workflow status as comment
- `@faber cancel` - Cancel pending feedback request
- `@faber cancel --run {run_id}` - Cancel specific run

## Integration Points (for future implementation)

1. **Trigger Detection**
   - GitHub webhook on issue_comment event
   - Or: GitHub Action triggered on comment containing @faber
   - Or: Polling mechanism checking for new comments

2. **Comment Parsing**
   - Extract @faber command and arguments
   - Extract feedback text (comment body before @faber)
   - Identify run_id from context or explicit argument

3. **Session Spinup**
   - Start new Claude Code session
   - Load run context via reconstitution protocol
   - Execute resume with feedback

4. **Response Posting**
   - Post progress/completion as issue comment
   - Update labels if configured
```

## Implementation Plan

### Phase 1: Faber-Manager Re-engagement (CLI) ✅ COMPLETE
Ensure proper workflow continuation after feedback in CLI context.

**Tasks**:
- [x] Add explicit re-invocation protocol to faber-manager.md
- [x] Implement "Continue from step X" instruction injection
- [x] Add divergence prevention language to agent (Critical Rules 9, 10)
- [ ] Test: feedback → faber-manager resumes → workflow completes
- [x] Add "approval_granted" event emission after feedback
- [x] Document CLI feedback flow

**Artifacts**:
- `plugins/faber/skills/faber-manager/workflow/feedback-resume.md`
- Updated `plugins/faber/agents/faber-manager.md` (Step 0, Rules 9-10)

### Phase 2: Context Reconstitution ✅ COMPLETE
Enable effective resume across session boundaries.

**Tasks**:
- [x] Implement Step 0: Context Reconstitution in faber-manager
- [x] Create reconstitution checklist (spec, issue, commits, events)
- [x] Add spec re-read on every resume
- [x] Add issue re-fetch on every resume
- [x] Add branch inspection on resume
- [x] Add event history loading
- [ ] Test: stop workflow → new session → resume → continues correctly

**Artifacts**:
- `plugins/faber/skills/faber-manager/workflow/context-reconstitution.md`

### Phase 3: Issue Comment Feedback Posting ✅ COMPLETE
Post feedback requests to GitHub issues.

**Tasks**:
- [x] Define issue comment template for feedback requests
- [x] Extend work plugin's comment-creator for structured feedback comments
- [x] Add notification_sent tracking to run state
- [x] Implement comment posting when feedback needed (if issue context)
- [x] Include example @faber command in comment
- [x] Track comment URL in run state
- [x] Document issue-based feedback flow

**Artifacts**:
- `plugins/faber/skills/feedback-handler/SKILL.md`
- `plugins/faber/skills/feedback-handler/scripts/format-feedback-comment.sh`
- `plugins/faber/skills/feedback-handler/scripts/generate-request-id.sh`
- `plugins/faber/skills/feedback-handler/scripts/update-feedback-state.sh`

### Phase 4: Parallel Run Coordination ✅ COMPLETE
Enable feedback aggregation for multiple concurrent runs.

**Tasks**:
- [x] Extend coordinator to track multiple run_ids
- [x] Implement "wait for all stops" logic
- [x] Create aggregated feedback report format
- [x] Implement response parsing and distribution
- [ ] Test: 3 parallel runs → 2 need feedback → aggregate → distribute
- [x] Document parallel workflow patterns

**Artifacts**:
- `plugins/faber/skills/faber-manager/workflow/parallel-coordination.md`
- `plugins/faber/skills/run-manager/scripts/aggregate-runs.sh`

### Phase 5: Feedback Attribution & Logging ✅ COMPLETE
Complete audit trail for feedback.

**Tasks**:
- [x] Capture user identity for CLI (git config user)
- [x] Capture user identity for issue comments (from API)
- [x] Store attribution in decision_point events
- [x] Add feedback_received event type
- [x] Enable querying feedback by user
- [x] Document audit capabilities

**Artifacts**:
- `plugins/faber/skills/feedback-handler/scripts/get-user-identity.sh`
- Updated `plugins/faber/docs/STATE-TRACKING.md` (HITL Feedback Tracking section)
- Updated `plugins/faber/docs/RUN-ID-SYSTEM.md` (Feedback Events section)
- Updated `plugins/faber/skills/run-manager/scripts/emit-event.sh` (new event types)

## Files Created/Modified

### New Files ✅
- `plugins/faber/skills/faber-manager/workflow/context-reconstitution.md`: Step 0 protocol
- `plugins/faber/skills/faber-manager/workflow/feedback-resume.md`: Resume after feedback
- `plugins/faber/skills/faber-manager/workflow/parallel-coordination.md`: Multi-run coordination
- `plugins/faber/docs/HITL-WORKFLOW.md`: Complete HITL documentation
- `plugins/faber/skills/feedback-handler/SKILL.md`: Feedback handler skill
- `plugins/faber/skills/feedback-handler/scripts/format-feedback-comment.sh`: Format comments
- `plugins/faber/skills/feedback-handler/scripts/generate-request-id.sh`: Generate request IDs
- `plugins/faber/skills/feedback-handler/scripts/update-feedback-state.sh`: State management
- `plugins/faber/skills/feedback-handler/scripts/get-user-identity.sh`: User attribution
- `plugins/faber/skills/run-manager/scripts/aggregate-runs.sh`: Parallel run aggregation

### Modified Files ✅
- `plugins/faber/agents/faber-manager.md`: Added Step 0 and Critical Rules 9-10
- `plugins/faber/skills/run-manager/scripts/emit-event.sh`: Added feedback event types
- `plugins/faber/docs/RUN-ID-SYSTEM.md`: Added Feedback Events section and HITL state fields
- `plugins/faber/docs/STATE-TRACKING.md`: Added HITL Feedback Tracking section

## Testing Strategy

### Unit Tests
- Run state serialization with feedback_request field
- Feedback type validation
- Context reconstitution data gathering
- Aggregated report generation

### Integration Tests
- CLI: pause → feedback → faber-manager resumes → completes
- Issue: pause → post comment → (manual trigger) → resumes → completes
- Resume: stop mid-workflow → new session → reconstitute → continue
- Parallel: 3 runs → aggregate feedback → distribute → all complete

### E2E Tests
- Full FABER workflow with approval gate (CLI)
- Full workflow with issue-based feedback posting
- Session restart with context reconstitution
- Parallel runs with mixed outcomes (complete, feedback, error)

## Dependencies

- fractary-work plugin (for issue comment posting)
- fractary-logs plugin (for event logging, already integrated)
- fractary-repo plugin (for branch/commit inspection)
- Existing Run ID system (leverage, don't replace)

## Risks and Mitigations

- **Risk**: Faber-manager diverges after feedback instead of continuing workflow
  - **Likelihood**: Medium
  - **Impact**: High
  - **Mitigation**: Explicit re-invocation with strong continuation instructions; test extensively

- **Risk**: Context reconstitution misses critical information
  - **Likelihood**: Medium
  - **Impact**: Medium
  - **Mitigation**: Comprehensive checklist; spec + issue + commits + events; test with real scenarios

- **Risk**: Parallel run feedback routing errors
  - **Likelihood**: Low
  - **Impact**: Medium
  - **Mitigation**: Explicit run_id in all feedback; validate before resume

- **Risk**: Issue comments become cluttered with feedback requests
  - **Likelihood**: Low
  - **Impact**: Low
  - **Mitigation**: Clear formatting; consider collapsible sections; future: use issue thread

## Out of Scope (Future Work)

1. **@faber comment trigger implementation** - Planned but separate issue
2. **Slack/Discord/Email notifications** - Future enhancement
3. **Feedback timeout with auto-action** - Deferred (no timeout for now)
4. **Webhook-based resume triggers** - Avoid for now, use explicit commands
5. **GitHub Action integration** - Future, for @faber trigger
6. **Cross-environment session resumption** - Covered by reconstitution protocol

## Success Metrics

- Faber-manager re-engagement: 100% of feedback responses result in proper workflow continuation
- Context reconstitution: Resumed workflows succeed at same rate as continuous workflows
- Issue feedback posting: All feedback requests post to issue when in issue context
- Parallel coordination: Feedback correctly routed to individual runs 100% of time

## Design Decisions

### D1: Session Design Assumes Ephemeral
Every resume is treated as a new session. Context is always reconstituted from persisted state (spec, issue, commits, events). This:
- Simplifies the model (one path, not two)
- Supports cross-environment workflows (issue → CLI, CLI → different machine)
- Reduces reliance on session persistence

### D2: Feedback Requests Persist Indefinitely
No auto-timeout or auto-cancel. Feedback requests remain open until explicitly addressed or cancelled. This:
- Avoids unexpected workflow cancellation
- Supports async workflows with long feedback cycles
- Can be revisited later if problematic

### D3: Parallel Runs Use Aggregation Pattern
Director waits for all runs to stop, then aggregates. This:
- Reduces user interruption (one prompt, not many)
- Enables coherent decision-making across related runs
- Adds complexity but improves UX significantly

### D4: Future @faber Integration Uses Explicit Commands
When implemented, @faber will require explicit commands (e.g., `@faber resume`) rather than trying to parse natural language feedback. This:
- Reduces parsing errors
- Makes intent clear
- Aligns with @claude patterns

## Implementation Notes

- Existing `decision_point` event type is perfect for feedback requests
- Per-run state isolation (`.fractary/plugins/faber/runs/{run_id}/`) already supports this design
- Reconstitution protocol should be idempotent (safe to run multiple times)
- Issue comments should use collapsible sections for lengthy context
- Consider adding a `/faber:pending` command to list all awaiting feedback requests across runs
