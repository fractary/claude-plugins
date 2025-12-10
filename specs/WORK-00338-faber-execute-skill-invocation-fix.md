---
spec_id: WORK-00338-faber-execute-skill-invocation-fix
work_id: 338
issue_url: https://github.com/fractary/claude-plugins/issues/338
title: Fix faber execute command skill invocation
type: bug
status: draft
created: 2025-12-10
refined: 2025-12-10
author: Claude
validated: false
severity: medium
source: conversation+issue
---

# Bug Fix Specification: Fix faber execute command skill invocation

**Issue**: [#338](https://github.com/fractary/claude-plugins/issues/338)
**Type**: Bug Fix
**Severity**: Medium
**Status**: Draft
**Created**: 2025-12-10

## Summary

The `/fractary-faber:execute` command incorrectly attempts to invoke `faber-executor` as an agent using the Task tool, when it is actually defined as a skill. This causes an error ("Agent type 'fractary-faber:faber-executor' not found") and bypasses the critical logic in the faber-executor skill. The command eventually recovers by falling back to the faber-manager agent, but the intended execution orchestration logic is lost.

## Bug Description

### Observed Behavior

When running `/fractary-faber:execute <plan-id>`, the command:
1. Parses arguments correctly
2. Attempts to invoke `fractary-faber:faber-executor` as an **agent** using the Task tool
3. Receives error: "Agent type 'fractary-faber:faber-executor' not found"
4. Recovers by directly invoking `faber-manager` agent
5. Execution proceeds but **bypasses all faber-executor skill logic**

Error message observed:
```
Error: Agent type 'fractary-faber:faber-executor' not found. Available agents:
general-purpose, statusline-setup, Explore, Plan, claude-code-guide,
fractary-codex:codex-manager, fractary-repo:repo-manager, fractary-work:work-manager,
fractary-faber:faber-manager, fractary-faber-cloud:cloud-director,
fractary-faber-cloud:infra-manager, fractary-helm-cloud:ops-manager,
fractary-file:file-manager, fractary-docs:docs-manager, fractary-logs:log-manager,
fractary-spec:spec-manager
```

### Expected Behavior

The `/fractary-faber:execute` command should:
1. Parse arguments
2. Invoke `faber-executor` as a **skill** using the Skill tool
3. The faber-executor skill handles:
   - Loading the plan file
   - Filtering items (if `--items` specified)
   - Loading resume state (if `--resume` specified)
   - Spawning faber-manager agents for each work item
   - Aggregating results
   - Returning execution summary

### Impact

- **Severity**: Medium - Workflow executes but critical orchestration logic is bypassed
- **Affected Users**: All users of `/fractary-faber:execute` command
- **Affected Features**:
  - Plan-based execution
  - Parallel/serial execution control
  - Resume support
  - Results aggregation
  - Worktree cleanup

## Reproduction Steps

1. Create a FABER plan using `/fractary-faber:plan --work-id <issue>`
2. Execute the plan using `/fractary-faber:execute <plan-id>`
3. Observe error message about agent not found
4. Note the fallback to faber-manager bypassing faber-executor logic

**Frequency**: 100% reproducible
**Environment**: Any environment with fractary-faber plugin

## Root Cause Analysis

### Investigation Findings

1. **execute.md command** (line 23, 87-101): Correctly documents using the Skill tool
   ```markdown
   4. **USE SKILL TOOL** - Invoke faber-executor using the Skill tool, NOT Task tool
   ```

2. **execute.md command** (line 87-101): Shows correct invocation pattern
   ```
   Skill(skill="faber-executor")
   ```

3. **faber-executor SKILL.md**: Correctly defined as a skill with appropriate frontmatter:
   ```yaml
   ---
   name: faber-executor
   description: Executes FABER plans by spawning faber-manager agents.
   model: claude-sonnet-4-5
   tools:
     - Task
     - Read
     - Write
     - Bash
     - Glob
     - SlashCommand
   ---
   ```

### Root Cause

The bug is a **behavioral issue** where the LLM executing the command is using the Task tool instead of the Skill tool, despite the command documentation clearly specifying to use Skill tool.

**Key Observation**: The execute.md frontmatter already includes `tools: Skill` (line 6), which should indicate that only the Skill tool is available. However, this constraint is advisory, not enforced by the system. The model is still able to attempt Task tool invocations.

**Primary Causes**:

1. **Model confusion**: The model may be pattern-matching on the workflow description mentioning "faber-manager agent" and incorrectly applying the Task tool pattern
2. **Instruction clarity**: The workflow section may not be emphatic enough about using Skill tool
3. **Missing explicit prohibition**: No explicit statement saying "DO NOT use Task tool for faber-executor"
4. **Frontmatter is advisory**: The `tools: Skill` frontmatter doesn't prevent the model from attempting to use other tools - it's just documentation

**Decision**: This will be addressed purely as an instruction clarity fix. The frontmatter's advisory nature is by design, not a bug to investigate.

### Why It Wasn't Caught Earlier

- The fallback behavior masked the issue - executions appeared to succeed
- The faber-executor skill's value-add (parallel execution, resume, aggregation) wasn't immediately visible when bypassed
- No automated tests verify skill vs agent invocation

## Technical Analysis

### Affected Components

- `plugins/faber/commands/execute.md`: Command that should invoke skill correctly
- `plugins/faber/skills/faber-executor/SKILL.md`: Skill being bypassed

### Related Code

- `plugins/faber/commands/execute.md:87-101`: Skill invocation instructions
- `plugins/faber/commands/execute.md:165-169`: Skill vs Agent documentation
- `plugins/faber/skills/faber-executor/SKILL.md:1-12`: Skill frontmatter

## Proposed Fix

### Solution Approach

Strengthen the execute.md command instructions to prevent the model from incorrectly using Task tool:

1. Add explicit prohibition against using Task tool
2. Add the exact Skill tool invocation syntax
3. Add a warning about the common mistake
4. Reinforce in CRITICAL_RULES section

### Code Changes Required

- `plugins/faber/commands/execute.md`: Strengthen skill invocation instructions

### Why This Fix Works

By making the instructions unambiguous and adding explicit prohibitions, the model will correctly use the Skill tool. The command already documents the correct approach - it just needs stronger reinforcement.

### Alternative Solutions Considered

- **Convert faber-executor to an agent**: Rejected - skills are the correct abstraction for this use case; agents are for workflow orchestration that requires multiple tool invocations
- **Add validation in plugin system**: Rejected - would require system-level changes for a documentation fix

## Implementation Plan

### Phase 1: Fix Command Instructions
**Status**: Not Started

**Objective**: Update execute.md to prevent incorrect invocation

**Tasks**:
- [ ] Add explicit "DO NOT use Task tool" in CRITICAL_RULES
- [ ] Add example of the exact Skill tool call to use
- [ ] Add warning about the common mistake pattern
- [ ] Test the fix manually

**Estimated Scope**: Small (single file edit)

## Files to Modify

- `plugins/faber/commands/execute.md`: Add stronger instructions for skill invocation

## Testing Strategy

### Regression Tests

Verify that existing plan execution still works after the fix.

### New Test Cases

- manual-test-skill-invocation: Verify `/fractary-faber:execute` uses Skill tool not Task tool

### Manual Testing Checklist

- [ ] Create a test plan with `/fractary-faber:plan`
- [ ] Execute with `/fractary-faber:execute <plan-id>`
- [ ] Verify no "Agent type not found" error appears
- [ ] Verify faber-executor skill messages appear in output
- [ ] Verify parallel execution works (multiple items)
- [ ] Verify `--serial` flag works
- [ ] Verify `--resume` flag works

## Risk Assessment

### Risks of Fix

- **Minimal risk**: This is a documentation/instruction fix, no code logic changes

### Risks of Not Fixing

- faber-executor skill logic permanently bypassed
- Parallel execution, resume support, and results aggregation not functioning
- Plan execution less reliable and less observable

## Dependencies

None - this is a self-contained fix to the command instructions.

## Scope Decisions

**Scope**: This fix is limited to `plugins/faber/commands/execute.md` only.

**Rationale**: User confirmed this issue should be addressed in isolation. No audit of other commands is included in this fix. If similar issues are discovered in other commands, they should be filed as separate issues.

## Acceptance Criteria

- [ ] `/fractary-faber:execute` command uses Skill tool to invoke faber-executor
- [ ] No "Agent type not found" error when executing plans
- [ ] faber-executor skill output messages visible during execution
- [ ] Plan status updated correctly by faber-executor
- [ ] Results aggregated and returned by faber-executor

## Prevention Measures

### How to Prevent Similar Bugs

- Add explicit "DO NOT" statements when skills vs agents matter
- Include the exact tool invocation syntax in command documentation
- Add warnings about common mistakes

### Process Improvements

- Consider adding automated tests that verify tool invocation patterns
- Document the Skill vs Task tool distinction more prominently in plugin standards

## Implementation Notes

The key insight is that the command documentation is correct but not emphatic enough. The model executing the command pattern-matches on "agent" mentions in the workflow and incorrectly uses Task tool. The fix is purely instructional - strengthen the documentation to eliminate ambiguity.

### Specific Changes to execute.md

1. In `<CRITICAL_RULES>` add:
   ```markdown
   5. **NEVER USE TASK TOOL** - faber-executor is a SKILL, not an agent. Using Task tool will fail.
   ```

2. In Step 2 of `<WORKFLOW>`, add exact invocation:
   ```markdown
   **EXACT INVOCATION** (copy this exactly):
   Skill(skill="faber-executor")

   DO NOT use: Task(subagent_type="fractary-faber:faber-executor") - THIS WILL FAIL
   ```

3. Add warning section:
   ```markdown
   <WARNING>
   Common Mistake: Do not confuse faber-executor (a skill) with faber-manager (an agent).
   - faber-executor: Skill - invoke with Skill tool
   - faber-manager: Agent - invoked by faber-executor using Task tool
   </WARNING>
   ```

## Changelog

### 2025-12-10: Initial Refinement

**Questions Asked**: 3
**Questions Answered**: 3 (all by user)

**Q&A Summary**:
1. **Root Cause Approach**: Instruction fix only - the frontmatter `tools: Skill` is advisory, not enforced. Address with stronger instructions.
2. **Scope**: This issue only - no audit of other commands included.
3. **Model**: Keep Haiku - the instructions just need to be clearer.

**Refinements Applied**:
- Added clarification that frontmatter `tools` is advisory, not enforced
- Added explicit scope decision to prevent scope creep
- Added refined date to frontmatter
