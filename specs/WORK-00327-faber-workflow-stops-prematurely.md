---
spec_id: WORK-00327-faber-workflow-stops-prematurely
work_id: 327
issue_url: https://github.com/fractary/claude-plugins/issues/327
title: "FABER: Workflow stops prematurely after spec-generate step; Resume workflow needs plan/execute architecture alignment"
type: bug
status: draft
created: 2025-12-09
updated: 2025-12-09
author: claude
validated: false
severity: high
source: conversation+issue
refinement_round: 1
---

# Bug Fix Specification: FABER Workflow Stops Prematurely

**Issue**: [#327](https://github.com/fractary/claude-plugins/issues/327)
**Type**: Bug Fix
**Severity**: High
**Status**: Draft
**Created**: 2025-12-09

## Summary

The FABER workflow orchestration has multiple critical bugs that prevent workflows from completing successfully: (1) the faber-manager agent stops after the first step in a phase instead of continuing to subsequent steps, (2) resume workflow recommendations don't align with the plan/execute two-phase architecture, (3) command namespace references use incorrect prefixes, and (4) workflow inheritance chain is identified but not properly merged, resulting in empty phase steps.

## Bug Description

### Observed Behavior

1. **Workflow Step Iteration Bug**: During execution of `/fractary-faber:execute`, the faber-manager agent completed `architect:generate-spec` successfully but stopped immediately instead of continuing to `architect:refine-spec`. The spec was created and GitHub comment posted, but the workflow halted.

2. **Resume Architecture Mismatch**: The suggested resume command `/fractary-faber:run --work-id {work_id} --resume {run_id}` doesn't exist. Neither `/fractary-faber:run` nor `/fractary-faber:execute` have `--resume` capability.

3. **Namespace Inconsistency**: Documentation shows wrong command prefixes like `/faber:execute` instead of `/fractary-faber:execute`.

4. **Workflow Inheritance Not Merged**: The plan file shows `inheritance_chain: ["fractary-faber:default", "fractary-faber:core"]` but phase steps are empty arrays. Core workflow steps (issue fetch, branch creation, commit/push, PR creation) are identified but not merged into the execution plan.

### Expected Behavior

1. After `architect:generate-spec` completes, workflow should proceed to `architect:refine-spec`, then continue through remaining phases
2. Resume commands should work with the plan/execute architecture using plan_id or run_id
3. All command references should use correct `fractary-faber:` prefix
4. Workflow inheritance should merge steps from all ancestors (core → default → project) with proper pre_steps/steps/post_steps ordering

### Impact

- **Severity**: High
- **Affected Users**: All users of the FABER workflow system
- **Affected Features**:
  - Complete FABER workflow execution
  - Workflow resume capability
  - Core workflow primitives (issue fetch, branch creation, commits, PRs)
  - Spec refinement user interaction

## Reproduction Steps

1. Create a plan using `/fractary-faber:plan --work-id 323`
2. Execute the plan using `/fractary-faber:execute {plan_id}`
3. Observe workflow stops after `architect:generate-spec`
4. Try to resume using suggested commands - they don't exist

**Frequency**: 100% reproducible
**Environment**: Claude Code with fractary-faber plugin v1.0.0

## Session Transcript Evidence

The following session excerpt demonstrates the exact failure pattern:

```
● fractary-faber:faber-manager(Execute FABER for #323)
  ⎿  Done (28 tool uses · 72.5k tokens · 3m 45s)

● Great! The faber-manager has started and completed the spec generation step.
  It seems to have paused at the spec refinement step...
```

**Key observations from session:**
1. The Task tool invoked `faber-manager` successfully
2. The agent ran for 3m 45s and used 28 tool calls
3. The agent returned with spec-generator output but did NOT continue to the next step
4. The executor then attempted `Agent Output 872031fe` but got "No agent found" error
5. The executor concluded the workflow "stopped early" and marked it "partial"

**This confirms Issue 1**: The faber-manager agent loses execution context after skill completion and exits prematurely, leaving the executor to wonder what happened.

**Additional Evidence - Issue 5 (NEW)**: The session also reveals a **skill invocation error**:
```
● Skill(fractary-faber-agent:faber-executor)
  ⎿  Error: Unknown skill: fractary-faber-agent:faber-executor
```
The executor initially tried `fractary-faber-agent:faber-executor` (incorrect) before finding `fractary-faber:faber-executor` (correct). This suggests inconsistent skill naming or documentation.

## Root Cause Analysis

### Investigation Findings

**Issue 1 - Step Iteration** (REFINED based on user investigation):
- **Primary Observation**: The faber-manager agent was triggered but exited almost immediately, with work being done outside of it
- This suggests the agent is not maintaining execution context through skill invocations
- The faber-manager code DOES include a proper loop over `steps_to_execute` in Section 4.2
- However, the agent appears to lose control after the first skill completes
- **Contributing Factor**: Issue 4 (empty steps from missing merge) meant the spec-generate was effectively the FIRST step, so stopping after it appeared to be "stopping after first step" when in fact it was "stopping after only step"

**Issue 2 - Resume Architecture**:
- Plan ID and Run ID are disconnected entities
- No parameter to reference existing plan from commands
- `--resume` flag doesn't exist on any FABER command

**Issue 4 - Workflow Merge**:
- The `faber-config` skill correctly identifies inheritance chain
- The documented merge algorithm in SKILL.md (lines 156-219) is not executed
- LLM agent copied child workflow structure and added metadata without merging ancestor steps

### Root Cause

1. **Step iteration**: Agent context boundary issue - faber-manager loses execution control after skill invocation completes, causing work to happen "outside" the agent rather than continuing the step loop. The manager's Section 4.2 loop exists but doesn't maintain control through skill boundaries.
2. **Resume**: Commands designed before plan/execute architecture was finalized; bidirectional linking between plan_id and run_id not implemented
3. **Namespace**: Documentation written with assumed short prefix, not updated after plugin naming conventions established
4. **Merge**: LLM-based merge algorithm is non-deterministic; no validation guard to catch incomplete merges

**Important Clarification**: Issues 1 and 4 are **independent bugs** that both manifested during the same test session:
- Issue 4 caused the workflow to have only ONE step (generate-spec) instead of the expected multiple steps
- Issue 1 would cause the workflow to stop after the first step even if multiple steps existed
- Both need to be fixed separately

### Why It Wasn't Caught Earlier

- Multi-step phase execution paths weren't tested end-to-end
- Resume scenarios weren't tested after plan/execute refactor
- Workflow inheritance with multiple ancestors wasn't integration tested
- Documentation review didn't verify command prefixes against actual implementation

## Technical Analysis

### Affected Components

- `plugins/faber/agents/faber-manager.md`: Step iteration logic in Section 4.2
- `plugins/faber/skills/faber-executor/SKILL.md`: Resume workflow documentation
- `plugins/faber/skills/faber-planner/SKILL.md`: Namespace references
- `plugins/faber/commands/execute.md`: Missing --resume flag
- `plugins/faber/commands/run.md`: Missing --plan-id and --resume flags
- `plugins/faber/skills/faber-config/SKILL.md`: Workflow merge algorithm

### Related Code

- `plugins/faber/agents/faber-manager.md:Section 4.2`: Step execution loop
- `plugins/faber/skills/faber-config/SKILL.md:156-219`: Merge algorithm documentation
- `plugins/faber/skills/run-manager/scripts/`: Resume state lookup

## Proposed Fix

### Solution Approach

**Four coordinated fixes:**

1. **Fix Step Iteration**: Add logging/debugging to verify step iteration loop; ensure skill completion triggers next step; investigate Task tool early return

2. **Add Resume Support**: Implement `--resume` flag on `/fractary-faber:execute` that reads plan file, finds associated run state, and spawns faber-manager with resume context

3. **Fix Command Namespaces**: Search and replace all occurrences of `/faber:` with `/fractary-faber:` in documentation

4. **Make Workflow Merge Deterministic**: Create shell script `merge-workflows.sh` using jq for deterministic merge; add validation guard to fail if merged result missing inherited steps

### Code Changes Required

- `plugins/faber/skills/faber-executor/SKILL.md`: Add --resume flag handling, fix namespace
- `plugins/faber/skills/faber-planner/SKILL.md`: Fix namespace references
- `plugins/faber/commands/execute.md`: Add --resume argument documentation
- `plugins/faber/agents/faber-manager.md`: Add step continuation logging, verify iteration logic
- `plugins/faber/skills/faber-config/SKILL.md`: Add explicit merge instructions and validation
- `plugins/faber/skills/faber-config/scripts/merge-workflows.sh` (new): Deterministic merge script
- `plugins/faber/skills/faber-config/scripts/validate-merge.sh` (new): Validation guard

### Why This Fix Works

1. **Step iteration fix**: Ensures all steps in `steps_to_execute` are processed sequentially without early termination
2. **Resume support**: Provides clear path to continue paused workflows using existing plan and state files
3. **Namespace fix**: Users can copy-paste commands from documentation and have them work
4. **Deterministic merge**: Removes LLM variability from critical merge logic; can be unit tested; consistent results

### Alternative Solutions Considered

- **Resume via run_id only**: Rejected because run state is created at execution time, and plans may not yet have been executed
- **Keep LLM-based merge with better prompting**: Rejected because non-deterministic behavior in critical path is unacceptable
- **Separate resume command**: Rejected because it fragments the command interface unnecessarily

## Implementation Plan

### Phase 1: Fix Step Iteration
**Status**: Not Started

**Objective**: Ensure faber-manager completes all steps in a phase before moving to next phase

**Tasks**:
- [ ] Add detailed logging to faber-manager step iteration (Section 4.2)
- [ ] Test Task tool behavior with multi-step agents
- [ ] Verify `steps_to_execute` array is fully iterated
- [ ] Add explicit continuation after each skill completion
- [ ] Test with 2+ steps in architect phase

**Estimated Scope**: Medium

### Phase 2: Fix Workflow Inheritance Merge
**Status**: Not Started

**Objective**: Ensure workflow merge produces complete step lists from inheritance chain

**Tasks**:
- [ ] Create `scripts/merge-workflows.sh` with jq-based merge logic
- [ ] Create `scripts/validate-merge.sh` for post-merge validation
- [ ] Add explicit merge instructions to faber-config SKILL.md
- [ ] Add validation guard: fail if inheritance_chain.length > 1 but steps empty
- [ ] Test two-level inheritance (default extends core)
- [ ] Test skip_steps functionality after merge

**Estimated Scope**: Medium

### Phase 3: Add Resume Support
**Status**: Not Started

**Objective**: Enable workflow resume using plan/execute architecture

**Resume Scope Decision**: Resume from **exact step** (not phase start)
- Resume reconstructs the exact point of interruption (e.g., `architect:refine-spec`)
- Does NOT restart from beginning of phase
- State file tracks `current_phase` and `current_step` for precise resume

**Tasks**:
- [ ] Add `--resume` flag to `/fractary-faber:execute` command
- [ ] Implement plan file reading and run state lookup
- [ ] Add `execution.run_id` field to plan file on execution start
- [ ] Add `plan_id` field to run state metadata
- [ ] Store `current_step` in state (not just `current_phase`)
- [ ] Spawn faber-manager with `is_resume=true` and `resume_context` containing exact step
- [ ] Skip already-completed steps during resume
- [ ] Test resume after spec-refine pause (exact step)
- [ ] Test resume after approval gate pause (exact step)

**Estimated Scope**: Medium-Large

### Phase 4: Fix Command Namespaces
**Status**: Not Started

**Objective**: Ensure all documentation uses correct `fractary-faber:` prefix

**Tasks**:
- [ ] Search for `/faber:` pattern in all FABER plugin files
- [ ] Replace with `/fractary-faber:` prefix
- [ ] Verify executor skill suggested commands
- [ ] Verify planner skill suggested commands
- [ ] Verify faber-manager agent outputs
- [ ] Test that all suggested commands are valid

**Estimated Scope**: Small

## Files to Modify

- `plugins/faber/agents/faber-manager.md`: Add step iteration logging and continuation logic
- `plugins/faber/skills/faber-executor/SKILL.md`: Add --resume flag, fix namespaces
- `plugins/faber/skills/faber-planner/SKILL.md`: Fix namespace references
- `plugins/faber/commands/execute.md`: Add --resume argument
- `plugins/faber/commands/run.md`: Document plan_id linkage
- `plugins/faber/skills/faber-config/SKILL.md`: Add explicit merge instructions
- `plugins/faber/skills/faber-config/scripts/merge-workflows.sh` (new): Deterministic merge
- `plugins/faber/skills/faber-config/scripts/validate-merge.sh` (new): Validation guard
- `plugins/faber/skills/run-manager/scripts/`: Add plan_id ↔ run_id lookup

## Testing Strategy

### Regression Tests

- Verify existing single-step workflows still work
- Verify simple plans without inheritance still execute
- Verify existing state management not broken

### New Test Cases

- **step-iteration-multi-step**: Plan with 2+ steps in architect phase executes all steps
- **spec-refine-pause**: spec-refiner properly pauses and returns control for user questions
- **resume-after-pause**: After spec-refine pause, resume command continues workflow
- **workflow-merge-two-level**: default extends core merges all core steps
- **workflow-merge-skip-steps**: skip_steps removes specified steps after merge
- **namespace-validity**: All suggested commands use correct fractary-faber: prefix

### Manual Testing Checklist

- [ ] Execute plan with multiple architect steps - all execute
- [ ] Trigger spec-refine pause - workflow pauses correctly
- [ ] Resume workflow after pause - continues from correct point
- [ ] Create plan with inheritance - merged steps appear in plan
- [ ] Copy suggested command from output - command works

## Risk Assessment

### Risks of Fix

- **Step iteration changes may affect single-step workflows**: Mitigation: Test single-step scenarios thoroughly
- **Resume state format changes may break existing states**: Mitigation: Add migration for existing states or version the format
- **Deterministic merge script may have edge cases**: Mitigation: Comprehensive test suite for merge scenarios

### Risks of Not Fixing

- FABER workflows cannot complete - only first step of each phase executes
- Users cannot resume paused workflows - must restart from beginning
- Core workflow primitives (issue fetch, branch, PR) never execute
- Documentation misleads users with invalid commands
- Overall FABER system is unusable for real workflows

## Dependencies

- jq command-line tool (for merge-workflows.sh script)
- Existing run-manager state file format
- Existing plan file format

## Acceptance Criteria

- [ ] Multi-step phase executes all steps in order without stopping
- [ ] Workflow with inheritance chain has merged steps from all ancestors
- [ ] `/fractary-faber:execute {plan_id} --resume` continues paused workflow
- [ ] Plan file contains run_id after execution starts
- [ ] Run state contains plan_id reference
- [ ] All documentation uses `fractary-faber:` prefix
- [ ] All suggested commands are valid and functional
- [ ] Validation guard fails if merge produces empty steps from non-empty ancestors

## Prevention Measures

### How to Prevent Similar Bugs

- Add integration tests for multi-step phase execution
- Add integration tests for workflow inheritance scenarios
- Validate command prefixes in CI/CD pipeline
- Test resume scenarios after architecture changes
- Deterministic scripts for critical operations instead of LLM-based

### Process Improvements

- End-to-end workflow testing should be part of PR review for FABER changes
- Documentation PRs should validate command syntax against implementation
- Critical path operations should prefer deterministic scripts over LLM agents

## Implementation Notes

**Updated Priority Assessment**: The four issues are **independent** and can be fixed in parallel:
- Issue 1 (step iteration) - Agent context boundary, causes premature exit regardless of steps present
- Issue 4 (workflow merge) - LLM merge failure, causes empty step lists
- Issue 2 (resume) - Missing command support, prevents recovery
- Issue 3 (namespace) - Documentation inconsistency, causes user confusion

**Recommended Fix Order** (by impact/dependency):
1. **Issue 1 (step iteration)** - Highest priority, core workflow broken
2. **Issue 4 (merge)** - High priority, inherited steps missing
3. **Issue 2 (resume)** - Medium priority, enables recovery from failures
4. **Issue 3 (namespace)** - Low priority, documentation fix only

**Note**: Issue 1 and Issue 4 were initially thought to be related (merge failure → only one step → stops after "first" step). Investigation confirmed they are **independent bugs** that coincidentally manifested together:
- Even with correctly merged steps, Issue 1 would cause the manager to exit after the first skill invocation
- Even with fixed step iteration, Issue 4 would still result in missing core workflow steps

---

## Changelog

### Round 1 (2025-12-09)

**Questions Asked:**
1. Root cause verification for Issue 1 (Task tool vs iteration logic vs context boundary)
2. Resume scope (exact step vs phase start)
3. Bug dependency (Issue 1 independent of Issue 4?)

**Answers Received:**
1. **Root Cause**: Session transcript shows faber-manager exits almost immediately after being triggered, with work happening "outside" the agent. Contributing factor: Issue 4 meant only ONE step existed, so stopping after it looked like "stopping after first step" but was actually "only step completed".
2. **Resume Scope**: Exact step (recommended) - Resume from the exact step that was interrupted
3. **Bug Dependency**: Independent bugs - Both need separate fixes

**Changes Applied:**
- Added session transcript evidence section with key observations
- Refined root cause analysis for Issue 1 (agent context boundary)
- Added clarification that Issues 1 and 4 are independent bugs
- Updated Phase 3 tasks with exact-step resume approach
- Revised implementation notes with updated priority assessment
- Identified potential Issue 5 (skill naming inconsistency)
