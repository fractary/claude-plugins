# Implementation Notes for Issue #292

## FABER Workflow Execution Issues: Completeness Analysis

### Work Summary
This document provides implementation guidance for fixing FABER workflow execution issues where:
1. Incomplete phases were not being executed
2. State was never updated during execution
3. Issue comments were not posted to GitHub
4. Execution evidence guards were bypassed

### Analysis and Recommendations

#### Issue 1: State Update Failures

**Current Behavior**:
The faber-manager agent must update state.json before AND after every step execution per CRITICAL_RULE #3. However, observation shows:
- State updates may not occur if the state skill fails
- No fallback mechanism exists for state update failures
- State file can become inconsistent with actual execution

**Recommended Fix**:
1. Implement atomic state updates with rollback capability
2. Add pre-update validation (state file readable and valid JSON)
3. Add post-update verification (verify state change actually persisted)
4. Implement automatic state recovery if update fails:
   ```bash
   # Before step execution
   state.backup()  # Create .bak copy
   state.update-step(phase, step, "in_progress")
   IF fails:
     state.restore()  # Restore from backup
     ABORT workflow with clear error message
   ```

**Implementation Location**:
- `/mnt/c/GitHub/fractary/claude-plugins/plugins/faber/agents/faber-manager.md` - Add pre/post state update logic
- `/mnt/c/GitHub/fractary/claude-plugins/plugins/faber/skills/run-manager/scripts/` - Add state recovery script

#### Issue 2: Issue Comments Not Posted

**Current Behavior**:
Comments should be posted to GitHub issues at key milestones (workflow_start, phase_complete, workflow_complete), but they are not appearing.

**Root Causes**:
1. Comment-creator skill may not be invoked at all
2. Skill may be invoked but with wrong parameters (missing working_directory)
3. GitHub authentication may fail silently
4. No error handling for failed comment postings

**Recommended Fix**:
1. Add explicit issue comment posting after each milestone:
   ```
   IF work_id provided:
     Invoke fractary-work:comment-creator skill
     WITH: issue_id={work_id}, message={milestone_summary}
   ELSE IF no work_id:
     LOG: "No work_id provided - skipping issue comments"
   ```

2. Add error handling for failed comments:
   ```
   IF comment posting fails:
     LOG warning (don't abort - comments are not critical)
     Store failure in event log
   ELSE:
     LOG comment URL for audit trail
   ```

3. Ensure working_directory is always passed:
   ```
   comment-creator parameters:
     - issue_id: {work_id}
     - message: {milestone_text}
     - working_directory: {absolute_path_to_project}
   ```

**Implementation Location**:
- `/mnt/c/GitHub/fractary/claude-plugins/plugins/faber/agents/faber-manager.md` - Add post-milestone comments

#### Issue 3: Execution Evidence Not Generated

**Current Behavior**:
Event logging via emit-event.sh should create an immutable audit trail, but events may not be generated for all operations.

**Missing Events**:
- phase_start: Not emitted when phase begins
- phase_complete: Not emitted when phase ends
- step_start: Not emitted when step begins
- step_complete: Not emitted when step ends
- skill_invoke: Not emitted when skill is invoked
- Approval events: Not emitted for approval gates

**Recommended Fix**:
1. Add emit-event calls at every critical juncture:
   ```
   Phase Start:
     emit-event.sh --run-id {run_id} --type phase_start --phase {phase}

   Step Start:
     emit-event.sh --run-id {run_id} --type step_start --phase {phase} --step {step_id}

   Step Complete:
     emit-event.sh --run-id {run_id} --type step_complete --phase {phase} --step {step_id}

   Phase Complete:
     emit-event.sh --run-id {run_id} --type phase_complete --phase {phase}
   ```

2. Add event emission for skill invocation:
   ```
   Invoke skill
   emit-event.sh --run-id {run_id} --type skill_invoke --phase {phase} --step {step_id} \
     --metadata '{"skill_name": "{skill}", "config": {...}}'
   ```

3. Verify events are created:
   ```bash
   # Before workflow_complete:
   if [ ! -f ".fractary/plugins/faber/runs/{run_id}/events/002-phase_start.json" ]; then
     ERROR "No execution evidence found"
   fi
   ```

**Implementation Location**:
- `/mnt/c/GitHub/fractary/claude-plugins/plugins/faber/agents/faber-manager.md` - Add emit-event calls throughout

#### Issue 4: Default Result Handling Not Applied

**Current Behavior**:
CRITICAL_RULE #8 requires default result handling to be applied when not specified in workflow config. However, steps may not be evaluated with defaults, leading to:
- Failed steps not stopping the workflow
- Warning steps not prompting the user
- Success steps not continuing correctly

**Recommended Fix**:
1. Implement result handling defaults at step evaluation:
   ```javascript
   function applyResultHandlingDefaults(step) {
     const defaults = {
       on_success: "continue",
       on_warning: "continue",
       on_failure: "stop"  // IMMUTABLE - always enforced
     };

     // If no result_handling, return full defaults
     if (!step.result_handling) {
       return defaults;
     }

     // Merge with user's partial config
     return {
       on_success: step.result_handling.on_success ?? defaults.on_success,
       on_warning: step.result_handling.on_warning ?? defaults.on_warning,
       on_failure: "stop"  // ALWAYS stop on failure - non-negotiable
     };
   }
   ```

2. Apply handling to every step result:
   ```
   FOR each step:
     step_result = execute_step()
     handling = applyResultHandlingDefaults(step)

     SWITCH step_result.status:
       CASE "failure":
         // on_failure is ALWAYS "stop"
         ABORT workflow
       CASE "warning":
         SWITCH handling.on_warning:
           CASE "prompt": Ask user
           CASE "stop": ABORT
           CASE "continue": Proceed (default)
       CASE "success":
         SWITCH handling.on_success:
           CASE "prompt": Ask user
           CASE "continue": Proceed (default)
   ```

**Implementation Location**:
- `/mnt/c/GitHub/fractary/claude-plugins/plugins/faber/agents/faber-manager.md` - Add result handling logic

### Execution Guards: Prevention of Hallucination

The three execution guards must work together to prevent hallucination:

#### Guard 1: Execution Evidence Check
```bash
# Before workflow_complete:
if [ ! -f "events/002-phase_start.json" ] && [ ! -f "events/003-step_start.json" ]; then
  ERROR "No execution evidence - workflow likely hallucinated"
  EXIT 1
fi
```

**This guard verifies**: At least one phase_start OR step_start event exists.

#### Guard 2: State File Validation
```bash
# Before workflow_complete:
PENDING=$(jq '.phases | map(select(.status == "pending")) | length' state.json)
TOTAL=$(jq '.phases | length' state.json)

if [ $PENDING -eq $TOTAL ]; then
  ERROR "All phases still pending - no execution occurred"
  EXIT 1
fi
```

**This guard verifies**: At least one phase shows status != "pending"

#### Guard 5: Issue Comments (when work_id provided)
```bash
# Before workflow_complete:
COMMENTS=$(ls events/*-comment_posted* 2>/dev/null | wc -l)
if [ $COMMENTS -eq 0 ]; then
  ERROR "No comments posted to issue - Guard 5 violation"
  EXIT 1
fi
```

**This guard verifies**: At least one comment was posted to the linked issue

### Implementation Checklist

Core Changes Required:
- [ ] Add state.backup() before every step execution
- [ ] Add state.update-step() call before EVERY step
- [ ] Add state verification after state updates
- [ ] Add emit-event() call for every phase/step boundary
- [ ] Add emit-event() call for every skill invocation
- [ ] Add comment-creator skill invocation after each phase
- [ ] Add comment-creator skill invocation at workflow start/end
- [ ] Implement result handling defaults
- [ ] Add on_failure: "stop" enforcement (IMMUTABLE)
- [ ] Add Guard 1, 2, 5 verification before workflow_complete
- [ ] Test full workflow execution through all 5 phases
- [ ] Test resume from mid-workflow
- [ ] Test step failure handling
- [ ] Test issue comment visibility

### Expected Outcomes

After implementation:
1. **State Consistency**: Every step update is reflected in state.json with timestamps
2. **Audit Trail**: Complete event log showing every operation
3. **Stakeholder Visibility**: GitHub issue has comments at each phase
4. **Execution Evidence**: Guards can verify execution actually occurred
5. **Resumable Workflows**: State file allows resuming from any point
6. **Consistent Result Handling**: All steps follow the same handling rules

### Files Modified in This Work Item

1. `/mnt/c/GitHub/fractary/claude-plugins/.fractary/plugins/spec/SPEC-00292-faber-execution-completeness.md` - Technical specification (created in Architect phase)
2. `/mnt/c/GitHub/fractary/claude-plugins/IMPLEMENTATION-NOTES-292.md` - This implementation guide
3. Additional files to be modified in faber-manager.md and related agents

### Related Issues

- Issue #290: "faber-manager hallucination fix" (previous attempt)
- Issue #275: "prevent date patterns from being parsed as work IDs"
- Issue #235: "ensure workflow steps return status code"
- Issue #237: "state management should track workflow phase"

### Testing Evidence

After implementation, run the following test:
```bash
# Test full workflow execution
/faber:run 292 --autonomy guarded

# Verify execution evidence
ls -la .fractary/plugins/faber/runs/*/events/
# Should show: phase_start, phase_complete events for all phases

# Verify state progression
jq '.phases[] | {phase: .phase, status: .status}' .fractary/plugins/faber/runs/*/state.json
# Should show: frame, architect, build, evaluate, release all "completed"

# Verify issue comments
gh issue comments 292 | grep "FABER\|Phase"
# Should show: multiple comments from workflow execution
```

### Success Criteria

The workflow is fixed when:
1. ✓ All 5 phases execute and mark as "completed"
2. ✓ State file shows every step with before/after updates
3. ✓ Issue #292 has 5+ comments (from phases) plus start/end comments
4. ✓ Guards 1, 2, 5 all pass before workflow completion
5. ✓ Can resume from any completed phase
6. ✓ Failed steps stop the workflow (on_failure: "stop" enforced)
7. ✓ Result handling applied consistently
