---
spec_id: spec-00319-faber-plan-execute-architecture
issue_number: 319
issue_url: https://github.com/fractary/claude-plugins/issues/319
title: FABER Plan/Execute Architecture Issues
type: bug
status: draft
created: 2025-12-09
author: faber-manager
validated: false
severity: high
---

# Bug Fix Specification: FABER Plan/Execute Architecture Issues

**Issue**: [#319](https://github.com/fractary/claude-plugins/issues/319)
**Type**: Bug Fix
**Severity**: High
**Status**: Draft
**Created**: 2025-12-09

## Summary

During execution of `/faber:plan --work-id 271`, several architectural and implementation issues were identified that prevent the two-phase plan/execute model from working correctly. This specification addresses these issues to ensure reliable FABER workflow execution.

## Bug Description

### Observed Behavior

1. **faber-executor Agent Type Not Found**: When the execute command attempted to invoke the `faber-executor` skill via the Task tool, it failed with "Agent type 'fractary-faber:faber-executor' not found"
2. **Workflow File Path Mismatch**: Config references workflows at `.fractary/plugins/faber/workflows/` but actual resolved workflow comes from plugin installation cache
3. **Plan Storage Location Inconsistency**: Plans saved to `logs/fractary/plugins/faber/plans/` which is outside standard `.fractary/` conventions
4. **Two-Phase Architecture Not Fully Wired**: The plan/execute flow breaks when transitioning from plan to execute

### Expected Behavior

1. Execute command should successfully invoke the faber-executor or faber-manager to run plans
2. Workflow resolution should clearly document the precedence (project overrides vs plugin defaults)
3. All workflow artifacts should follow consistent path conventions
4. `/faber:plan` -> `/faber:execute` flow should work end-to-end without manual intervention

### Impact

- **Severity**: High
- **Affected Users**: All users attempting to use FABER two-phase workflow
- **Affected Features**: `/faber:plan`, `/faber:execute`, workflow orchestration

## Reproduction Steps

1. Run `/faber:plan --work-id 271`
2. When prompted to execute, say "Yes"
3. Observe `/faber:execute` command fails to find agent type
4. Manual fallback to `faber-manager` works

**Frequency**: 100% reproducible
**Environment**: Any project using FABER plugin v3.0.0

## Root Cause Analysis

### Investigation Findings

- `faber-executor` is defined as a skill (`plugins/faber/skills/faber-executor/`) not an agent
- Execute command in `plugins/faber/commands/execute.md` tries to invoke via Task tool (for agents)
- The Skill tool should be used instead, or the skill should be registered as an agent

### Root Cause

The execute command's invocation mechanism doesn't match the component registration:
- Skills are invoked via `Skill` tool
- Agents are invoked via `Task` tool or natural language
- `faber-executor` is a skill but execute tries to invoke it as an agent

### Why It Wasn't Caught Earlier

- The plan/execute architecture was designed in spec but implementation diverged
- Testing may have used direct invocation paths that bypassed the command layer

## Technical Analysis

### Affected Components

- `plugins/faber/commands/execute.md`: Uses wrong invocation mechanism
- `plugins/faber/skills/faber-executor/SKILL.md`: Should possibly be an agent
- `plugins/faber/.claude-plugin/plugin.json`: Missing agent registration if faber-executor should be one
- `plugins/faber/skills/faber-planner/SKILL.md`: Plan storage path not standardized

### Related Code

- `plugins/faber/commands/execute.md:~line 50-70`: Task tool invocation attempt
- `plugins/faber/skills/faber-executor/SKILL.md`: Skill definition
- `plugins/faber/.claude-plugin/plugin.json`: Plugin manifest

## Proposed Fix

### Solution Approach

**Option A (Recommended)**: Update execute command to use Skill tool instead of Task tool
- Minimal change, aligns with current skill-based architecture
- Keeps faber-executor as a skill (correct for its role)

**Option B**: Register faber-executor as an agent
- Would require moving to `plugins/faber/agents/`
- Overkill since executor just needs to invoke the manager

**Option C**: Eliminate faber-executor entirely, have execute command invoke faber-manager directly
- Simplest approach
- Already proven to work in manual fallback

### Code Changes Required

1. `plugins/faber/commands/execute.md`: Change from Task tool to Skill tool invocation (Option A) OR direct manager invocation (Option C)
2. `plugins/faber/skills/faber-planner/SKILL.md`: Update plan storage path to `.fractary/logs/faber/plans/`
3. `plugins/faber/docs/CONFIGURATION.md`: Document workflow resolution precedence

### Why This Fix Works

- Using the correct invocation mechanism (Skill tool) matches how skills are designed to be called
- Standardizing paths follows project conventions and makes artifacts discoverable
- Documentation prevents future confusion about workflow resolution

### Alternative Solutions Considered

- **Make faber-executor an agent**: Unnecessary complexity, skills are appropriate for deterministic execution
- **Add agent wrapper around skill**: Adds indirection without benefit

## Implementation Plan

### Phase 1: Fix Execute Command
**Status**: [ ] Not Started

**Objective**: Make `/faber:execute {plan_id}` work correctly

**Tasks**:
- [ ] Analyze execute.md current flow
- [ ] Update to use Skill tool OR direct manager invocation
- [ ] Test with existing plan file

**Estimated Scope**: Small (1-2 files)

### Phase 2: Standardize Plan Storage
**Status**: [ ] Not Started

**Objective**: Use consistent path conventions for plans

**Tasks**:
- [ ] Update faber-planner to save to `.fractary/logs/faber/plans/`
- [ ] Update any path references
- [ ] Optionally migrate existing plans

**Estimated Scope**: Small (1-2 files)

### Phase 3: Document Workflow Resolution
**Status**: [ ] Not Started

**Objective**: Clarify how workflows are resolved

**Tasks**:
- [ ] Document in CONFIGURATION.md
- [ ] Add resolution order: project `.fractary/` > plugin cache > built-in defaults
- [ ] Add examples

**Estimated Scope**: Small (documentation only)

### Phase 4: Clean Up Abandoned Run (Optional)
**Status**: [ ] Not Started

**Objective**: Address the abandoned run for issue #310

**Tasks**:
- [ ] Review run state
- [ ] Either clean up or add resume command

**Estimated Scope**: Small (manual cleanup or small feature)

## Files to Modify

- `plugins/faber/commands/execute.md`: Fix invocation mechanism
- `plugins/faber/skills/faber-planner/SKILL.md`: Update plan storage path
- `plugins/faber/docs/CONFIGURATION.md`: Add workflow resolution documentation
- `plugins/faber/skills/faber-executor/SKILL.md`: Possibly remove if Option C chosen

## Testing Strategy

### Regression Tests

- Ensure `/faber:plan --work-id X` still creates plans correctly
- Ensure `/faber:run --work-id X` still works (single-step mode)

### New Test Cases

- `test_plan_execute_flow`: Create plan, then execute via command
- `test_plan_storage_path`: Verify plans saved to correct location

### Manual Testing Checklist

- [ ] Run `/faber:plan --work-id 319`
- [ ] Approve execution when prompted
- [ ] Verify `/faber:execute` invokes manager successfully
- [ ] Verify plan stored in `.fractary/logs/faber/plans/`
- [ ] Verify workflow runs to completion

## Risk Assessment

### Risks of Fix

- **Path migration breaks existing plans**: Plans in old location won't be found
  - Mitigation: Keep backward compatibility or provide migration

### Risks of Not Fixing

- Two-phase workflow remains broken
- Users must use manual workarounds
- Reduces confidence in FABER automation

## Dependencies

- No external dependencies
- Changes are internal to faber plugin

## Acceptance Criteria

- [ ] `/faber:plan --work-id X` creates plan successfully
- [ ] User approval triggers `/faber:execute {plan_id}`
- [ ] Execute command invokes workflow successfully (no "agent not found" error)
- [ ] Plans stored in `.fractary/logs/faber/plans/` (or documented alternative)
- [ ] Workflow resolution order documented

## Prevention Measures

### How to Prevent Similar Bugs

- Add integration tests for full command flows
- Ensure skill/agent registration matches invocation patterns
- Review specs against implementation before merge

### Process Improvements

- Add "smoke test" step to FABER releases that tests plan/execute flow
- Document component types (skill vs agent) clearly in standards

## Implementation Notes

The fix should prioritize reliability over elegance. Option C (eliminating faber-executor) may be simplest since the manager agent already handles the execution logic. The executor skill was intended as a thin wrapper that may not be necessary.

Consider whether the two-phase model adds value or if `/faber:run` with approval gates is sufficient for most use cases.
