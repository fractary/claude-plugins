---
spec_id: WORK-00260-status-cache-pr-persistence
work_id: 260
issue_url: https://github.com/fractary/claude-plugins/issues/260
title: Fix status cache PR number persistence after branch switch
type: bug
status: draft
created: 2025-12-07
author: fractary
validated: false
severity: medium
source: conversation+issue
---

# Bug Fix Specification: Status Cache PR Persistence

**Issue**: [#260](https://github.com/fractary/claude-plugins/issues/260)
**Type**: Bug Fix
**Severity**: Medium
**Status**: Draft
**Created**: 2025-12-07

## Summary

The fractary-repo status cache incorrectly persists the PR number from a previous branch after switching to a different branch (e.g., `main`). This occurs because:

1. **Branch switch issue**: The cache update logic uses the old cached PR number during the current run while asynchronously fetching the new (or empty) PR number for the next run.
2. **PR merge issue**: The `/repo:pr-merge` command does not clear the PR number from the cache after successful merge, leaving stale data even when staying on the same branch.

This causes confusion in the status line and could lead to incorrect PR-related operations.

## Bug Description

### Observed Behavior

After completing work on an issue branch (e.g., `fix/123-some-bug`), merging the PR, deleting the branch, and switching back to `main`:
1. The status cache continues to show the merged PR number (e.g., PR #45)
2. The status line displays stale PR information
3. The cached PR number persists until the next branch switch or cache refresh

### Expected Behavior

When switching to a branch that has no associated PR (like `main` or a new feature branch):
1. The PR number should be cleared immediately or show empty
2. The status line should not display PR information for `main`
3. Operations that check PR status should not find a stale PR

### Impact

- **Severity**: Medium
- **Affected Users**: All users of fractary-repo plugin with status line enabled
- **Affected Features**:
  - Status line display showing incorrect PR
  - Potential interference with PR-related commands that check cache
  - User confusion about current work context
  - Starting new work on same branch after merge shows old PR

## Reproduction Steps

### Scenario A: Branch Switch (Original Issue)
1. Create a feature branch linked to an issue: `/repo:branch-create --work-id 123`
2. Make commits and push to create a PR
3. Wait for status cache to update (shows PR number)
4. Merge the PR on GitHub
5. Delete the remote and local branch
6. Switch to `main`: `git checkout main`
7. Observe the status line still shows the old PR number
8. Start a new session or run `/repo:branch-create --work-id 456`
9. The old PR number may still appear briefly or interfere with operations

### Scenario B: PR Merge via CLI (Additional Issue)
1. Create a feature branch: `/repo:branch-create --work-id 123`
2. Make commits and push to create a PR
3. Wait for status cache to update (shows PR number, e.g., PR #45)
4. Merge the PR via CLI: `/repo:pr-merge 45 --delete-branch`
5. Merge completes successfully
6. Status cache still shows `pr_number: "45"` (WRONG - PR is merged)
7. If user continues working on same branch or starts new work, stale PR appears

**Frequency**: Always reproducible
**Environment**: Any environment with fractary-repo plugin v1.x

## Root Cause Analysis

### Investigation Findings

The bug is located in `plugins/repo/scripts/update-status-cache.sh` at lines 186-229.

The cache update logic has a race condition in how it handles PR number refresh:

```bash
# Lines 186-229: PR number handling
if [ "$BRANCH" != "$CACHED_BRANCH" ] || [ -z "$CACHED_PR_NUMBER" ]; then
    # If we don't have a PR number yet, use cached one temporarily
    if [ -z "$PR_NUMBER" ]; then
        PR_NUMBER="$CACHED_PR_NUMBER"  # BUG: Uses OLD PR number
    fi
    # ... async lookup starts but results are for NEXT run
else
    PR_NUMBER="$CACHED_PR_NUMBER"  # Reuses cached
fi
```

### Root Cause

The async PR lookup optimization (added for performance) creates a one-run delay:

1. **Run N** (on old branch): Cache has `branch: "feat/123-bug"`, `pr_number: "45"`
2. **Run N+1** (just switched to `main`):
   - `BRANCH="main"` ≠ `CACHED_BRANCH="feat/123-bug"` → triggers refresh
   - No PR cache exists for `main` yet, so `PR_NUMBER=""`
   - Falls back: `PR_NUMBER="$CACHED_PR_NUMBER"` → **Uses "45"!**
   - Async lookup finds no PR for `main`, stores empty in `pr-*.cache`
   - Main cache is written with `pr_number: "45"` (WRONG)
3. **Run N+2**: Async result from Run N+1 is now available, PR shows empty

The optimization assumes a one-run delay is acceptable, but this violates user expectations when switching branches.

### Why It Wasn't Caught Earlier

1. The async optimization was added to avoid blocking the status update on slow `gh pr view` calls
2. Testing focused on PR detection working, not on PR clearing
3. The one-run delay is subtle and often masked by subsequent cache updates
4. The scenario of "merge PR, delete branch, switch to main" wasn't explicitly tested

## Technical Analysis

### Affected Components

- `plugins/repo/scripts/update-status-cache.sh`: Main cache update logic with PR handling bug
- `plugins/repo/scripts/read-status-cache.sh`: Reads cached values (no changes needed)
- `plugins/repo/skills/handler-source-control-github/scripts/merge-pr.sh`: Does not clear cache after merge
- Status line display: Shows stale PR (consequence, not cause)

### Related Code

- `plugins/repo/scripts/update-status-cache.sh:155-229`: PR number lookup and caching
- `plugins/repo/scripts/update-status-cache.sh:186-189`: The fallback to cached PR number
- `plugins/repo/scripts/update-status-cache.sh:197-225`: Async background PR lookup
- `plugins/repo/skills/handler-source-control-github/scripts/merge-pr.sh:201-213`: Success output (missing cache clear)

## Proposed Fix

### Solution Approach

This fix has two parts addressing the two root causes:

---

#### Part 1: Clear PR on Branch Change (in update-status-cache.sh)

When the branch changes, immediately clear the PR number instead of using the cached value:

```bash
if [ "$BRANCH" != "$CACHED_BRANCH" ]; then
    # Branch changed - clear PR number, don't carry over from old branch
    PR_NUMBER=""
    # Start async lookup for new branch
    # ... async code ...
elif [ -z "$CACHED_PR_NUMBER" ]; then
    # Same branch but no PR yet - start async lookup
    # ... async code ...
else
    # Same branch with existing PR - reuse cached
    PR_NUMBER="$CACHED_PR_NUMBER"
fi
```

This ensures:
- Branch change → PR cleared immediately
- Same branch, no PR → async lookup starts
- Same branch, has PR → reuse cached (fast)

---

#### Part 2: Clear PR Cache After Merge (in merge-pr.sh)

After successful PR merge, proactively clear the PR number from the status cache:

```bash
# After successful merge (before JSON output)
# Clear PR from status cache since the PR is now merged
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_SCRIPTS_DIR="${SCRIPT_DIR}/../../../scripts"

# Clear PR number from cache
if [ -f "${REPO_SCRIPTS_DIR}/clear-pr-cache.sh" ]; then
    "${REPO_SCRIPTS_DIR}/clear-pr-cache.sh" 2>/dev/null || true
else
    # Fallback: directly clear PR from cache file
    CACHE_DIR="${HOME}/.fractary/repo"
    REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    REPO_ID=$(echo "$REPO_PATH" | (md5sum 2>/dev/null || md5 2>/dev/null || shasum 2>/dev/null) | cut -d' ' -f1 | cut -c1-16 || echo "global")
    CACHE_FILE="${CACHE_DIR}/status-${REPO_ID}.cache"
    PR_CACHE_FILE="${CACHE_DIR}/pr-${REPO_ID}.cache"

    # Clear PR from main cache
    if [ -f "$CACHE_FILE" ]; then
        sed -i 's/"pr_number": "[^"]*"/"pr_number": ""/' "$CACHE_FILE" 2>/dev/null || true
    fi

    # Clear PR cache file
    rm -f "$PR_CACHE_FILE" 2>/dev/null || true
fi
```

**Why add this to merge-pr.sh**:
1. The merge operation has definitive knowledge that the PR is now closed
2. Clearing immediately prevents stale data even if user stays on same branch
3. No need to wait for next cache refresh or branch switch
4. Defense in depth: works even if branch change detection has edge cases

---

#### Alternative: Sync Lookup on Branch Change (Not Recommended)

When branch changes, perform a synchronous (blocking) PR lookup instead of async:

```bash
if [ "$BRANCH" != "$CACHED_BRANCH" ]; then
    # Branch changed - do sync lookup (one-time cost)
    PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null || echo "")
else
    # ... existing async logic for same-branch case ...
fi
```

Trade-off: Slightly slower on branch switch, but accurate immediately. Not recommended because Part 1 achieves the same goal without performance impact.

### Code Changes Required

**Part 1 - update-status-cache.sh**:
- Lines 186-189: Modify fallback logic to NOT use cached PR on branch change
- Lines 166-184: May need adjustment to PR cache validation logic

**Part 2 - merge-pr.sh**:
- Add ~15-20 lines after successful merge to clear PR from cache
- Located after line 199 (success output), before JSON output

**Optional - new script clear-pr-cache.sh**:
- Create dedicated script for clearing PR from cache (reusable)
- Can be called from merge-pr.sh and potentially other scripts

### Why This Fix Works

**Part 1** works because:
1. When switching branches, the old PR number is irrelevant to the new branch
2. Clearing immediately gives accurate state (no PR) rather than stale state
3. The async lookup will populate the correct PR (if any) for the next run
4. Users see "no PR" which is correct for `main` or new branches

**Part 2** works because:
1. After merge, we have definitive knowledge the PR no longer exists (merged state)
2. Proactive clearing prevents any window where stale PR could be shown
3. Works regardless of whether user switches branches
4. Consistent with principle: "operations that change state should update cache"

The one-run delay for PR discovery on new branches is acceptable (0 → correct PR) but the delay for branch switch is not (old PR → empty → correct) because showing wrong PR is worse than showing no PR.

### Alternative Solutions Considered

- **Sync lookup always**: Too slow for status line updates (100-500ms per `gh pr view`)
- **Dual-phase commit**: Write cache twice (once without PR, once after lookup) - adds complexity
- **PR cache per branch**: Maintain separate PR cache per branch - adds storage complexity
- **Clear PR only in update-status-cache.sh**: Misses the post-merge case if user doesn't switch branches

## Implementation Plan

### Phase 1: Fix Branch Change Logic
**Status**: ⬜ Not Started

**Objective**: Modify PR number handling to clear on branch change

**Tasks**:
- [ ] Update `update-status-cache.sh` to clear PR on branch change (Part 1)
- [ ] Ensure async lookup still works for same-branch PR discovery
- [ ] Add inline comments explaining the behavior

**Estimated Scope**: ~20 lines changed

### Phase 2: Fix PR Merge Cache Clear
**Status**: ⬜ Not Started

**Objective**: Clear PR from cache after successful merge

**Tasks**:
- [ ] Add cache clearing logic to `merge-pr.sh` after successful merge (Part 2)
- [ ] Clear both main status cache and PR cache file
- [ ] Handle errors gracefully (non-blocking, don't fail merge on cache issues)
- [ ] Optionally create reusable `clear-pr-cache.sh` script

**Estimated Scope**: ~20 lines added to merge-pr.sh

### Phase 3: Testing
**Status**: ⬜ Not Started

**Objective**: Verify both fixes work across scenarios

**Tasks**:
- [ ] Test Scenario A: Switch from PR branch to main - PR should clear
- [ ] Test Scenario A: Switch from PR branch to new feature branch - PR should clear
- [ ] Test Scenario B: Merge PR via `/repo:pr-merge` - PR should clear immediately
- [ ] Test: Stay on same branch without merge - PR should persist
- [ ] Test: Create PR on branch - PR should be discovered
- [ ] Verify status line shows correct state after all scenarios

**Estimated Scope**: Manual testing + optional script

### Phase 4: Edge Cases
**Status**: ⬜ Not Started

**Objective**: Handle edge cases gracefully

**Tasks**:
- [ ] Test: Rapid branch switching (ensure no race conditions)
- [ ] Test: Network failure during async lookup (should not crash)
- [ ] Test: PR cache file corruption (should recover)
- [ ] Test: Merge PR while cache file is locked (should not block merge)

**Estimated Scope**: Review and minor hardening

## Files to Modify

- `plugins/repo/scripts/update-status-cache.sh`: Fix PR number fallback logic (~10-20 lines changed)
- `plugins/repo/skills/handler-source-control-github/scripts/merge-pr.sh`: Add cache clearing after merge (~15-20 lines added)
- `plugins/repo/scripts/clear-pr-cache.sh`: (Optional) New reusable script for clearing PR from cache

## Testing Strategy

### Regression Tests

Ensure existing functionality still works:
- Status cache updates on UserPromptSubmit hook
- Branch name extraction works
- Issue ID extraction works
- Commits ahead/behind calculation works
- Async PR lookup still finds PRs for current branch

### New Test Cases

- `test_pr_clears_on_branch_switch`: Verify PR number is empty after switching branches
- `test_pr_clears_on_merge`: Verify PR number is empty after `/repo:pr-merge` completes
- `test_pr_persists_on_same_branch`: Verify PR number persists when staying on same branch (no merge)
- `test_pr_discovered_async`: Verify new PR is discovered after creation

### Manual Testing Checklist

**Scenario A (Branch Switch):**
- [ ] Create branch with issue ID
- [ ] Push and create PR
- [ ] Verify status shows PR number
- [ ] Merge PR externally (GitHub UI) and delete branch
- [ ] Switch to main
- [ ] Verify status shows NO PR number
- [ ] Start new work on different issue
- [ ] Verify status shows correct (empty or new) PR

**Scenario B (CLI Merge):**
- [ ] Create branch with issue ID
- [ ] Push and create PR
- [ ] Verify status shows PR number
- [ ] Merge PR via `/repo:pr-merge` command
- [ ] Immediately check status cache - should show NO PR number
- [ ] Stay on same branch - PR should remain empty
- [ ] Switch to main - PR should remain empty

## Risk Assessment

### Risks of Fix

- **Async lookup timing**: User might not see PR immediately after creation
  - Mitigation: Acceptable - one-run delay for discovery is fine
- **Test coverage**: Manual testing may miss edge cases
  - Mitigation: Add automated test script
- **Cache file locking in merge-pr.sh**: Could block if cache is locked
  - Mitigation: Use non-blocking clear with `|| true` to prevent merge failures

### Risks of Not Fixing

- Users see wrong PR number leading to confusion
- PR-related operations might reference wrong PR
- Trust in status line accuracy is undermined
- Potential bugs in FABER workflow that checks cache for PR status

## Dependencies

- bash (for script execution)
- gh CLI (for PR lookup)
- flock (for cache locking)

## Acceptance Criteria

- [ ] After switching from a PR branch to main, status cache shows no PR
- [ ] After switching to a new feature branch, status cache shows no PR
- [ ] After `/repo:pr-merge` completes, status cache shows no PR immediately
- [ ] Staying on a branch with a PR (not merged), status cache shows correct PR
- [ ] Creating a new PR is detected within 1-2 cache updates
- [ ] Status line displays accurate PR information
- [ ] No performance regression in cache update time
- [ ] Merge operation does not fail if cache clearing fails (graceful degradation)

## Prevention Measures

### How to Prevent Similar Bugs

- When implementing async optimizations, consider the "first run after state change" case
- Test state transitions, not just steady-state behavior
- Cache fallback logic should consider context (same entity vs different entity)
- Operations that definitively change state should proactively update related caches

### Process Improvements

- Add test scenarios for state transitions (branch switch, PR merge)
- Consider adding cache field validation (is cached PR for current branch?)
- Document async timing expectations in code comments

## Implementation Notes

The fix should be minimal and focused. The async optimization for PR lookup is valuable for performance and should be preserved - only the fallback behavior on branch change needs adjustment.

Key insight: "No PR" is better UX than "Wrong PR" - so we should err on the side of clearing stale data rather than preserving it.

---

## Changelog

### 2025-12-07 - Refinement Round 1

**Refinement Focus**: PR-merge command should also clear cache

**Changes Applied**:
1. Added Part 2 to solution approach: Clear PR cache after successful merge in `merge-pr.sh`
2. Added Scenario B to reproduction steps: PR merge via CLI
3. Updated affected components to include `merge-pr.sh`
4. Added Phase 2 to implementation plan: Fix PR Merge Cache Clear
5. Updated files to modify list to include `merge-pr.sh` and optional `clear-pr-cache.sh`
6. Added new test case `test_pr_clears_on_merge`
7. Added Scenario B to manual testing checklist
8. Added acceptance criterion for immediate cache clear after merge
9. Added risk mitigation for cache file locking during merge

**Rationale**: The original spec only addressed the branch switch scenario. User feedback identified that the `/repo:pr-merge` command should proactively clear the PR from cache since it has definitive knowledge that the PR is now merged. This is a defense-in-depth approach that ensures the cache is cleared even if the user doesn't switch branches after merging.
