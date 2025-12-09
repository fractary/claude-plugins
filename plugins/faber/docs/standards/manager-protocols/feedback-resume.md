# Workflow: Resume After Feedback

This workflow defines how faber-manager resumes workflow execution after receiving user feedback at a decision point.

## Overview

**Purpose**: Ensure proper workflow continuation after user provides feedback, with explicit faber-manager re-engagement.

**Critical Requirement**: The faber-manager MUST take back control and continue the planned workflow. Claude MUST NOT diverge into freeform operation.

## Feedback Resume Protocol

### Pre-Conditions

Before executing this protocol:
1. Context reconstitution has been completed (see `context-reconstitution.md`)
2. `state.status == "awaiting_feedback"`
3. `state.feedback_request` contains the pending feedback request
4. User has provided feedback response

### Step 1: Validate Feedback Request

```bash
# Verify feedback request exists and is valid
IF state.status != "awaiting_feedback" THEN
  ERROR: "Cannot resume - workflow is not awaiting feedback (status: ${state.status})"
  EXIT 1

IF state.feedback_request is null THEN
  ERROR: "Cannot resume - no feedback request found in state"
  EXIT 1

feedback_request = state.feedback_request
request_id = feedback_request.request_id
request_type = feedback_request.type
resume_point = feedback_request.resume_point

LOG "✓ Validated feedback request: ${request_id}"
LOG "  Type: ${request_type}"
LOG "  Resume point: ${resume_point.phase}:${resume_point.step}"
```

### Step 2: Capture Feedback Response

```bash
# The feedback response is provided via:
# - CLI: User's inline response to the prompt
# - Issue: Comment content before @faber trigger (future)
# - Parameter: Explicit feedback passed to resume command

feedback_response = {
  request_id: request_id,
  response: user_response,          # The actual feedback (e.g., "approve", "reject")
  comment: user_comment,            # Optional additional comment
  provided_by: {
    user: get_current_user(),       # git config user.name or issue comment author
    source: feedback_source,        # "cli" or "issue_comment"
    timestamp: current_timestamp()
  }
}

LOG "✓ Captured feedback response"
LOG "  Response: ${feedback_response.response}"
LOG "  From: ${feedback_response.provided_by.user} via ${feedback_response.provided_by.source}"
```

### Step 3: Validate Feedback Response

```bash
# Ensure feedback matches expected type and options
expected_options = feedback_request.options  # e.g., ["approve", "reject", "request_changes"]

IF feedback_response.response not in expected_options THEN
  # Check for partial match or alias
  normalized = normalize_response(feedback_response.response)

  IF normalized not in expected_options THEN
    WARNING: "Unexpected response: '${feedback_response.response}'"
    WARNING: "Expected one of: ${expected_options.join(', ')}"

    # For free-text types (clarification), any response is valid
    IF request_type == "clarification" THEN
      LOG "ℹ Clarification type - accepting free-text response"
    ELSE
      # Ask user to clarify
      ASK_USER: "Your response '${feedback_response.response}' doesn't match expected options. Please select:"
      OPTIONS: expected_options
```

### Step 4: Log Feedback Received Event

```bash
# Emit feedback_received event (new event type for HITL tracking)
Bash: plugins/faber/skills/run-manager/scripts/emit-event.sh \
  --run-id "${RUN_ID}" \
  --type "feedback_received" \
  --phase "${resume_point.phase}" \
  --step "${resume_point.step}" \
  --status "received" \
  --message "Feedback received for request ${request_id}" \
  --metadata '{
    "request_id": "${request_id}",
    "request_type": "${request_type}",
    "response": "${feedback_response.response}",
    "provided_by": {
      "user": "${feedback_response.provided_by.user}",
      "source": "${feedback_response.provided_by.source}"
    }
  }'

LOG "✓ Logged feedback_received event"
```

### Step 5: Update Run State

```bash
# Clear feedback request and update status
updated_state = {
  ...state,
  status: "in_progress",
  current_phase: resume_point.phase,
  current_step: resume_point.step,
  feedback_request: null,  # Clear pending request
  feedback_history: [
    ...(state.feedback_history ?? []),
    {
      request_id: request_id,
      request_type: request_type,
      response: feedback_response.response,
      provided_by: feedback_response.provided_by,
      received_at: current_timestamp()
    }
  ]
}

# Write updated state
write(STATE_FILE, updated_state)

LOG "✓ Updated state: awaiting_feedback → in_progress"
```

### Step 6: Emit Approval Granted Event

```bash
# If this was an approval-type feedback, emit approval_granted
IF request_type in ["approval", "confirmation", "review"] THEN
  Bash: plugins/faber/skills/run-manager/scripts/emit-event.sh \
    --run-id "${RUN_ID}" \
    --type "approval_granted" \
    --phase "${resume_point.phase}" \
    --message "User approved continuation (${feedback_response.response})" \
    --metadata '{
      "request_id": "${request_id}",
      "decision": "${feedback_response.response}",
      "approved_by": "${feedback_response.provided_by.user}"
    }'

  LOG "✓ Emitted approval_granted event"
```

### Step 7: Process Feedback Response

```bash
# Handle the feedback response based on type and response
SWITCH feedback_response.response:

  CASE "approve":
    LOG "✓ User approved - continuing workflow"
    action = "continue"

  CASE "reject":
    LOG "✗ User rejected - aborting workflow"
    action = "abort"
    abort_reason = feedback_response.comment ?? "User rejected at ${resume_point.phase}:${resume_point.step}"

  CASE "request_changes":
    LOG "↻ User requested changes - may need revision"
    action = "revise"
    revision_feedback = feedback_response.comment

  CASE "retry":
    LOG "↻ User requested retry"
    action = "retry"

  CASE "skip":
    LOG "⏭ User requested skip"
    action = "skip"

  CASE "abort":
    LOG "✗ User requested abort"
    action = "abort"
    abort_reason = "User aborted at ${resume_point.phase}:${resume_point.step}"

  DEFAULT:
    # For clarification or free-text responses
    LOG "ℹ Received clarification/input: ${feedback_response.response}"
    action = "continue"
    additional_context = feedback_response.response

# Store action for workflow engine
context.feedback_action = action
context.feedback_additional = additional_context ?? revision_feedback ?? null
```

### Step 8: Re-engage Faber-Manager for Workflow Continuation

**CRITICAL**: This is where we ensure faber-manager takes back control.

```markdown
## FABER-MANAGER RE-ENGAGEMENT

The workflow engine MUST now continue execution from the resume point.

**Context for continuation:**
- Run ID: ${RUN_ID}
- Resume Phase: ${resume_point.phase}
- Resume Step: ${resume_point.step}
- Feedback Action: ${context.feedback_action}
- Additional Context: ${context.feedback_additional}

**Instructions for faber-manager:**

1. **DO NOT improvise or deviate from the workflow definition**
2. Continue executing steps from ${resume_point.phase}:${resume_point.step}
3. If action is "continue": Proceed to next step after resume point
4. If action is "revise": Re-execute the step with revision feedback
5. If action is "retry": Re-execute the step that failed
6. If action is "skip": Mark step as skipped and proceed
7. If action is "abort": Mark workflow as aborted and exit

**Execution Mode:**
- This is a RESUME, not a new workflow
- Skip all steps that were already completed (check state.phases[phase].steps_completed)
- Start from the step AFTER the resume point (unless revise/retry)

**Workflow continuation command:**
Continue workflow orchestration loop from Step 4 in faber-manager.md,
starting at phase=${resume_point.phase}, step=${resume_point.step + 1}
```

## Handling Different Feedback Actions

### Action: Continue

Standard continuation - proceed to next step:

```bash
# Mark the paused step as complete (feedback was the completion gate)
Invoke Skill: faber-state
Operation: update-step
Parameters: run_id=${RUN_ID}, phase=${resume_point.phase}, step=${resume_point.step}, "completed"

# Proceed to next step in workflow
next_step = get_next_step(resume_point.phase, resume_point.step)

IF next_step is null THEN
  # Phase complete, proceed to next phase
  next_phase = get_next_phase(resume_point.phase)
  next_step = get_first_step(next_phase)

LOG "→ Continuing to ${next_phase}:${next_step}"
```

### Action: Revise

Re-execute step with revision feedback:

```bash
# Pass revision feedback to the step
step_context.revision_feedback = context.feedback_additional
step_context.is_revision = true

# Re-execute the same step
LOG "↻ Re-executing ${resume_point.phase}:${resume_point.step} with revision feedback"
execute_step(resume_point.phase, resume_point.step, step_context)
```

### Action: Retry

Re-execute step without modification (error recovery):

```bash
# Clear error state for the step
Invoke Skill: faber-state
Operation: clear-step-error
Parameters: run_id=${RUN_ID}, phase=${resume_point.phase}, step=${resume_point.step}

# Re-execute the step
LOG "↻ Retrying ${resume_point.phase}:${resume_point.step}"
execute_step(resume_point.phase, resume_point.step, step_context)
```

### Action: Skip

Skip the step and proceed:

```bash
# Mark step as skipped
Invoke Skill: faber-state
Operation: update-step
Parameters: run_id=${RUN_ID}, phase=${resume_point.phase}, step=${resume_point.step}, "skipped"

# Emit skip event
Bash: plugins/faber/skills/run-manager/scripts/emit-event.sh \
  --run-id "${RUN_ID}" \
  --type "step_skip" \
  --phase "${resume_point.phase}" \
  --step "${resume_point.step}" \
  --message "Step skipped by user"

# Proceed to next step
LOG "⏭ Skipped ${resume_point.phase}:${resume_point.step}"
```

### Action: Abort

Stop the workflow:

```bash
# Mark workflow as aborted
Invoke Skill: faber-state
Operation: mark-complete
Parameters: run_id=${RUN_ID}, final_status="aborted", reason="${abort_reason}"

# Emit workflow_cancelled event
Bash: plugins/faber/skills/run-manager/scripts/emit-event.sh \
  --run-id "${RUN_ID}" \
  --type "workflow_cancelled" \
  --message "Workflow aborted by user: ${abort_reason}"

LOG "✗ Workflow aborted"
EXIT 0
```

## Divergence Prevention

To prevent Claude from diverging after feedback:

### Strong Continuation Instructions

Always include these instructions when resuming:

```markdown
**CRITICAL WORKFLOW CONTINUATION RULES**

1. You are the faber-manager agent resuming workflow run ${RUN_ID}
2. The user has provided feedback - now CONTINUE THE WORKFLOW
3. Execute the remaining workflow steps as defined in the configuration
4. Do NOT improvise, suggest alternatives, or deviate from the workflow
5. If you need to make implementation decisions, refer to the specification
6. If you encounter ambiguity, pause at the next decision_point - do not guess

**You are resuming from:**
- Phase: ${resume_point.phase}
- Step: ${resume_point.step}
- Action: ${context.feedback_action}

**Next action:**
${next_action_description}
```

### Workflow Lock

Consider the workflow "locked" after feedback:

```bash
# Set a workflow lock flag in context
context.workflow_locked = true
context.workflow_lock_reason = "Resuming after feedback - must follow workflow"

# This flag can be checked by steps to ensure they don't deviate
IF context.workflow_locked THEN
  # Disallow freeform operations
  # Only execute configured workflow steps
```

## Integration with faber-manager.md

This workflow integrates with the main faber-manager agent at two points:

### 1. Before Step 2 (Load State)

Add check for awaiting_feedback status:

```markdown
## Step 1.5: Check for Pending Feedback

IF is_resume AND state.status == "awaiting_feedback" THEN
  # Execute feedback resume protocol
  Follow workflow: feedback-resume.md

  # This sets context.feedback_action and context.resume_point
  # Continue from Step 4 with resume point set
```

### 2. In Step 4 (Phase Orchestration Loop)

When starting a phase, check if resuming:

```markdown
# In phase orchestration loop
IF context.resume_point?.phase == current_phase THEN
  # Skip to the resume step
  skip_until_step = context.resume_point.step

  # Apply feedback action
  IF context.feedback_action == "continue" THEN
    skip_until_step = next_step_after(context.resume_point.step)
```

## Error Handling

| Error | Action |
|-------|--------|
| Invalid feedback response | Re-prompt user with valid options |
| State update failure | Abort resume, suggest manual intervention |
| Missing resume point | Abort resume, suggest re-running workflow |
| Workflow already completed | Inform user, no action needed |

## See Also

- [context-reconstitution.md](./context-reconstitution.md) - Context loading protocol
- [faber-manager.md](../../../agents/faber-manager.md) - Main workflow agent
- [HITL-WORKFLOW.md](../../HITL-WORKFLOW.md) - Complete HITL documentation
