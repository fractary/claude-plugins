# SPEC-00292: FABER Workflow Execution Completeness

**Status**: Draft
**Work ID**: 292
**Date**: 2025-12-08
**Author**: FABER Manager

## Problem Statement

FABER workflow execution is experiencing critical issues:

1. **Incomplete Phase Execution**: Workflows do not execute all phases (Frame → Architect → Build → Evaluate → Release)
2. **Missing State Updates**: Phase/step status is not updated in state.json during execution
3. **No Issue Comments**: Despite work_id being provided, no status updates are posted to linked GitHub issues
4. **Execution Guards Ineffective**: Pre-completion checklist guards (Guard 1, 2, 5) are not preventing hallucinated completion

These issues were observed in issue #290 workflow execution despite hallucination-prevention guards being implemented.

## Root Causes

### Root Cause 1: State Update Failures
- State updates are not happening BEFORE and AFTER each step
- CRITICAL_RULE #3 requires mandatory state updates:
  - Before step execution: mark as "in_progress"
  - After step execution: mark as "completed" or "failed"
- Missing these updates means:
  - State becomes inconsistent with actual execution
  - Resume functionality breaks (no way to know what completed)
  - Guards cannot verify execution occurred

### Root Cause 2: Comment Posting Not Invoked
- Issue comments are a critical requirement (CRITICAL_RULE #11)
- Comments provide stakeholder visibility and create audit trail
- Current implementation may:
  - Skip comment-creator skill invocation
  - Invoke it with wrong parameters
  - Fail silently without error handling

### Root Cause 3: Execution Evidence Not Generated
- Event logging (emit-event.sh) must happen for every major operation
- Missing events include:
  - phase_start and phase_complete for each phase
  - step_start and step_complete for each step
  - approval_granted, approval_denied for gates
  - skill_invoke for skill invocations
- Without events, Guard 1 (Execution Evidence Check) has nothing to verify

### Root Cause 4: Default Result Handling Not Applied
- CRITICAL_RULE #8: Default result handling must be applied to all steps
- When result_handling is not specified, use defaults:
  - on_success: "continue"
  - on_warning: "continue"
  - on_failure: "stop" (IMMUTABLE)
- Missing this means steps may not be evaluated correctly

## Solution Design

### Component 1: State Update Enforcement

**What**: Ensure state is ALWAYS updated before and after step execution

**Where**: faber-manager agent (CRITICAL_RULES enforcement)

**Implementation**:
1. Before step execution:
   ```
   state.update-step(phase, step, "in_progress")
   IF fails: ABORT with clear error
   ```
2. Execute step (invoke skill or prompt)
3. After step execution:
   ```
   result = capture_step_result()
   state.update-step(phase, step, "completed"|"failed", result)
   ```

**Validation**:
- State file shows each step with timestamp and status
- No gaps between step_start event and state update
- Recovery uses state file to determine resume point

### Component 2: Issue Comment Integration

**What**: Post comments to linked issues at key milestones

**Where**: faber-manager agent after each phase completes

**Milestones**:
1. workflow_start: Post initial comment with run ID and phases
2. phase_complete: Post comment after each phase with achievements
3. workflow_complete: Post final comment with artifacts and results

**Implementation**:
```
IF work_id provided:
  Skill: fractary-work:comment-creator
  Parameters:
    - issue_id: work_id
    - message: Phase completion summary
    - work_id: work_id
    - author_context: current phase
```

**Error Handling**:
- If comment posting fails, log error but DON'T ABORT
- Store comment attempt in event log
- Guard 5 can verify comments were attempted

### Component 3: Event Logging Completeness

**What**: Log every significant operation in immutable event log

**Where**: Events directory at `.fractary/plugins/faber/runs/{run_id}/events/`

**Events Required**:
- Phase boundaries: phase_start, phase_complete
- Step execution: step_start, step_complete, step_error
- Skill invocation: skill_invoke with parameters
- Decisions: approval_request, approval_granted, approval_denied
- Failures: step_error, phase_error with error details
- Retries: retry_loop_enter, retry_loop_exit, step_retry

**Validation**: Guard 1 verifies event existence before completion

### Component 4: Default Result Handling

**What**: Apply standard result handling when not explicitly configured

**Where**: Step execution in faber-manager

**Implementation**:
```
function applyResultHandlingDefaults(step):
  defaults = {
    on_success: "continue",
    on_warning: "continue",
    on_failure: "stop"  // IMMUTABLE
  }
  return merge(step.result_handling, defaults)
```

**Validation**:
- Every step result is evaluated with applied defaults
- on_failure: "stop" is ALWAYS enforced regardless of config
- Result handling is applied consistently across all phases

## Testing Strategy

### Test 1: Full Workflow Execution
Execute workflow through all 5 phases, verify:
- State file shows all phases with status != "pending"
- Event directory contains all required events
- Issue #292 has 5+ comments (start + phase completions + end)
- Guards 1, 2, 5 pass before completion

### Test 2: Phase Restart
Execute first 2 phases, pause, resume from phase 3:
- State file shows phases 1-2 as "completed"
- Resume starts at phase 3
- No duplicate events in log
- Artifacts from phases 1-2 preserved

### Test 3: Step Failure Recovery
Inject failure in build phase, verify:
- State shows step as "failed"
- Error event logged with details
- User given failure prompt with recovery options
- Workflow stops (on_failure: stop is enforced)

### Test 4: Issue Comment Visibility
Run workflow with work_id, verify:
- GitHub issue has comment from each milestone
- Comments include run ID for traceability
- Comments show phase progress clearly
- Guard 5 (issue comments) verification passes

## Acceptance Criteria

1. **AC1**: State file updated before AND after every step
   - Verified by examining state.json and events in order
   - State reflects actual execution progress

2. **AC2**: All 5 phases execute when workflow completes successfully
   - Frame → Architect → Build → Evaluate → Release all show "completed"
   - Each phase has phase_start and phase_complete events

3. **AC3**: Issue comments posted for visibility
   - At least 1 comment per phase (minimum 5 comments)
   - Comments include run ID for audit trail
   - Comments are posted during workflow, not after completion

4. **AC4**: Execution evidence guards pass
   - Guard 1: Multiple phase_start/step_start events exist
   - Guard 2: State shows non-pending phases
   - Guard 5: Issue comments were posted

5. **AC5**: Result handling applied consistently
   - Failed steps cause workflow stop (on_failure: stop)
   - Warning steps continue or prompt (based on config)
   - Success steps continue to next step

## Implementation Checklist

- [ ] Audit faber-manager agent for state update completeness
- [ ] Add state.update-step call before every step execution
- [ ] Add state.update-step call after every step execution
- [ ] Verify error cases trigger state update with failure status
- [ ] Add issue comment posting after each phase
- [ ] Add comment posting at workflow start
- [ ] Add comment posting at workflow end
- [ ] Verify all emit-event calls are in place
- [ ] Add result handling default application logic
- [ ] Test full workflow with all guards
- [ ] Test phase resumption with state recovery
- [ ] Test step failure handling and recovery options

## Files to Review

- `/mnt/c/GitHub/fractary/claude-plugins/plugins/faber/agents/faber-manager.md` - Main orchestration
- `/mnt/c/GitHub/fractary/claude-plugins/plugins/faber/skills/run-manager/scripts/emit-event.sh` - Event logging
- `/mnt/c/GitHub/fractary/claude-plugins/.fractary/plugins/faber/config.json` - Configuration
- `/mnt/c/GitHub/fractary/claude-plugins/.fractary/plugins/faber/runs/*/state.json` - State files
- `/mnt/c/GitHub/fractary/claude-plugins/.fractary/plugins/faber/runs/*/events/` - Event logs

## References

- CRITICAL_RULE #3: State Management - Mandatory Before/After Updates
- CRITICAL_RULE #8: Result Handling - Never Improvise
- CRITICAL_RULE #11: Issue Updates - Stakeholder Visibility
- EXECUTION_GUARD Guard 1: Pre-Completion Execution Evidence Check
- EXECUTION_GUARD Guard 2: State File Validation
- EXECUTION_GUARD Guard 5: Issue Comments Requirement
