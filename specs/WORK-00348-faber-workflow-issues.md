---
spec_id: WORK-00348-faber-workflow-issues
issue_number: 348
issue_url: https://github.com/fractary/claude-plugins/issues/348
title: FABER workflow execution issues - missing user prompts, issue comments, and result handling
type: bug
status: draft
created: 2025-12-10
author: faber-planner
validated: false
severity: high
refinement_rounds: 1
last_refined: 2025-12-10
---

# Bug Fix Specification: FABER Workflow Execution Issues

**Issue**: [#348](https://github.com/fractary/claude-plugins/issues/348)
**Type**: Bug Fix
**Severity**: High
**Status**: Draft
**Created**: 2025-12-10

## Summary

During execution of FABER workflows, several expected behaviors are not occurring:
1. spec-refiner doesn't stop to ask user questions (proceeds without input)
2. spec-generator doesn't post comments to issues when specs are created
3. Phase completion comments are not being posted by faber-manager
4. Default result handling allows warnings to pass silently

These issues were discovered during execution of issue #335 and represent fundamental gaps in FABER's interactive and tracking capabilities.

## Bug Description

### Observed Behavior

1. **spec-refiner proceeds without user input**: The skill never invokes AskUserQuestion at all. Rule #10 ("NEVER block on unanswered questions - make best-effort decisions") was misinterpreted during implementation. The **intended behavior** was: "If user is prompted and elects not to answer, proceed with best-effort decisions" - but the user must be given the option to respond first. Currently, questions are never presented.

2. **spec-generator doesn't comment**: The GitHub comment is conditional on config (`integration.update_issue_on_create`). Without explicit config, commenting is silently skipped.

3. **Phase completion comments missing**: Only "Workflow Started" comment exists. No comments for Frame, Architect, Build, or Evaluate phase completions. The faber-manager Step 4.3 (Post-Phase Actions) is either not being reached or failing silently.

4. **Warnings treated as success**: Default `on_warning: "continue"` means even critical warnings (like "No user answers provided") are logged but don't halt execution.

### Expected Behavior

1. spec-refiner should halt workflow and wait for user input when questions are generated
2. spec-generator should post issue comments by default (without requiring config)
3. faber-manager should post a comment after EACH phase completes (not just workflow end)
4. User-input steps should have explicit result handling that prompts on warnings

### Impact
- **Severity**: High
- **Affected Users**: All users running FABER workflows
- **Affected Features**: spec-refiner, spec-generator, faber-manager phase tracking, FABER result handling

## Reproduction Steps

1. Create an issue with some requirements that need clarification
2. Run `/fractary-faber:run --work-id <issue-id>`
3. Observe that spec-refiner proceeds without asking questions
4. Check the GitHub issue - no phase completion comments posted
5. Review workflow output - warnings logged but execution continued

**Frequency**: Always (100% reproducible)
**Environment**: All environments with FABER workflow execution

## Root Cause Analysis

### Investigation Findings

The issue analysis in #348 identified specific code locations and configuration dependencies:

1. **spec-refiner SKILL.md** has contradictory critical rules:
   - Rule #5: "ALWAYS use AskUserQuestion tool to present questions in CLI"
   - Rule #10: "NEVER block on unanswered questions - make best-effort decisions"

2. **generate-from-context.md Step 15** has config-dependent commenting:
   ```
   If work_id is provided AND integration.update_issue_on_create is true in config
   ```

3. **faber-manager.md Step 4.3** (Post-Phase Actions) should post comments after each phase but evidence shows it's not being executed consistently.

4. **Default result_handling** in faber-manager allows warnings to pass:
   ```
   on_success: "continue"
   on_warning: "continue"  // Log warning, proceed to next step
   on_failure: "stop"
   ```

### Root Cause

Multiple causes:
1. **Misinterpreted Rule #10**: spec-refiner's Rule #10 was meant to handle "user prompted but didn't answer" scenario, but implementation treats it as "don't prompt at all". The skill never calls AskUserQuestion.
2. **Config dependency**: Commenting requires explicit config that may not exist
3. **Execution path issue**: Post-phase actions either not reached or failing silently
4. **Missing status type**: No `pending_input` status to explicitly halt for user input when needed

### Why It Wasn't Caught Earlier

- Workflows executed without requiring user interaction (happy path)
- Phase comments were optional/config-dependent, so absence wasn't flagged
- Warning logs were ignored in favor of overall success status
- No end-to-end test for interactive workflows

## Technical Analysis

### Affected Components
- `plugins/spec/skills/spec-refiner/SKILL.md`: Conflicting critical rules
- `plugins/spec/skills/spec-generator/workflow/generate-from-context.md`: Config-dependent commenting
- `plugins/faber/agents/faber-manager.md`: Post-phase actions, result handling
- `plugins/faber/docs/RESPONSE-FORMAT.md`: Missing `pending_input` status

### Stack Trace
```
Not applicable - logical/behavioral bug, not runtime error
```

### Related Code
- `plugins/spec/skills/spec-refiner/SKILL.md:CRITICAL_RULES`: Rules #5 and #10 conflict
- `plugins/spec/skills/spec-generator/workflow/generate-from-context.md:Step 15`: Conditional commenting
- `plugins/faber/agents/faber-manager.md:Step 4.3`: Post-Phase Actions section
- `plugins/faber/agents/faber-manager.md:result_handling`: Default warning behavior

## Proposed Fix

### Solution Approach

Implement a multi-pronged fix addressing each root cause:

1. **Add `pending_input` status to FABER response format** - New status that explicitly halts workflow for user input
2. **Fix spec-refiner to actually call AskUserQuestion** - Clarify Rule #10's intent (proceed with best-effort AFTER user has been prompted, not instead of prompting), ensure AskUserQuestion is invoked, return `pending_input` when waiting for user
3. **Make issue commenting mandatory** - Always post phase completion comments (no config dependency)
4. **Fix phase completion comment posting** - Debug and fix faber-manager Step 4.3
5. **Add explicit result_handling for user-input steps** - Override default `on_warning: "continue"` for refine-spec

### Code Changes Required
- `plugins/faber/docs/RESPONSE-FORMAT.md`: Add `pending_input` status documentation
- `plugins/spec/skills/spec-refiner/SKILL.md`: Clarify Rule #10 intent, ensure AskUserQuestion is called, add `pending_input` response
- `plugins/spec/skills/spec-generator/workflow/generate-from-context.md`: Make commenting mandatory (always post when work_id present)
- `plugins/faber/agents/faber-manager.md`: Fix Step 4.3, add `pending_input` handling, ensure phase comments always posted
- `plugins/faber/config/` or workflow definitions: Add `result_handling` for refine-spec step

### Why This Fix Works

1. `pending_input` status provides clear semantics for "halt and wait"
2. Clarifying Rule #10 and ensuring AskUserQuestion is called means users get prompted (the intended behavior)
3. Mandatory commenting ensures consistent tracking regardless of config - stakeholders always see progress
4. Fixing Step 4.3 ensures phase completion visibility
5. Explicit result_handling prevents warnings from being silently ignored

### Alternative Solutions Considered
- **Add config option for blocking behavior**: Rejected - increases complexity, defaults should work correctly
- **Add hooks for user prompts**: Rejected - adds indirection without solving root cause
- **Log-only approach**: Rejected - doesn't solve the fundamental user interaction issue

## Implementation Plan

### Phase 1: FABER Response Format Update
**Status**: Not Started

**Objective**: Add `pending_input` status to FABER response format

**Tasks**:
- [ ] Document `pending_input` status in RESPONSE-FORMAT.md
- [ ] Define semantics: when to use, what faber-manager should do
- [ ] Add examples for skill implementers

**Estimated Scope**: Small (documentation only)

### Phase 2: spec-refiner Fix
**Status**: Not Started

**Objective**: Fix spec-refiner to actually prompt users before making best-effort decisions

**Tasks**:
- [ ] Clarify Rule #10 in SKILL.md: "NEVER block on unanswered questions" means "after prompting, if user elects not to answer, proceed" - NOT "don't prompt at all"
- [ ] Ensure the skill workflow actually invokes AskUserQuestion before proceeding
- [ ] Update OUTPUTS section to show `pending_input` response format for when waiting for user
- [ ] Add explicit step in workflow: "Present questions via AskUserQuestion, THEN if user doesn't answer all, make best-effort decisions"
- [ ] Test that questions are presented and workflow only proceeds after user responds (or explicitly skips)

**Estimated Scope**: Medium

### Phase 3: spec-generator Fix
**Status**: Not Started

**Objective**: Make issue commenting mandatory (always post when work_id present)

**Tasks**:
- [ ] Update generate-from-context.md Step 15 to ALWAYS post comment when work_id is present
- [ ] Remove the `integration.update_issue_on_create` config dependency for basic spec creation comment
- [ ] Keep detailed/verbose step-level comments as optional (config-controlled) if desired
- [ ] Ensure comment includes spec path and summary

**Estimated Scope**: Small

### Phase 4: faber-manager Phase Comments Fix
**Status**: Not Started

**Objective**: Ensure phase completion comments are ALWAYS posted (mandatory, not config-dependent)

**Tasks**:
- [ ] Make phase completion comments mandatory in faber-manager (Critical Rule #11 already exists - enforce it)
- [ ] Fix execution path to ensure Step 4.3 (Post-Phase Actions) runs after each phase
- [ ] Verify comment-creator skill is invoked correctly with run_id for traceability
- [ ] Remove any config dependencies for basic phase milestone comments
- [ ] Test with full workflow execution - verify comments appear after Frame, Architect, Build, Evaluate, Release

**Estimated Scope**: Medium

### Phase 5: faber-manager pending_input Handling
**Status**: Not Started

**Objective**: Handle `pending_input` status correctly

**Tasks**:
- [ ] Add `pending_input` to status handling in faber-manager
- [ ] Save workflow state on `pending_input`
- [ ] Notify user of pending questions
- [ ] Provide resume command

**Estimated Scope**: Medium

### Phase 6: Workflow result_handling Update
**Status**: Not Started

**Objective**: Add explicit result handling for user-input steps

**Tasks**:
- [ ] Update default workflow definition with result_handling for refine-spec
- [ ] Set `on_warning: "prompt"` for steps requiring user input
- [ ] Document in workflow configuration guide

**Estimated Scope**: Small

## Files to Modify

- `plugins/faber/docs/RESPONSE-FORMAT.md`: Add `pending_input` status
- `plugins/spec/skills/spec-refiner/SKILL.md`: Remove Rule #10, add `pending_input` response
- `plugins/spec/skills/spec-generator/workflow/generate-from-context.md`: Make commenting mandatory
- `plugins/faber/agents/faber-manager.md`: Fix Step 4.3, add `pending_input` handling
- `plugins/faber/skills/faber-manager/workflow/*.md`: Update any phase-specific workflows
- `plugins/faber/config/workflows/default.json`: Add result_handling for refine-spec (if workflow config exists)

## Testing Strategy

### Regression Tests
- Existing FABER workflow tests should still pass
- Specs should still be generated successfully
- Phase transitions should work as before

### New Test Cases
- test_spec_refiner_halts_for_input: Verify spec-refiner returns `pending_input` and workflow halts
- test_spec_generator_comments: Verify comments posted without explicit config
- test_phase_completion_comments: Verify comment posted after each phase
- test_pending_input_workflow_state: Verify workflow state saved on `pending_input`

### Manual Testing Checklist
- [ ] Run `/fractary-faber:run` on an issue requiring clarification
- [ ] Verify spec-refiner presents questions and waits
- [ ] Verify spec-generator posts comment to issue
- [ ] Verify phase completion comments appear on issue
- [ ] Verify workflow can resume after user provides input
- [ ] Verify warning handling works as expected with new result_handling

## Risk Assessment

### Risks of Fix
- **Breaking existing workflows**: Mitigation - `pending_input` is additive, doesn't break existing statuses
- **Increased workflow interruptions**: Mitigation - Only occurs when user input genuinely needed
- **Comment spam on issues**: Mitigation - Keep detailed comments config-controlled, only mandatory for phase milestones

### Risks of Not Fixing
- Users don't get prompted for critical decisions
- Workflow tracking is invisible (no phase comments)
- Warnings are silently ignored leading to incomplete implementations
- FABER appears unreliable/unpredictable

## Dependencies

- No external dependencies
- Changes are self-contained within fractary plugins
- No database or infrastructure changes required

## Acceptance Criteria

- [ ] spec-refiner halts workflow and waits for user input when questions are generated
- [ ] spec-generator posts comment to issue when spec is created (without requiring config)
- [ ] faber-manager posts phase completion comment after EACH phase completes
- [ ] `pending_input` status is documented in FABER response format
- [ ] Default workflow has appropriate `result_handling` for user-input steps
- [ ] Issue #335 workflow execution (or similar) shows all expected comments

## Prevention Measures

### How to Prevent Similar Bugs
- Review critical rules for conflicts during skill development
- Make sensible defaults - don't require config for basic functionality
- Add end-to-end tests for interactive workflows
- Test warning paths, not just success paths

### Process Improvements
- Add "rule conflict check" to skill review process
- Default config should enable all tracking features
- Add integration tests that verify issue comments are posted

## Implementation Notes

The issue analysis in #348 is thorough and provides excellent guidance. The proposed solutions are well-thought-out. Implementation should follow the phases in order, as later phases depend on earlier ones (e.g., `pending_input` handling requires the status to be documented first).

Key insight: The root cause is primarily **misinterpreted intent** (Rule #10 meant "proceed if user doesn't answer after being prompted", not "don't prompt") and **over-reliance on configuration** (commenting should just work). The fixes align with the FABER principle of "sensible defaults."

---

## Changelog

### Round 1 - 2025-12-10

**Questions Asked**: 4
**Questions Answered**: 4

**Q&A Summary**:

1. **Root Cause Clarification**: Confirmed that the actual bug is AskUserQuestion never being called, not a rule conflict. Rule #10's intent was "if user prompted and doesn't answer, proceed" - but user must be given option first.

2. **Status Type Approach**: User chose "Both changes" - add `pending_input` status AND fix the AskUserQuestion invocation issue.

3. **Debug vs Fix**: User chose "Proceed with fixes" - no need to instrument/debug first.

4. **Mandatory Comments**: User chose "Always posted" - phase completion comments should be mandatory, no config needed.

**Changes Applied**:
- Clarified root cause from "conflicting rules" to "misinterpreted Rule #10 leading to AskUserQuestion never being called"
- Updated Phase 2 tasks to focus on ensuring AskUserQuestion is invoked before best-effort decisions
- Updated Phase 3 and Phase 4 to make commenting mandatory (always post when work_id present)
- Refined "Why This Fix Works" section to reflect clarified understanding
