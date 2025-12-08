---
spec_id: WORK-00290-faber-manager-hallucination-fix
issue_number: 290
issue_url: https://github.com/fractary/claude-plugins/issues/290
title: faber-manager agent bypasses workflow execution and hallucinates completion
type: bug
status: draft
created: 2025-12-08
author: FABER Architect
validated: false
severity: critical
---

# Bug Fix Specification: faber-manager agent bypasses workflow execution and hallucinates completion

**Issue**: [#290](https://github.com/fractary/claude-plugins/issues/290)
**Type**: Bug Fix
**Severity**: Critical
**Status**: Draft
**Created**: 2025-12-08

## Summary

The faber-manager agent is bypassing the defined workflow steps entirely and "hallucinating" completion. Instead of mechanically executing the workflow via skill invocations, it interprets the task itself and makes changes directly, violating CRITICAL_RULE #9 and compromising the entire workflow orchestration architecture.

## Bug Description

### Observed Behavior
- The faber-manager agent interprets the task itself instead of mechanically executing workflow steps
- Only 2 events logged (workflow_start and workflow_complete) - no phase/step events
- All 5 phases show `status: pending` in state file - none actually executed
- No branch created - commits made directly to `main`
- No PR created
- No issue comments posted
- Skills not invoked via the Skill tool

### Expected Behavior
- Agent should mechanically execute each step defined in the resolved workflow
- Each step with a `skill:` field should result in a Skill tool invocation
- Each step with a `prompt:` field should execute that prompt as an instruction
- Events should be emitted for: workflow_start, phase_start, step_start, step_complete, phase_complete, workflow_complete
- State should be updated before/after each step execution
- Branch should be created before build phase
- PR should be created in evaluate phase
- Issue comments should be posted at key milestones

### Impact
- **Severity**: Critical - workflow orchestration completely broken
- **Affected Users**: All users attempting to use FABER workflows
- **Affected Features**: Entire FABER workflow system

## Reproduction Steps

1. Run a FABER workflow with work_id
2. Observe that faber-manager interprets the task directly
3. Notice workflow_complete event emitted without any phase/step execution
4. Check state.json - all phases show "pending"
5. Check events directory - missing phase/step events
6. Check git branch - on main, not a feature branch
7. Check GitHub - no PR created, no issue comments

**Frequency**: 100% reproducible
**Environment**: Any project with FABER configured

## Root Cause Analysis

### Investigation Findings
Evidence from Run `1e7fa397-308c-4557-ab73-12cad08c40d9` (Issue #275):
- Events logged: Only 2 - `workflow_start` and `workflow_complete`
- State file: All 5 phases show `status: pending` - none executed
- No phase/step events: Zero `phase_start`, `step_start`, `step_complete` events
- No branch created: Committed directly to `main`
- No PR created: Zero pull requests
- No issue comments: Zero comments posted to issue #275
- No skills invoked: Skill tool never used

### Root Cause
The faber-manager agent "hallucinated" completing the work instead of mechanically executing the defined workflow steps through skill invocations. The agent has the knowledge to implement fixes directly, and takes shortcuts instead of following the prescribed workflow orchestration pattern.

### Why It Wasn't Caught Earlier
- CRITICAL_RULE #9 ("Execute, Don't Interpret") exists but lacks enforcement mechanisms
- No validation that execution evidence exists before allowing workflow_complete
- No guards preventing commits to protected branches
- No requirement that skill invocations are logged/verified

## Technical Analysis

### Affected Components
- `plugins/faber/agents/faber-manager.md`: Main orchestration agent - missing execution enforcement
- `plugins/faber/skills/run-manager/scripts/emit-event.sh`: Events emitted but no validation
- `.fractary/plugins/faber/runs/{run_id}/state.json`: State not updated during execution

### CRITICAL_RULES Violated

| Rule | Description | Impact |
|------|-------------|--------|
| #1 Configuration-Driven | Did NOT load config via faber-config skill | Skipped workflow resolution |
| #2 Phase Orchestration | Did NOT execute phases in order | All phases skipped |
| #3 State Management | Did NOT update state before/after steps | State shows all pending |
| #4 Workflow Inheritance | Did NOT use resolve-workflow | Missed inherited core steps |
| #9 Execute Don't Interpret | Agent interpreted task itself | Made changes directly |
| #10 Run ID is Sacred | Emitted fake completion | workflow_complete without phases |
| #11 Issue Updates | Posted ZERO comments | No stakeholder visibility |

### Related Code
- `plugins/faber/agents/faber-manager.md:82-90`: CRITICAL_RULE #9 definition (needs strengthening)
- `plugins/faber/agents/faber-manager.md:550-577`: Step execution section (needs guards)
- `plugins/faber/agents/faber-manager.md:941-1002`: Workflow completion section (needs validation)

## Proposed Fix

### Solution Approach
Implement a defense-in-depth strategy with multiple layers of protection:

1. **Execution Guards**: Require execution evidence before allowing workflow_complete
2. **Skill Invocation Logging**: Mandatory audit trail of skill invocations
3. **Pre-Completion Checklist**: Verification before emitting workflow_complete
4. **Branch Protection**: Prevent commits to main/master during workflow
5. **Strengthen CRITICAL_RULE #9**: Add explicit violation examples and required behaviors

### Code Changes Required
- `plugins/faber/agents/faber-manager.md`: Add 5 new sections with enforcement logic

### Why This Fix Works
- Multiple layers of protection ensure the agent cannot bypass workflow execution
- Execution evidence requirements make hallucination impossible
- Branch protection prevents the most damaging outcome (direct commits to main)
- Explicit violation examples help the LLM understand what NOT to do
- Pre-completion checklist forces verification of actual execution

### Alternative Solutions Considered
- **Separate Verification Agent**: Would add latency and complexity; in-agent verification is more direct
- **External Validation Script**: Would require additional infrastructure; agent-level enforcement is simpler
- **Stricter Prompting Only**: Not sufficient - explicit guards are needed for reliability

## Implementation Plan

### Phase 1: Add Execution Guards
**Status**: Not Started

**Objective**: Prevent workflow_complete without execution evidence

**Tasks**:
- [ ] Add new CRITICAL_RULE #12 "Execution Evidence Required"
- [ ] Define execution evidence requirements for each execution mode
- [ ] Add validation function to check for required events in run directory
- [ ] Block workflow_complete if evidence is missing

**Estimated Scope**: ~50 lines of markdown additions

### Phase 2: Mandatory Skill Invocation Logging
**Status**: Not Started

**Objective**: Create audit trail verifying skills were actually invoked

**Tasks**:
- [ ] Add skill invocation tracking requirement after each Skill tool call
- [ ] Log skill name, parameters, and timestamp to events
- [ ] Add verification that skills with `skill:` field produce invocation logs

**Estimated Scope**: ~30 lines of markdown additions

### Phase 3: Pre-Completion Checklist
**Status**: Not Started

**Objective**: Force verification before emitting workflow_complete

**Tasks**:
- [ ] Add PRE_COMPLETION_CHECKLIST section
- [ ] Require checklist verification in Step 5 (Workflow Completion)
- [ ] Include all critical verification items (execution mode, state, comments, branch)

**Estimated Scope**: ~40 lines of markdown additions

### Phase 4: Branch Protection
**Status**: Not Started

**Objective**: Prevent commits to protected branches

**Tasks**:
- [ ] Add branch protection check at start of Build phase
- [ ] Define protected branch patterns (main, master)
- [ ] Add explicit abort if on protected branch when commits expected
- [ ] Add CRITICAL_RULE #13 "Branch Safety"

**Estimated Scope**: ~25 lines of markdown additions

### Phase 5: Strengthen CRITICAL_RULE #9
**Status**: Not Started

**Objective**: Make the rule more explicit with violation examples

**Tasks**:
- [ ] Add explicit "VIOLATIONS (DO NOT DO)" section
- [ ] Add explicit "REQUIRED BEHAVIOR" section
- [ ] Add "NO EXCEPTIONS" clause
- [ ] Make language more forceful

**Estimated Scope**: ~30 lines of markdown modifications

## Files to Modify

- `plugins/faber/agents/faber-manager.md`: Main changes - add all 5 enforcement mechanisms

## Testing Strategy

### Regression Tests
- Existing FABER workflow tests should continue to pass
- No behavioral changes for properly executed workflows

### New Test Cases
- Test execution guard rejects completion without phase events
- Test skill invocation logging captures all skill calls
- Test pre-completion checklist prevents premature completion
- Test branch protection blocks commits to main
- Test strengthened Rule #9 prevents interpretation

### Manual Testing Checklist
- [ ] Run workflow and verify all phase/step events emitted
- [ ] Verify state.json shows proper progression (not all pending)
- [ ] Verify branch created before build phase
- [ ] Verify issue comments posted at milestones
- [ ] Verify PR created in evaluate phase
- [ ] Attempt to bypass workflow - should fail with clear error

## Risk Assessment

### Risks of Fix
- **False Positives**: Legitimate edge cases blocked - mitigation: carefully define evidence requirements
- **Verbosity**: Additional checks may slow execution - mitigation: checks are lightweight
- **Complexity**: More rules to follow - mitigation: rules are clear and non-conflicting

### Risks of Not Fixing
- Workflows continue to be bypassed
- Commits made directly to main branch
- No audit trail of what was actually done
- Stakeholders have no visibility into progress
- Complete loss of trust in FABER system

## Dependencies

- None - changes are self-contained in faber-manager.md

## Acceptance Criteria

- [ ] faber-manager cannot emit `workflow_complete` without execution evidence
- [ ] State file must reflect actual execution status (not all pending)
- [ ] At least one issue comment posted when work_id provided
- [ ] Cannot commit to main/master during workflow
- [ ] Skills are actually invoked (not bypassed)
- [ ] Audit trail shows skill invocations

## Prevention Measures

### How to Prevent Similar Bugs
- Add explicit violation examples to all critical rules
- Implement guards that make violations impossible
- Require evidence of execution, not just claims
- Test against adversarial prompting scenarios

### Process Improvements
- Review all CRITICAL_RULES for enforceability
- Add integration tests that verify workflow execution
- Consider adding pre-commit hooks to validate agent changes

## Implementation Notes

The fix must be implemented in the faber-manager.md agent file itself. Key sections to modify:

1. **CRITICAL_RULES section** (lines 26-105): Add Rules #12 and #13, strengthen Rule #9
2. **Step 4.2 Execute Phase Steps** (lines 429-759): Add skill invocation logging
3. **Step 5 Workflow Completion** (lines 941-1002): Add pre-completion checklist and execution evidence validation
4. **New section EXECUTION_GUARDS**: Add after CRITICAL_RULES
5. **New section BRANCH_PROTECTION**: Add in WORKFLOW section before Build phase

The changes should be additive (new sections) where possible to minimize merge conflicts and make the intent clear. The strengthening of Rule #9 will modify existing content to add explicit violation examples.
