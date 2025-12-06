# Workflow: Context Reconstitution

Every time faber-manager starts or resumes a workflow, it MUST execute this context reconstitution protocol to ensure it has sufficient context to continue effectively.

## Overview

**Purpose**: Ensure workflow continuity regardless of session state (same session, new session, different environment).

**When to Execute**: ALWAYS at the start of any workflow execution - whether new run, resume, or re-run.

**Design Philosophy**: Treat every invocation as a fresh session. Always reconstitute context from persisted state.

## Step 0: Context Reconstitution Protocol

Execute these steps IN ORDER before any workflow step execution:

### 0.1 Load Run State and Metadata

```bash
# Read run state
RUN_DIR=".fractary/plugins/faber/runs/${RUN_ID}"
STATE_FILE="${RUN_DIR}/state.json"
METADATA_FILE="${RUN_DIR}/metadata.json"

# Validate run exists
if [[ ! -f "$STATE_FILE" ]]; then
  ERROR: "Run not found: ${RUN_ID}"
  EXIT 1
fi

# Load state
state = read(STATE_FILE)
metadata = read(METADATA_FILE)

# Extract key fields
work_id = state.work_id
status = state.status
current_phase = state.current_phase
current_step = state.current_step
artifacts = state.artifacts
feedback_request = state.feedback_request  # May be null
```

**Validate State Integrity:**
```
IF state.work_id is null AND work_id was expected THEN
  WARNING: "State missing work_id - may be a standalone run"

IF state.status not in ["pending", "in_progress", "awaiting_feedback", "completed", "failed", "cancelled"] THEN
  ERROR: "Invalid state status: ${state.status}"
  EXIT 1
```

### 0.2 Load Specification (if exists)

```bash
# Check if spec exists
spec_path = state.artifacts.spec_path

IF spec_path is not null AND file_exists(spec_path) THEN
  # Read full specification into context
  spec_content = read(spec_path)

  LOG "✓ Loaded specification: ${spec_path}"
  LOG "  Title: ${spec_frontmatter.title}"
  LOG "  Type: ${spec_frontmatter.type}"
  LOG "  Status: ${spec_frontmatter.status}"
ELSE
  LOG "ℹ No specification found (may not be created yet)"
```

**What to Extract from Spec:**
- Summary and goals
- Functional requirements
- Acceptance criteria
- Technical approach
- Files to modify
- Implementation phases/tasks

### 0.3 Load Issue Details (if work_id present)

```bash
IF work_id is not null THEN
  # Fetch issue via work plugin
  issue_data = invoke "/fractary-work:issue-fetch ${work_id}"

  LOG "✓ Loaded issue #${work_id}: ${issue_data.title}"
  LOG "  State: ${issue_data.state}"
  LOG "  Labels: ${issue_data.labels.join(', ')}"
  LOG "  Comments: ${issue_data.comments.length}"

  # Store issue context
  context.issue = {
    title: issue_data.title,
    description: issue_data.body,
    labels: issue_data.labels,
    comments: issue_data.comments,
    url: issue_data.url,
    state: issue_data.state
  }
ELSE
  LOG "ℹ No work_id - standalone workflow run"
```

**What to Extract from Issue:**
- Title and description (requirements)
- Labels (may indicate type, priority)
- All comments (may contain decisions, clarifications, feedback responses)
- Current state (open/closed)

### 0.4 Inspect Branch State (if branch exists)

```bash
branch_name = state.artifacts.branch_name

IF branch_name is not null THEN
  # Check if branch exists
  branch_exists = bash("git show-ref --verify --quiet refs/heads/${branch_name} && echo true || echo false")

  IF branch_exists == "true" THEN
    # Get recent commits on this branch
    recent_commits = bash("git log --oneline -10 ${branch_name}")

    # Get diff summary against main
    diff_summary = bash("git diff --stat main...${branch_name}")

    LOG "✓ Branch exists: ${branch_name}"
    LOG "  Recent commits:"
    for commit in recent_commits:
      LOG "    ${commit}"

    # Store branch context
    context.branch = {
      name: branch_name,
      commits: recent_commits,
      files_changed: diff_summary
    }
  ELSE
    LOG "ℹ Branch ${branch_name} not found locally (may need to fetch)"
ELSE
  LOG "ℹ No branch created yet"
```

**What to Understand from Branch:**
- What has been implemented so far
- How many commits have been made
- What files have been changed
- Gap between current state and spec requirements

### 0.5 Review Recent Events

```bash
EVENTS_DIR="${RUN_DIR}/events"

IF directory_exists(EVENTS_DIR) THEN
  # Get last 20 events
  recent_events = list_files(EVENTS_DIR) | sort | tail -20

  events = []
  for event_file in recent_events:
    event = read(event_file)
    events.append(event)

  LOG "✓ Loaded ${events.length} recent events"

  # Summarize key events
  for event in events:
    IF event.type in ["phase_complete", "step_error", "decision_point", "approval_granted"] THEN
      LOG "  [${event.timestamp}] ${event.type}: ${event.message}"

  # Store event context
  context.events = events
ELSE
  LOG "ℹ No events found (new run)"
```

**What to Understand from Events:**
- What phases/steps have completed
- Any errors that occurred
- Decision points and their outcomes
- Approval requests and responses
- Retry attempts and results

### 0.6 Check for Pending Feedback

```bash
IF state.status == "awaiting_feedback" THEN
  feedback_request = state.feedback_request

  LOG "⏳ Workflow is awaiting feedback"
  LOG "  Request ID: ${feedback_request.request_id}"
  LOG "  Type: ${feedback_request.type}"
  LOG "  Prompt: ${feedback_request.prompt}"
  LOG "  Requested at: ${feedback_request.requested_at}"

  IF feedback_request.notification_sent.issue_comment THEN
    LOG "  Comment posted: ${feedback_request.notification_sent.comment_url}"

  # Mark that we're resuming from feedback
  context.resuming_from_feedback = true
  context.feedback_request = feedback_request
ELSE
  context.resuming_from_feedback = false
```

### 0.7 Determine Resume Point

```bash
resume_point = null

SWITCH state.status:
  CASE "awaiting_feedback":
    # Resume after the step that requested feedback
    resume_point = {
      phase: state.feedback_request.resume_point.phase,
      step: state.feedback_request.resume_point.step,
      mode: "after_feedback"
    }
    LOG "Resume point: After feedback at ${resume_point.phase}:${resume_point.step}"

  CASE "in_progress":
    # Resume from current step
    resume_point = {
      phase: state.current_phase,
      step: state.current_step,
      mode: "continue"
    }
    LOG "Resume point: Continue from ${resume_point.phase}:${resume_point.step}"

  CASE "failed":
    # Determine if retryable
    failed_step = state.phases[state.current_phase].failed_step
    resume_point = {
      phase: state.current_phase,
      step: failed_step,
      mode: "retry"
    }
    LOG "Resume point: Retry failed step ${resume_point.phase}:${resume_point.step}"

  CASE "pending":
    # Start from beginning
    resume_point = {
      phase: "frame",
      step: null,
      mode: "start"
    }
    LOG "Resume point: Start from beginning"

  CASE "completed":
    LOG "ℹ Workflow already completed - nothing to resume"
    resume_point = null

  CASE "cancelled":
    LOG "ℹ Workflow was cancelled - cannot resume"
    resume_point = null

context.resume_point = resume_point
```

### 0.8 Build Consolidated Context

```bash
# Consolidate all loaded context
workflow_context = {
  run_id: RUN_ID,
  work_id: work_id,

  # State info
  status: state.status,
  current_phase: state.current_phase,
  current_step: state.current_step,
  artifacts: state.artifacts,

  # Loaded context
  spec: context.spec,           # May be null
  issue: context.issue,         # May be null
  branch: context.branch,       # May be null
  events: context.events,       # May be empty

  # Feedback state
  resuming_from_feedback: context.resuming_from_feedback,
  feedback_request: context.feedback_request,

  # Resume info
  resume_point: context.resume_point
}

LOG ""
LOG "═══════════════════════════════════════════════════════════"
LOG "  CONTEXT RECONSTITUTION COMPLETE"
LOG "═══════════════════════════════════════════════════════════"
LOG "  Run ID:        ${RUN_ID}"
LOG "  Work ID:       ${work_id ?? 'N/A'}"
LOG "  Status:        ${state.status}"
LOG "  Resume Mode:   ${resume_point?.mode ?? 'N/A'}"
LOG "  Spec:          ${spec_path ?? 'Not created'}"
LOG "  Branch:        ${branch_name ?? 'Not created'}"
LOG "  Events:        ${events.length} loaded"
LOG "═══════════════════════════════════════════════════════════"
LOG ""
```

## Context Summary Output

After reconstitution, output a brief summary for visibility:

```
✓ Context reconstituted for run: fractary/claude-plugins/abc-123...
  Work Item: #258 - Better faber workflow HITL handling
  Spec: /specs/WORK-00258-faber-hitl-resume-handling.md
  Branch: feat/258-better-faber-workflow-hitl-resume-handling-via-iss
  Status: awaiting_feedback → Resuming after feedback
  Last Event: [2025-12-06T18:30:00Z] decision_point: Awaiting design approval
```

## Error Handling

| Error | Action |
|-------|--------|
| Run directory not found | ABORT with clear error and run ID |
| State file corrupted | ABORT, suggest manual inspection |
| Issue fetch failed | WARN and continue (issue may be deleted) |
| Branch not found | WARN and continue (may need to create) |
| Events directory empty | INFO (expected for new runs) |

## Why This Matters

1. **Session Independence**: Claude sessions are ephemeral. Every resume must work as if it's a new session.

2. **Cross-Environment Support**: User may start in GitHub issue context, then switch to CLI. Context must work either way.

3. **Debugging**: If something goes wrong, full context helps diagnose the issue.

4. **Continuity**: Workflow continues seamlessly without user needing to re-explain context.

## Integration Points

**Called By:**
- faber-manager agent (Step 0 before any workflow execution)

**Reads From:**
- `.fractary/plugins/faber/runs/{run_id}/state.json`
- `.fractary/plugins/faber/runs/{run_id}/metadata.json`
- `.fractary/plugins/faber/runs/{run_id}/events/`
- Spec file (path from state.artifacts.spec_path)
- Work plugin (issue fetch)
- Git (branch inspection)

**Outputs:**
- `workflow_context` object used by all subsequent workflow steps
