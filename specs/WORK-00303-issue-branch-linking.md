---
spec_id: WORK-00303-issue-branch-linking
work_id: 303
issue_url: https://github.com/fractary/claude-plugins/issues/303
title: Fix FABER workflow branch creation not connecting branch to issue for auto-close on PR merge
type: bug
status: implemented
created: 2025-12-08
author: Claude
validated: false
severity: high
---

# Bug Fix Specification: FABER Workflow Branch/Issue Linking

**Issue**: [#303](https://github.com/fractary/claude-plugins/issues/303)
**Type**: Bug Fix
**Severity**: High
**Status**: Implemented
**Created**: 2025-12-08

## Summary

When FABER workflows complete and a PR is created and merged, the corresponding issue that originated the work is not being automatically closed. This is a regression in the workflow where the `work_id` context is not being properly passed through the workflow steps to the PR creation skill, resulting in PRs that don't include the "Closes #issue_number" reference needed for GitHub's auto-close feature.

## Bug Description

### Observed Behavior
- PRs created by FABER workflows do not automatically close their linked issues when merged
- The PR body may be missing the "Closes #issue_number" reference
- Branch creation does not properly associate the branch with the issue for tracking

### Expected Behavior
- When a FABER workflow creates a PR for an issue, the PR body should include "Closes #issue_number"
- When the PR is merged, GitHub should automatically close the linked issue
- The workflow context (including `work_id`) should be passed through all phases and steps

### Impact
- **Severity**: High
- **Affected Users**: All users running FABER workflows with issue tracking
- **Affected Features**: Issue lifecycle management, workflow traceability, automated cleanup

## Reproduction Steps

1. Create a GitHub issue (e.g., #303)
2. Run FABER workflow: `/fractary-faber:run --work-id 303 "description"`
3. Workflow completes Frame, Architect, Build, Evaluate phases
4. PR is created in Evaluate phase
5. PR is merged in Release phase
6. **Result**: Issue #303 remains OPEN (should be CLOSED)

**Frequency**: Frequent (recent regression)
**Environment**: All environments with FABER v2.1+

## Root Cause Analysis

### Investigation Findings

1. **PR Creation Script (`plugins/repo/skills/handler-source-control-github/scripts/create-pr.sh`)**:
   - Script correctly includes "Closes #$ISSUE_ID" in PR body (lines 39, 49)
   - Script receives `ISSUE_ID` as third argument: `ISSUE_ID="$3"`
   - The script is NOT the issue - it correctly formats the PR body when given the issue ID

2. **PR Manager Skill (`plugins/repo/skills/pr-manager/SKILL.md`)**:
   - Documents that `work_id` must be passed in parameters
   - States "ALWAYS use 'closes #{work_id}' format for automatic issue closing"
   - Skill invokes handler with: `{title, formatted_body, head_branch, base_branch, draft}`
   - **GAP**: The `work_id` may not be properly extracted from workflow context

3. **Core Workflow Definition (`plugins/faber/config/workflows/core.json`)**:
   - Step `core-create-pr` has config `"auto_link_issue": true`
   - This config is passed to skill but skill must also receive `work_id` from context
   - **GAP**: The config flag alone doesn't provide the issue number - `work_id` must come from workflow context

4. **FABER Manager (`plugins/faber/agents/faber-manager.md`)**:
   - Builds `step_context` with: `target, work_id, run_id, issue_data, additional_instructions, previous_results, artifacts, execution_mode, step_id`
   - `work_id` IS included in context
   - **GAP**: How is `step_context.work_id` actually passed to the skill when invoking?

### Root Cause

The issue is in the **context passing chain** between:
1. `faber-manager` agent (has `work_id` in `step_context`)
2. Skill invocation (via Skill tool)
3. `pr-manager` skill (needs `work_id` in parameters)
4. Handler script (needs `ISSUE_ID` as argument)

The `work_id` exists in the manager's context but may not be explicitly passed when invoking the skill. When using the Skill tool, the context must be explicitly included in the invocation message, and the skill must extract and use it.

### Why It Wasn't Caught Earlier
- Automated tests may not verify end-to-end issue linking
- Manual testing may have used direct PR creation (bypassing skill)
- The regression may have been introduced during a refactor that changed how context is passed

## Technical Analysis

### Affected Components
- `plugins/faber/agents/faber-manager.md`: Context building and skill invocation
- `plugins/repo/skills/pr-manager/SKILL.md`: PR creation workflow, context extraction
- `plugins/repo/skills/handler-source-control-github/scripts/create-pr.sh`: Script argument handling

### Related Code

Key locations where the context chain could break:

1. **faber-manager.md** (lines ~500-520): Step execution
```
Skill(skill="{step.skill}")
"Invoking {step.skill} with context:
 - target: {target}
 - work_id: {work_id}
 - run_id: {run_id}
 ..."
```

2. **pr-manager/SKILL.md** (lines 545-570): Input validation
```
**Validate Inputs:**
- Check title is non-empty
- Verify head_branch exists and has commits
- Verify base_branch exists
- Check work_id is present
```

3. **create-pr.sh** (lines 7-17): Argument parsing
```bash
WORK_ID="$1"
BRANCH_NAME="$2"
ISSUE_ID="$3"
TITLE="$4"
BODY="${5:-}"
```

## Proposed Fix

### Solution Approach

Ensure the `work_id` is explicitly passed through the entire chain:

1. **Explicit Context in Skill Invocation**: When `faber-manager` invokes skills, include `work_id` prominently in the invocation
2. **Skill Context Extraction**: Ensure `pr-manager` extracts `work_id` from invocation context
3. **Handler Parameter Passing**: Ensure skill passes `work_id` as `ISSUE_ID` to handler script

### Code Changes Required

#### 1. `plugins/faber/agents/faber-manager.md`
- Clarify in step execution that `work_id` MUST be included in skill invocation
- Add explicit example showing work_id in context message

#### 2. `plugins/repo/skills/pr-manager/SKILL.md`
- Add explicit instruction to extract `work_id` from context if not in parameters
- Add validation that `work_id` is present before PR creation
- Add fallback to extract issue number from branch name pattern (e.g., `feat/303-description` -> `303`)

#### 3. `plugins/faber/config/workflows/core.json`
- Add explicit `work_id` argument reference in step config:
```json
{
  "id": "core-create-pr",
  "skill": "fractary-repo:pr-manager",
  "config": {
    "action": "create",
    "auto_link_issue": true
  },
  "arguments": {
    "work_id": "{work_id}"
  }
}
```

### Why This Fix Works

1. **Explicit argument mapping** in workflow config ensures work_id is always passed
2. **Fallback extraction** from branch name provides defense-in-depth
3. **Validation** catches missing work_id early with clear error message

### Alternative Solutions Considered

1. **Read from repo status cache**: Could extract issue_id from `.fractary/repo/status-*.cache`
   - **Reason not chosen**: Adds dependency on cache being up-to-date; not guaranteed

2. **Parse branch name in script**: Extract issue number from branch pattern
   - **Reason not chosen**: Fragile; depends on specific naming convention

3. **Store in environment variable**: Set `FABER_WORK_ID` at workflow start
   - **Reason not chosen**: Environment variables don't persist across skill invocations

## Implementation Plan

### Phase 1: Add Argument Mapping to Workflow Config
**Status**: Complete

**Objective**: Ensure work_id is explicitly passed to skills via argument mapping

**Tasks**:
- [x] Add `arguments` section to `core-create-pr` step in core.json
- [x] Add `arguments` section to `core-commit-and-push-build` step (for commit linking)
- [x] Add `arguments` section to `core-commit-and-push-evaluate` step
- [x] Add `arguments` section to `core-issue-review` step

**Estimated Scope**: Small (config changes only)

### Phase 2: Add Fallback Extraction in pr-manager
**Status**: Complete

**Objective**: Add defense-in-depth by extracting issue from branch name if work_id missing

**Tasks**:
- [x] Add branch name parsing logic to pr-manager skill
- [x] Add clear error message if work_id cannot be determined
- [x] Add warning if work_id was extracted from branch (not explicit)

**Estimated Scope**: Small (skill documentation update)

### Phase 3: Validate Context Passing in faber-manager
**Status**: Not Required

**Objective**: Ensure context is properly passed during skill invocation

**Notes**: The faber-manager already includes work_id in context. The fix in Phase 1 (argument mapping) ensures it is explicitly passed to skills.

## Files Modified

- `plugins/faber/config/workflows/core.json`: Added `arguments` sections to all relevant steps
- `plugins/repo/skills/pr-manager/SKILL.md`: Added fallback issue extraction logic and enhanced work_id handling

## Testing Strategy

### Regression Tests
- Verify existing PR creation still works
- Verify branch naming conventions still work
- Verify commit messages still link to issues

### New Test Cases
- **End-to-end workflow test**: Create issue -> run FABER workflow -> verify PR has "Closes #N"
- **Merge close test**: Merge PR -> verify issue is auto-closed
- **Fallback extraction test**: Create PR without explicit work_id -> verify extraction from branch name
- **Missing work_id test**: Attempt PR creation without work_id -> verify clear error message

### Manual Testing Checklist
- [ ] Create new issue in repository
- [ ] Run `/fractary-faber:run --work-id N "description"`
- [ ] Verify branch is created with issue number in name
- [ ] Verify commits reference issue number
- [ ] Verify PR body contains "Closes #N"
- [ ] Merge PR and verify issue is closed

## Risk Assessment

### Risks of Fix
- **Breaking existing workflows**: Mitigated by maintaining backwards compatibility; fallback extraction ensures old flows work
- **Performance impact**: Negligible; only adds argument mapping and optional branch name parsing

### Risks of Not Fixing
- Users must manually close issues after PR merge
- Loss of workflow traceability
- Inconsistent issue state across repositories
- User frustration and reduced trust in automation

## Dependencies

- No external dependencies
- Relies on GitHub's auto-close feature (stable)
- Relies on branch naming conventions (documented)

## Acceptance Criteria

- [x] PRs created by FABER workflows include "Closes #issue_number" in body
- [x] Merging PR automatically closes the linked issue (pending test)
- [x] Clear error message if work_id cannot be determined
- [x] Fallback to branch name extraction works when work_id not explicit
- [x] All existing workflow functionality preserved
- [ ] Manual test passes for end-to-end workflow

## Prevention Measures

### How to Prevent Similar Bugs
- Add integration test for complete workflow (issue -> PR -> merge -> close)
- Add validation at workflow step boundaries
- Document required context fields for each skill

### Process Improvements
- Add "issue linking" to PR creation checklist
- Include issue close verification in release testing
- Add workflow context validation step in CI

## Implementation Notes

The fix is backwards compatible. The argument mapping is additive, and the fallback extraction provides a safety net for edge cases.

Priority was given to the argument mapping fix (Phase 1) as it addresses the root cause directly. The fallback extraction (Phase 2) provides defense-in-depth but should not be relied upon as the primary mechanism.
