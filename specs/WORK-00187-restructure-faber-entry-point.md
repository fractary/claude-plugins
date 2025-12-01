---
spec_id: WORK-00187-restructure-faber-entry-point
work_id: 187
issue_url: https://github.com/fractary/claude-plugins/issues/187
title: Restructure FABER Entry Point Architecture
type: feature
status: draft
created: 2025-12-01
author: jmcwilliam
validated: false
source: conversation+issue
---

# WORK-00187: Restructure FABER Entry Point Architecture

## Summary

The `/faber:manage` command stops after fetching issue details instead of continuing through the full FABER workflow (Frame → Architect → Build → Evaluate → Release). The root cause is an overly complex command layer that duplicates logic and fails to properly invoke the `faber-director` skill after workflow detection.

This spec defines a restructure that creates a clean separation of concerns:
- **Command** (`/faber:direct`) - Lightweight entry point
- **Director skill** - Intelligence layer (parsing, routing, parallelization)
- **Manager agent/skill** - Execution layer (runs single workflow)

## Problem Statement

### Current Behavior

When running `/faber:manage 60`:
1. ✅ Parses arguments (work_id: 60)
2. ✅ Loads configuration
3. ✅ Fetches issue for workflow detection (Step 1.5)
4. ❌ **STOPS** - Never invokes faber-director skill

### Root Cause

The `faber-manage.md` command:
1. Duplicates logic that should be in the director skill (config loading, workflow detection)
2. Has a complex multi-step workflow that the LLM doesn't complete
3. Fetches the issue (for workflow detection) but doesn't continue to the actual invocation

### Expected Behavior

After fetching issue, the command should:
1. Determine workflow (from labels or default)
2. **Invoke faber-director skill**
3. Director spawns faber-manager agent(s)
4. Full workflow executes: Frame → Architect → Build → Evaluate → Release

## Solution Architecture

### New Architecture

```
/faber:direct (NEW - lightweight command)
    ↓ immediately invokes
faber-director skill (intelligence layer)
    ↓ spawns 1 or N
faber-manager agent (execution layer)
    ↓ delegates to
faber-manager skill (workflow logic)
```

### Layer Responsibilities

| Layer | Responsibility | Should NOT do |
|-------|---------------|---------------|
| **Command** (`/faber:direct`) | Parse raw args, invoke director skill | Config loading, workflow detection, issue fetching |
| **Director skill** | Parse intent, detect workflow from labels, decide single vs parallel, spawn manager agent(s) | Execute workflow phases |
| **Manager agent** | Thin wrapper, invoke manager skill with context | Complex logic |
| **Manager skill** | Execute single workflow (all 5 phases) | Parallelization |

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Deprecation period | None - delete old commands | Clean break, avoid confusion |
| Issue fetch timing | Always fetch (even with explicit --workflow) | Provides context/validation |
| Autonomy flag | Keep at command level | Config is default, flag overrides |

## Implementation Plan

### Step 1: Create `/faber:direct` Command

**File**: `plugins/faber/commands/faber-direct.md` (NEW)

Lightweight command that:
1. Accepts flexible input (work_id, natural language, or both)
2. Immediately invokes `faber-director` skill with raw input
3. Returns director's response

**Key characteristics**:
- Minimal processing - just parse and forward
- No config loading
- No workflow detection
- No issue fetching
- Single responsibility: invoke director skill

**Command structure**:
```markdown
---
name: fractary-faber:direct
description: Execute FABER workflow via natural language or work item ID
argument-hint: <work_id | "natural language request"> [--workflow <id>] [--autonomy <level>]
tools: Skill
model: inherit
---
```

**Arguments**:
- `<work_id>` or `<natural language>` - Required positional argument
- `--workflow <id>` - Optional workflow override
- `--autonomy <level>` - Optional autonomy override (dry-run, assist, guarded, autonomous)

### Step 2: Update `faber-director` Skill

**File**: `plugins/faber/skills/faber-director/SKILL.md` (MODIFY)

The skill already has:
- ✅ Natural language parsing
- ✅ Parallelization logic
- ✅ Task tool invocation for faber-manager

**Changes needed**:

1. **Add Step 0: Load Configuration**
   ```
   Load config from `.fractary/plugins/faber/config.json`
   - Get available workflows
   - Get default autonomy level
   - Get integration settings
   ```

2. **Enhanced Step 1: Always Fetch Issue**
   ```
   ALWAYS fetch issue for context/validation:
   - Even with explicit --workflow flag
   - Use for workflow detection from labels (when --workflow not provided)
   - Provides issue title, description, comments for context
   ```

3. **Support Autonomy Override**
   ```
   Priority order:
   1. --autonomy flag (highest)
   2. Config default (fallback)
   ```

4. **Ensure worktree: true**
   ```
   ALL workflows use worktrees for isolation
   Always pass worktree: true to faber-manager
   ```

### Step 3: Verify `faber-manager` Agent/Skill

**Files**:
- `plugins/faber/agents/faber-manager.md` - Verify thin wrapper
- `plugins/faber/skills/faber-manager/SKILL.md` - Verify contains all logic

**Verification checklist**:
- [ ] Agent immediately invokes skill (no complex logic)
- [ ] Skill contains complete workflow execution logic
- [ ] Skill handles all 5 phases: Frame, Architect, Build, Evaluate, Release
- [ ] Skill respects autonomy settings
- [ ] Skill manages state via `.fractary/plugins/faber/state.json`

### Step 4: Delete Old Commands

**Files to DELETE**:
- `plugins/faber/commands/faber-manage.md`
- `plugins/faber/commands/faber-run.md` (if exists)

No deprecation period - clean break to new architecture.

### Step 5: Update Plugin Manifest

**File**: `plugins/faber/.claude-plugin/plugin.json`

Changes:
- Add `./commands/faber-direct.md` to commands path (auto-discovered)
- Verify commands directory reference is correct
- Remove any explicit references to deleted commands

## Files to Modify

| File | Action | Description |
|------|--------|-------------|
| `plugins/faber/commands/faber-direct.md` | CREATE | Lightweight command (~50 lines) |
| `plugins/faber/skills/faber-director/SKILL.md` | MODIFY | Add config loading, always fetch issue |
| `plugins/faber/commands/faber-manage.md` | DELETE | Replaced by faber-direct |
| `plugins/faber/commands/faber-run.md` | DELETE | Deprecated, if exists |
| `plugins/faber/.claude-plugin/plugin.json` | VERIFY | Ensure commands directory correct |

## Example Usage

After restructure:

```bash
# Simple work item
/faber:direct 123

# Natural language
/faber:direct "implement issue 123 and 124"

# With overrides
/faber:direct 123 --workflow hotfix --autonomy autonomous

# Multiple items (director handles parallelization)
/faber:direct 100,101,102
```

## Acceptance Criteria

1. **Basic workflow execution**
   - [ ] `/faber:direct 123` executes full workflow without stopping
   - [ ] All 5 phases complete: Frame → Architect → Build → Evaluate → Release

2. **Natural language support**
   - [ ] `/faber:direct "run issue 123"` correctly parses and executes
   - [ ] `/faber:direct "implement issues 100 and 101"` extracts multiple IDs

3. **Parallelization**
   - [ ] `/faber:direct 100,101,102` spawns 3 agents in parallel
   - [ ] Each agent runs in isolated worktree

4. **Command cleanup**
   - [ ] `/faber:manage` command deleted
   - [ ] `/faber:run` command deleted (if exists)
   - [ ] No broken references in plugin manifest

5. **Workflow detection**
   - [ ] Labels like `workflow:hotfix` detected from issue
   - [ ] Detection happens in director skill, not command

6. **Autonomy handling**
   - [ ] `--autonomy` flag overrides config default
   - [ ] All levels work: dry-run, assist, guarded, autonomous

## Testing Strategy

### Manual Testing

1. **Single issue execution**:
   ```bash
   /faber:direct 187
   # Verify: Full workflow completes
   ```

2. **With workflow override**:
   ```bash
   /faber:direct 187 --workflow default
   # Verify: Uses specified workflow
   ```

3. **With autonomy override**:
   ```bash
   /faber:direct 187 --autonomy dry-run
   # Verify: Simulates without changes
   ```

4. **Multiple issues**:
   ```bash
   /faber:direct 100,101
   # Verify: Two parallel agents spawned
   ```

### Validation Checklist

- [ ] Command invokes director skill immediately (no intermediate processing)
- [ ] Director fetches issue data
- [ ] Director loads configuration
- [ ] Director spawns manager agent(s)
- [ ] Manager executes full workflow
- [ ] PR created at end (Release phase)

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Breaking existing usage | Medium | High | Clear migration docs, test before delete |
| Director skill complexity increase | Low | Medium | Keep changes focused, don't over-engineer |
| Natural language parsing edge cases | Medium | Low | Fall back to treating input as work_id |

## Notes

### Why Not Just Fix faber-manage?

The current `faber-manage.md` has fundamental architecture issues:
1. **Too many responsibilities** - Parses args, loads config, detects workflow, fetches issue, invokes skill
2. **Duplicated logic** - Workflow detection duplicated between command and director
3. **LLM execution fragility** - Complex multi-step workflow prone to incomplete execution

A clean slate with clear separation is more maintainable.

### Backward Compatibility

No backward compatibility - old commands are deleted:
- Users must update to `/faber:direct`
- Simple migration: `/faber:manage 123` → `/faber:direct 123`
- Same flags work: `--workflow`, `--autonomy`

### Future Considerations

- Could add `/faber:status` to query workflow state
- Could add `/faber:retry` to retry failed workflows
- Director skill could support more natural language patterns

## Related Issues

- Issue #187: faber:manage workflow stops after issue fetch (this issue)

## Changelog

| Date | Author | Change |
|------|--------|--------|
| 2025-12-01 | jmcwilliam | Initial spec created from conversation context |
