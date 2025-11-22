# Testing Guide: Issue #165 - FABER Manage Command with Worktree Integration

## Overview

This guide provides steps to test the new `/faber:manage` command and worktree integration implemented in PR #168.

## What Was Implemented

### New Features
1. **`/faber:manage` command** - Replaces `/faber:run` with proper skill-based architecture
2. **Worktree integration** - ALL FABER workflows now use isolated worktrees
3. **Registry-based reuse** - Worktrees are tracked and reused across workflow restarts
4. **Multi-item support** - Execute workflows for multiple work items in parallel

### Architecture Improvements
1. **3-layer architecture compliance** - Extracted ~50 lines of inline bash to 3 focused scripts
2. **Context efficiency** - Reduced token usage by ~2K tokens per workflow execution
3. **Input validation** - Comprehensive validation for work IDs (max 20, format checks, etc.)
4. **Working directory management** - Clear documentation of CWD transitions through phases

## Prerequisites

1. FABER plugin initialized: `/fractary-faber:init`
2. Work plugin configured with GitHub/Jira/Linear
3. Repo plugin configured with GitHub/GitLab/Bitbucket
4. Test repository with issues/work items

## Test Cases

### TC1: Basic Single Work Item Workflow

**Objective**: Verify `/faber:manage` executes complete workflow with worktree isolation

**Steps**:
1. Run: `/faber:manage 123` (replace 123 with valid work item ID)
2. Observe Frame phase creates worktree in `.worktrees/feat-123-*`
3. Verify workflow executes in worktree directory
4. Check registry: `cat ~/.fractary/repo/worktrees.json`
5. Verify worktree entry exists with `work_id: "123"`

**Expected Results**:
- Worktree created at `.worktrees/feat-123-{description-slug}`
- Working directory switches to worktree after Frame phase
- Registry contains entry mapping `123` → worktree path
- State file created at `.worktrees/feat-123-*/fractary/plugins/faber/state.json`

### TC2: Worktree Reuse on Workflow Restart

**Objective**: Verify restarting workflow reuses existing worktree

**Steps**:
1. Start workflow: `/faber:manage 124`
2. Pause workflow (Ctrl+C or let it pause at Release)
3. Note the worktree path from registry
4. Restart workflow: `/faber:manage 124` (same work ID)
5. Verify it reuses the same worktree path

**Expected Results**:
- Console shows: "✅ Found existing worktree for work_id 124"
- Same worktree path used (not a new one created)
- Registry `last_used` timestamp updated
- Workflow continues from previous state

### TC3: Multi-Item Parallel Execution

**Objective**: Verify parallel workflow execution for multiple work items

**Steps**:
1. Run: `/faber:manage 100,101,102` (comma-separated, no spaces)
2. Observe 3 parallel faber-manager agents launched
3. Check that 3 separate worktrees created
4. Verify each workflow is isolated

**Expected Results**:
- 3 worktrees created: `.worktrees/feat-100-*`, `.worktrees/feat-101-*`, `.worktrees/feat-102-*`
- Registry contains 3 entries (work_ids: 100, 101, 102)
- Each workflow executes independently without interference
- All 3 workflows complete successfully

### TC4: Input Validation

**Objective**: Verify comprehensive input validation catches errors

**Test Cases**:

**TC4.1: Space-separated IDs (should fail)**
```bash
/faber:manage 123 124 125
```
Expected: Error message suggesting comma-separated format

**TC4.2: Invalid characters**
```bash
/faber:manage 123!@#
```
Expected: Error showing valid format pattern

**TC4.3: Too many items (>20)**
```bash
/faber:manage 1,2,3,...,25  # 25 items
```
Expected: Error message about 20-item limit with batch suggestion

**TC4.4: Empty work ID**
```bash
/faber:manage
```
Expected: Error showing usage syntax

**TC4.5: Empty entries in list**
```bash
/faber:manage 123,,125
```
Expected: Error about empty entries with correct format example

### TC5: Long Branch Name Handling

**Objective**: Verify truncation works for very long branch names

**Steps**:
1. Create work item with very long title (>80 characters)
2. Run: `/faber:manage {work_id}`
3. Check created worktree path length

**Expected Results**:
- Branch slug truncated to 70 chars
- 8-character hash appended for uniqueness
- Example: `feat-123-very-long-branch-name-that-exceeds-eighty-characters-in--a1b2c3d4`
- Worktree path stays under filesystem limits

### TC6: Working Directory Transitions

**Objective**: Verify working directory changes correctly through phases

**Steps**:
1. Note current directory: `pwd`
2. Run: `/faber:manage 125`
3. After Frame phase, verify: `pwd` shows `.worktrees/feat-125-*`
4. Let workflow complete through all phases
5. Verify directory remains in worktree throughout

**Expected Results**:
- Start: `/path/to/repo`
- After Frame: `/path/to/repo/.worktrees/feat-125-description`
- After Build: Still in worktree
- After Release: Still in worktree
- Worktree persists after completion (for review/cleanup)

### TC7: Worktree Cleanup

**Objective**: Verify worktree cleanup after PR merge

**Steps**:
1. Complete workflow for work item 126
2. Merge PR: `/repo:pr-merge 126 --worktree-cleanup`
3. Check worktree directory removed
4. Verify registry entry removed

**Expected Results**:
- Worktree directory `.worktrees/feat-126-*` deleted
- Registry entry for `126` removed
- Main repository working directory restored

### TC8: Configuration Loading

**Objective**: Verify command loads configuration from correct location

**Steps**:
1. Check configuration exists: `cat .fractary/plugins/faber/config.json`
2. Run: `/faber:manage 127`
3. Verify workflow uses configuration values (autonomy, workflow ID)

**Expected Results**:
- Configuration loaded from `.fractary/plugins/faber/config.json` (NOT `.faber.config.toml`)
- Workflow uses default workflow from config
- Autonomy level matches config setting

### TC9: Deprecation Warning

**Objective**: Verify old `/faber:run` command shows deprecation warning

**Steps**:
1. Run: `/faber:run 128` (old command)
2. Check for deprecation notice

**Expected Results**:
- Warning displayed about deprecation
- Suggests using `/faber:manage` instead
- Workflow still executes (backward compatibility)

## Script Testing

### Test Script Syntax

```bash
# Verify all scripts are syntactically valid
bash -n plugins/repo/skills/branch-manager/scripts/check-worktree.sh
bash -n plugins/repo/skills/branch-manager/scripts/register-worktree.sh
bash -n plugins/repo/skills/branch-manager/scripts/create-worktree.sh
```

### Test Registry Operations

```bash
# View current registry
cat ~/.fractary/repo/worktrees.json | jq '.'

# Check specific work_id
cat ~/.fractary/repo/worktrees.json | jq '.["123"]'

# Clear registry (for testing)
echo '{}' > ~/.fractary/repo/worktrees.json
```

### Test Worktree Listing

```bash
# List all active worktrees
git worktree list

# Check specific worktree exists
ls -la .worktrees/
```

## Verification Checklist

After running tests, verify:

- [ ] All test cases passed
- [ ] Worktrees created in `.worktrees/` subfolder (not parallel directory)
- [ ] Registry at `~/.fractary/repo/worktrees.json` contains correct entries
- [ ] Working directory transitions work correctly
- [ ] Input validation catches all error cases
- [ ] Scripts execute without errors
- [ ] Integration flow works: command → skill → agent → scripts
- [ ] Context efficiency improvement realized (~2K tokens saved)
- [ ] Backward compatibility maintained (`/faber:run` still works)

## Troubleshooting

### Worktree Already Exists Error

If you see "fatal: 'path' is already checked out at 'other-path'":
- Remove stale worktree: `git worktree remove <path> --force`
- Clear registry entry: `jq 'del(.["{work_id}"])' ~/.fractary/repo/worktrees.json`

### Registry Corruption

If registry becomes corrupted:
```bash
# Backup current registry
cp ~/.fractary/repo/worktrees.json ~/.fractary/repo/worktrees.json.bak

# Reset registry
echo '{}' > ~/.fractary/repo/worktrees.json

# Rebuild from active worktrees
git worktree list
# Manually re-register each active worktree
```

### CWD Not Switching to Worktree

If working directory doesn't switch:
- Check Frame phase completed successfully
- Verify branch-manager received `worktree: true` parameter
- Check scripts have execute permissions: `chmod +x plugins/repo/skills/branch-manager/scripts/*.sh`

## Performance Metrics

Expected performance improvements:
- **Context usage**: ~2K tokens saved per workflow execution
- **Concurrent workflows**: Multiple workflows can run simultaneously without interference
- **Workflow resume**: Instant resume using existing worktree
- **Cleanup**: Manual cleanup required after PR merge (use `--worktree-cleanup` flag)

## Success Criteria

Implementation is successful if:
1. All test cases pass
2. No regression in existing FABER workflows
3. Worktrees are properly isolated and reused
4. Input validation prevents invalid operations
5. Scripts execute deterministically outside LLM context
6. Integration flow is clean: command → skill → agent → scripts
7. Documentation is clear and complete

## Next Steps

After testing:
1. Document any issues found in PR #168
2. Verify fixes for any issues
3. Approve PR for merge
4. Update main branch
5. Monitor production usage for edge cases

---

**Created**: 2025-11-22
**Issue**: #165
**PR**: #168
**Author**: Claude Code
