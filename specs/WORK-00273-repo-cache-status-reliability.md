# WORK-00273: Make Repo Cache Update / Status Line More Reliable

## Overview

**Work Item**: [#273](https://github.com/fractary/claude-plugins/issues/273)
**Type**: Bug Fix / Reliability Improvement
**Created**: 2025-12-07
**Status**: Draft
**Last Refined**: 2025-12-07

## Changelog

### 2025-12-07 - Refinement Round 1
- Added root cause analysis: statusLine refresh is decoupled from cache updates
- Clarified hook placement strategy: plugin hooks.json only
- Changed command to `/fractary-status:sync` (owner: status plugin)
- Removed Stop hook cache update (auto-commit only)
- Added detailed statusLine timing documentation

## Problem Statement

The status line frequently does not represent the current state. It is often one step behind and shows dated information about:
- Number of uncommitted files
- Number of unstaged changes
- Current issue ID
- Current PR information

### Root Cause Analysis

Based on issue comments and investigation of Claude Code's statusLine behavior:

#### Primary Root Cause: StatusLine/Cache Update Timing Mismatch

**The core issue is that the statusLine and cache update are decoupled:**

1. **StatusLine refreshes on conversation message updates** (throttled to max every 300ms)
2. **Cache updates happen in hooks** (UserPromptSubmit, SessionStart)
3. **Cache change alone doesn't trigger statusLine refresh**

**Sequence causing "one step behind":**
```
1. User submits prompt
2. UserPromptSubmit hook fires → cache updates (reflects NEW state)
3. StatusLine reads cache (but may have already read OLD cache before hook completed)
4. Claude processes prompt
5. Conversation updates → statusLine refreshes → NOW shows updated cache
6. User sees "old" status during prompt processing, "new" status after response
```

The status line appears to lag because it reads the cache at a different point in the event cycle than when the cache updates.

#### Secondary Contributing Factors

1. **Inconsistent Hook Configuration**
   - Plugin hooks in `plugins/repo/hooks/hooks.json` define `Stop` and `UserPromptSubmit` hooks
   - Project-specific `.claude/settings.json` may have additional `SessionStart` hooks
   - Not all projects have consistent hook configurations
   - **Decision**: Consolidate all hooks in plugin's `hooks/hooks.json`

2. **Hook Definition Inconsistencies**
   - `Stop` hook currently runs: `auto-commit-on-stop.sh` (not cache update)
   - `UserPromptSubmit` hook uses: `update-status-cache.sh --quiet`
   - `SessionStart` missing from plugin hooks.json
   - **Decision**: Keep Stop for auto-commit only; add SessionStart to plugin hooks

3. **Two Plugins Involved**
   - `plugins/repo/` - manages cache via `update-status-cache.sh`
   - `plugins/status/` - manages display via `status-line.sh`
   - **Decision**: Sync command belongs in status plugin as `/fractary-status:sync`

## Requirements

### Functional Requirements

1. **FR-1: Reliable Hook Execution**
   - Consolidate all hook definitions in plugin's `hooks/hooks.json`
   - Add `SessionStart` hook to `plugins/repo/hooks/hooks.json`
   - Keep `Stop` hook for auto-commit only (no cache update)
   - Keep `UserPromptSubmit` hook for cache update
   - Validate that `${CLAUDE_PLUGIN_ROOT}` expansion works in all contexts

2. **FR-2: Consistent Cache Updates**
   - Status cache should always reflect current git state
   - Cache should update after any operation that changes git state
   - Include: branch changes, commits, file staging, PR operations

3. **FR-3: Sync Command** (Owner: status plugin)
   - New command: `/fractary-status:sync`
   - Force refresh of cache AND status line display
   - Display comprehensive status output (enhanced `git status`)
   - Include: git status, issue ID, PR info, branch info, last cache update time
   - **Key**: Must trigger a conversation message to force statusLine refresh

4. **FR-4: StatusLine Synchronization**
   - Investigate ways to ensure statusLine reads fresh cache
   - Option A: Have cache update output text (triggers message update → statusLine refresh)
   - Option B: Accept 300ms delay as inherent to statusLine design
   - Option C: Direct git reads in status-line.sh as fallback for stale cache

### Non-Functional Requirements

1. **NFR-1: Reliability**
   - Status line accuracy should be >= 99% within 1 second of any state change

2. **NFR-2: Performance**
   - Cache update should complete within 500ms for typical repositories
   - Should not noticeably delay user interactions

3. **NFR-3: Consistency**
   - Behavior should be identical across all projects using the plugin
   - No project-specific configuration required for basic functionality

## Technical Approach

### Phase 1: Audit & Document Current State

1. **Review existing hook configuration** ✅ (Done during refinement)
   - `plugins/repo/hooks/hooks.json` - has Stop (auto-commit), UserPromptSubmit (cache update)
   - `plugins/status/hooks/hooks.json` - has UserPromptSubmit (capture-prompt)
   - Project `.claude/settings.json` - has SessionStart (marketplace update + cache update)

2. **Analyze `update-status-cache.sh`** ✅ (Done during refinement)
   - `--quiet` flag suppresses success messages, not errors
   - Uses flock for serialization (prevents concurrent updates)
   - Async PR lookup already implemented
   - Cache stored at `~/.fractary/repo/status-{hash}.cache`

3. **Document statusLine timing** ✅ (Done during refinement)
   - Refreshes on conversation message updates (throttled 300ms)
   - Decoupled from hook execution
   - Reading cache doesn't trigger refresh

### Phase 2: Consolidate Hook Configuration

1. **Update `plugins/repo/hooks/hooks.json`**
   ```json
   {
     "hooks": {
       "SessionStart": [{"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/update-status-cache.sh --quiet"}]}],
       "Stop": [{"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/auto-commit-on-stop.sh"}]}],
       "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/update-status-cache.sh --quiet"}]}]
     }
   }
   ```

2. **Update project settings** (document migration)
   - Remove `SessionStart` cache update from project `.claude/settings.json`
   - Keep marketplace update prompt (project-specific)
   - Plugin hooks handle the rest

### Phase 3: Implement `/fractary-status:sync` Command

1. **Create in status plugin** (not repo plugin)
   - `plugins/status/commands/sync.md` - command definition
   - `plugins/status/skills/status-syncer/SKILL.md` - skill implementation

2. **Command behavior**:
   - Call `update-status-cache.sh` to refresh cache
   - Read and display comprehensive status
   - Output triggers conversation message → statusLine refreshes

3. **Command output format**:
   ```
   📊 Repository Status Synced
   ──────────────────────────────────────
   Branch: feat/273-make-repo-cache-update-status-line-more-reliable
   Issue:  #273 - Make repo cache update / status line more reliable
   PR:     None

   Git Status:
     Staged:    0 files
     Modified:  2 files
     Untracked: 1 file
     Ahead:     3 commits
     Behind:    0 commits

   Cache:
     Updated:   2025-12-07T14:30:00Z
     Location:  ~/.fractary/repo/status-abc123.cache
   ──────────────────────────────────────
   ✅ Status line will refresh with next message
   ```

### Phase 4: Add Debug/Logging Mode (Optional)

1. **Add `--debug` flag to `update-status-cache.sh`**
   - Logs execution to `~/.fractary/repo/hook-debug.log`
   - Helps diagnose hook firing issues
   - Off by default (no performance impact)

2. **Add `/fractary-status:debug` command** (optional)
   - Shows recent hook executions
   - Helps troubleshoot "one step behind" issues

## Files to Modify

### Primary Files

| File | Action | Description |
|------|--------|-------------|
| `plugins/repo/hooks/hooks.json` | Modify | Add SessionStart hook |
| `plugins/status/commands/sync.md` | Create | New sync command |
| `plugins/status/skills/status-syncer/SKILL.md` | Create | Skill for sync operation |

### Secondary Files

| File | Action | Description |
|------|--------|-------------|
| `plugins/repo/scripts/update-status-cache.sh` | Modify | Add optional `--debug` flag |
| `plugins/status/docs/HOOKS.md` | Create | Document hook behavior and timing |
| `CLAUDE.md` | Update | Document migration for SessionStart hook |

## Acceptance Criteria

1. **AC-1**: Status line reflects current git state within 1 second of any change (after message update)
2. **AC-2**: All hooks (SessionStart, UserPromptSubmit) fire reliably from plugin hooks.json
3. **AC-3**: No project-specific configuration required for cache update (only marketplace update is project-specific)
4. **AC-4**: `/fractary-status:sync` command provides accurate, comprehensive output and forces statusLine refresh
5. **AC-5**: Cache update does not noticeably delay user interactions

## Testing Plan

1. **Manual Testing**
   - Create commits, verify status updates
   - Switch branches, verify status updates
   - Create PRs, verify status updates
   - Start new sessions, verify SessionStart hook fires

2. **Edge Cases**
   - Multiple rapid operations
   - Large repositories
   - Network failures (for PR/issue data)

## Resolved Questions

| Question | Answer | Source |
|----------|--------|--------|
| Where should SessionStart hook be defined? | Plugin hooks.json only | User preference (refinement round 1) |
| Which plugin owns the sync command? | status plugin as `/fractary-status:sync` | User preference (refinement round 1) |
| What should Stop hook do? | Auto-commit only (no cache update) | User preference (refinement round 1) |
| Why is status "one step behind"? | StatusLine refreshes on message updates, not cache updates | Claude Code docs research |

## Open Questions

1. **StatusLine refresh mechanism**: Is there a way to programmatically trigger statusLine refresh? (Documented behavior suggests no, but worth confirming)
2. How do we handle status for repositories without work plugin configured? (Graceful fallback needed)

## References

- Issue: https://github.com/fractary/claude-plugins/issues/273
- Current hooks: `plugins/repo/hooks/hooks.json`
- Status cache script: `plugins/repo/scripts/update-status-cache.sh`
- Status line script: `plugins/status/scripts/status-line.sh`
- Claude Code statusLine docs: Refreshes on conversation message updates (throttled 300ms)
