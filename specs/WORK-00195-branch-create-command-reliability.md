---
spec_id: WORK-00195-branch-create-command-reliability
work_id: 195
issue_url: https://github.com/fractary/claude-plugins/issues/195
title: Fix /fractary-repo:branch-create command reliability issues
type: bug
status: draft
created: 2025-12-05
author: jmcwilliam
validated: false
severity: high
source: conversation+issue
---

# Bug Fix Specification: /fractary-repo:branch-create command reliability issues

**Issue**: [#195](https://github.com/fractary/claude-plugins/issues/195)
**Type**: Bug Fix
**Severity**: High
**Status**: Draft
**Created**: 2025-12-05

## Summary

The `/fractary-repo:branch-create` command exhibits inconsistent behavior where it sometimes stops before creating a branch, fails to switch to the created branch, or doesn't update the status line to reflect changes. This makes the command unreliable and confusing for users who cannot determine whether their intended operation completed successfully.

## Bug Description

### Observed Behavior

The command exhibits four distinct failure modes:

1. **Stops after issue fetch**: Command fetches the issue details (work-id) but then stops without creating the branch
2. **Creates but doesn't switch**: Command reports successful branch creation but doesn't checkout/switch to the new branch
3. **Switches but status line not updated**: Branch is created and switched, but the fractary-status custom status line doesn't reflect the change
4. **Intermittent success**: Sometimes all steps complete correctly with no issues

Evidence from issue comments shows:
- Example 1 (issue #194): Command reported success with "Checked Out: Yes" but status line didn't update, leaving user uncertain
- Example 2 (issue #241): Command generated the branch name but stopped, asking user "Would you like me to create this branch now?" instead of proceeding

### Expected Behavior

When invoked (e.g., `/fractary-repo:branch-create --work-id 195`):
1. Fetch issue details from work tracking system
2. Generate semantic branch name from issue title/type
3. **Create the branch in git**
4. **Switch to the newly created branch**
5. **Update the repo status cache** (which drives the status line)
6. **Display clear success confirmation** with branch name

The entire workflow should complete atomically - if any step fails, provide clear error messaging. The status line should immediately reflect the new branch.

### Impact

- **Severity**: High - Core command functionality is unreliable
- **Affected Users**: All users of the fractary-repo plugin
- **Affected Features**: Branch creation workflow, FABER Frame phase (which depends on branch creation), work item tracking integration

## Reproduction Steps

1. Have fractary-repo and fractary-work plugins configured
2. Have an open issue (e.g., #195) in GitHub
3. Run `/fractary-repo:branch-create --work-id 195`
4. Observe inconsistent behavior - sometimes stops, sometimes completes

**Frequency**: Intermittent (occurs approximately 40-60% of the time based on user reports)
**Environment**: Claude Code with fractary plugins, any supported platform (GitHub/GitLab/Bitbucket)

## Root Cause Analysis

### Investigation Findings

Analyzing the command flow reveals multiple potential failure points:

1. **Command layer** (`plugins/repo/commands/branch-create.md`):
   - Uses `model: claude-haiku-4-5` which may be less reliable for complex multi-step orchestration
   - Command is marked as "ONLY A ROUTER" but handles Mode 3 (semantic mode) processing itself via SlashCommand
   - The workflow describes 5 steps but Step 4 says "ACTUALLY INVOKE the Task tool" suggesting prior implementations may not have actually invoked it

2. **Agent layer** (`plugins/repo/agents/repo-manager.md`):
   - Complex mode detection logic (direct/semantic/description)
   - Multi-skill orchestration for semantic mode: branch-namer → branch-manager
   - Optional worktree and spec creation add complexity
   - "semantic mode" requires fetching issue details then proceeding - handoff may fail

3. **Status cache integration**:
   - Status line depends on repo plugin's status cache (`~/.fractary/repo/status-*.cache`)
   - Cache update may not occur if branch creation flow doesn't complete normally
   - Scripts that update cache may not be invoked if agent stops early

### Root Cause

The primary root causes appear to be:

1. **Incomplete semantic mode workflow**: When using `--work-id` only (Mode 3), the command fetches the issue but the handoff to actual branch creation is inconsistent. The command sometimes interprets the issue fetch as "completion" and stops.

2. **Model reliability for orchestration**: Using `claude-haiku-4-5` for the command layer may cause less deterministic execution of multi-step workflows, particularly when the workflow spans multiple tool invocations (SlashCommand for issue fetch → Task tool for agent invocation).

3. **Missing explicit completion checks**: The workflow doesn't verify that each step actually completed before proceeding or reporting success.

4. **Status cache update timing**: The status cache may not be updated if the agent completes branch creation but the hooks don't fire or the cache update script isn't invoked.

### Why It Wasn't Caught Earlier

- Intermittent nature makes it hard to reproduce consistently
- Success cases work perfectly, masking the failure modes
- No integration tests covering the full command → agent → skill → script flow
- Status line is cosmetic, so failures there are less visible than git operation failures

## Technical Analysis

### Affected Components

- `plugins/repo/commands/branch-create.md`: Command entry point, argument parsing, mode detection
- `plugins/repo/agents/repo-manager.md`: Operation routing, skill orchestration, mode handling
- `plugins/repo/skills/branch-manager/SKILL.md`: Actual branch creation
- `plugins/repo/skills/branch-namer/SKILL.md`: Branch name generation for semantic mode
- `plugins/repo/scripts/update-status-cache.sh`: Status cache update (if exists)
- `plugins/status/hooks/hooks.json`: Status line update hooks

### Stack Trace

N/A - This is a workflow/orchestration issue, not a crash.

### Related Code

- `plugins/repo/commands/branch-create.md:48-60`: Semantic mode handling in command layer
- `plugins/repo/commands/branch-create.md:294-397`: Agent invocation examples (reference, not executed)
- `plugins/repo/agents/repo-manager.md:189-209`: Semantic mode detection and processing
- `plugins/repo/agents/repo-manager.md:341-399`: Exit code 10 handling and spec creation flow

## Proposed Fix

### Solution Approach

Implement a multi-pronged fix addressing each failure mode:

1. **Simplify command layer**: Remove Mode 3 preprocessing from command, let agent handle all semantic mode logic
2. **Add explicit completion verification**: Each step must verify completion before proceeding
3. **Ensure atomic status update**: Branch creation skill must update status cache as final step
4. **Add clear success/failure messaging**: Explicit output at each stage

### Code Changes Required

1. **`plugins/repo/commands/branch-create.md`**:
   - Remove Mode 3 (semantic mode) preprocessing - don't fetch issue at command layer
   - Pass `mode: "semantic"` with `work_id` directly to agent
   - Let agent handle entire semantic flow
   - Simplify to pure routing (consistent with "ONLY A ROUTER" mandate)

2. **`plugins/repo/agents/repo-manager.md`**:
   - Add explicit step completion verification
   - For semantic mode: fetch issue → generate name → create branch → checkout → update cache (all steps required)
   - Add explicit "branch created and checked out" confirmation in output
   - Ensure status cache update is part of success criteria

3. **`plugins/repo/skills/branch-manager/SKILL.md`**:
   - Add explicit checkout step after branch creation
   - Add status cache update as final step
   - Return structured response confirming both operations

4. **Add/verify status cache update script**:
   - Ensure `update-status-cache.sh` exists and is invoked
   - Should update: branch name, issue ID, checked_out status
   - Status line should reflect changes immediately

### Why This Fix Works

1. **Single responsibility**: Command only routes, agent orchestrates, skills execute
2. **Explicit verification**: Each step confirms completion before proceeding
3. **Atomic updates**: Status cache is updated as part of branch creation, not separately
4. **Clear feedback**: User sees explicit confirmation of each operation

### Alternative Solutions Considered

- **Use stronger model for command**: Could use `claude-sonnet-4-5` instead of haiku, but doesn't address architectural issues
- **Add retry logic**: Could retry failed steps, but masks underlying issues
- **Separate status update command**: Could require manual status refresh, but poor UX

## Files to Modify

- `plugins/repo/commands/branch-create.md`: Simplify to pure routing, remove Mode 3 preprocessing
- `plugins/repo/agents/repo-manager.md`: Add completion verification, ensure atomic operations
- `plugins/repo/skills/branch-manager/SKILL.md`: Add checkout and cache update to branch creation
- `plugins/repo/skills/branch-manager/scripts/create-branch.sh`: Ensure checkout and cache update
- `plugins/status/scripts/update-status-cache.sh`: Verify/fix cache update script

## Testing Strategy

### Regression Tests

Ensure existing functionality continues to work:
- Mode 1 (direct branch name) still works
- Mode 2 (description-based) still works
- `--worktree` flag still creates worktrees
- `--spec-create` flag still creates specs

### New Test Cases

- `test_semantic_mode_creates_branch`: Verify `--work-id` only creates branch
- `test_semantic_mode_switches_branch`: Verify checkout occurs after creation
- `test_semantic_mode_updates_cache`: Verify status cache updated
- `test_semantic_mode_status_line`: Verify status line reflects change
- `test_branch_already_exists`: Verify exit code 10 handled correctly for spec creation

### Manual Testing Checklist

- [ ] Run `/fractary-repo:branch-create --work-id {id}` 10 times, verify 100% success rate
- [ ] Verify branch is created in git (`git branch --list`)
- [ ] Verify branch is checked out (`git branch --show-current`)
- [ ] Verify status cache is updated (`cat ~/.fractary/repo/status-*.cache`)
- [ ] Verify status line displays correct branch
- [ ] Test with non-existent issue ID (should fail gracefully)
- [ ] Test when branch already exists (should checkout existing, not fail)
- [ ] Test all three modes (direct, description, semantic) in sequence

## Risk Assessment

### Risks of Fix

- **Breaking change to command API**: Low risk - simplifying, not changing API
  - **Mitigation**: Maintain same command arguments, only change internal flow
- **Agent complexity increase**: Medium risk - more explicit verification
  - **Mitigation**: Document clearly, add tests
- **Status cache format changes**: Low risk - cache is internal
  - **Mitigation**: Ensure backward compatibility with existing cache readers

### Risks of Not Fixing

- Users lose trust in plugin reliability
- FABER workflows fail unpredictably at Frame phase
- Manual workarounds needed, defeating purpose of automation
- Increased support burden from user reports

## Dependencies

- fractary-work plugin (for issue fetch in semantic mode)
- fractary-status plugin (for status line display)
- git CLI (for branch operations)
- gh CLI (for GitHub issue fetch)

## Acceptance Criteria

- [ ] `/fractary-repo:branch-create --work-id {id}` creates branch 100% of the time
- [ ] Created branch is automatically checked out
- [ ] Status cache is updated with new branch information
- [ ] Status line reflects the new branch immediately
- [ ] Clear success message shows: branch name, checkout status, cache update status
- [ ] If branch already exists, checkout existing and proceed (for spec creation)
- [ ] If issue not found, fail gracefully with clear error message
- [ ] All three modes (direct, description, semantic) work reliably

## Prevention Measures

### How to Prevent Similar Bugs

- Add integration tests for full command → agent → skill → script flows
- Require explicit completion verification for multi-step workflows
- Use stronger models for complex orchestration if needed
- Add health checks / smoke tests for plugin commands

### Process Improvements

- Document "completion criteria" for each command explicitly
- Add logging/tracing for command execution flow
- Consider adding a `--verbose` flag for debugging
- Regular reliability testing of core commands

## Implementation Notes

### Recommended Implementation Order

1. First, add explicit completion checks to `branch-manager` skill
2. Then, update `repo-manager` agent to verify completions
3. Then, simplify `branch-create` command to remove Mode 3 preprocessing
4. Finally, add/verify status cache update integration

### Key Insight from Issue Comments

The second comment shows a clear case where the agent generated the branch name but asked "Would you like me to create this branch now?" instead of proceeding. This suggests the agent is treating branch name generation as an optional preview step rather than part of an atomic workflow. The fix should make the entire semantic mode flow atomic and automatic.

### Status Cache Integration

The status cache is at `~/.fractary/repo/status-{REPO_ID}.cache` and should contain:
```json
{
  "branch": "feat/195-branch-create-command-reliability",
  "issue_id": "195",
  "repo": "fractary/claude-plugins",
  "updated_at": "2025-12-05T..."
}
```

The status line reads this cache and displays it. Ensuring this cache is updated as part of branch creation will fix the status line issues.
