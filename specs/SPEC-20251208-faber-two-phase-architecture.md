# SPEC: FABER Two-Phase Architecture (Plan → Execute)

**Spec ID**: SPEC-20251208-faber-two-phase-architecture
**Title**: Restructure FABER into Two-Phase Plan/Execute Model
**Type**: Architecture / Refactoring
**Status**: Draft (Refined)
**Created**: 2025-12-08
**Author**: Conversation Context
**Source**: Planning discussion in Claude Code session

---

## Summary

Restructure the FABER workflow system from a monolithic director/manager pattern into a clean two-phase architecture:

1. **Phase 1: Planning** (`/faber:plan`) - Director creates an immutable plan artifact
2. **Phase 2: Execution** (`/faber:execute`) - Manager(s) execute the plan

This separation addresses the current issues with the 1,248-line faber-director skill that is too complex and prone to premature termination, while also enabling parallel execution of multiple targets.

---

## Problem Statement

### Current Issues

1. **Bloated Director Skill**: faber-director.SKILL.md is 1,248 lines (was 803 originally), making it confusing for the LLM
2. **Premature Termination**: The director stops after faber-config returns, failing to invoke faber-manager
3. **Agents-on-Agents Concern**: Having director (as agent) spawn manager agents was considered problematic
4. **Black Box Execution**: No visibility into what the workflow will do before it runs
5. **Complex State Management**: Multiple runs per issue, unclear resume semantics
6. **No Parallel Execution**: Can't easily work on multiple targets simultaneously

### Root Causes

- Director tries to do too much: parse input, resolve workflow, fetch issue, detect labels, validate, build params, invoke manager
- When sub-skills return (like faber-config), the LLM interprets that as "done"
- No artifact to inspect before execution begins
- State is tangled between director and manager

---

## Proposed Solution

### Two-Phase Model

```
Phase 1: /faber:plan (Director creates artifact)
├── Parse user input (target, work_id, wildcards)
├── Expand wildcards to concrete targets
├── Resolve workflow inheritance (via faber-config)
├── For each target:
│   ├── Create GitHub issue (if needed)
│   ├── Create branch
│   └── Create worktree
├── Save plan artifact to .faber/plans/
└── STOP (do not execute)

Phase 2: /faber:execute <plan-id> (Manager executes)
├── Read plan artifact
├── For each item in plan:
│   └── Task(faber-manager, {issue, worktree, workflow})
├── Run in parallel or serial (based on config)
└── Aggregate and report results
```

### Plan Artifact Structure

The plan is a **complete snapshot of intent** saved before execution:

```json
{
  "id": "fractary-claude-plugins-ipeds-20251208T153000",
  "created": "2025-12-08T15:30:00Z",
  "created_by": "faber-director",
  "source": {
    "input": "ipeds/*",
    "work_id": null,
    "expanded_from": "wildcard"
  },

  "workflow": {
    "id": "fractary-faber:default",
    "resolved_at": "2025-12-08T15:30:00Z",
    "inheritance_chain": ["fractary-faber:default", "fractary-faber:core"],
    "phases": {
      "frame": { "enabled": true, "steps": [...] },
      "architect": { "enabled": true, "steps": [...] },
      "build": { "enabled": true, "steps": [...] },
      "evaluate": { "enabled": true, "steps": [...] },
      "release": { "enabled": true, "steps": [...] }
    }
  },

  "autonomy": "guarded",

  "items": [
    {
      "target": "ipeds/admissions",
      "issue": {
        "number": 401,
        "url": "https://github.com/org/repo/issues/401",
        "created": true
      },
      "branch": "feat/401-ipeds-admissions",
      "worktree": "../project-wt-401",
      "run_id": null
    },
    {
      "target": "ipeds/completions",
      "issue": {
        "number": 402,
        "url": "https://github.com/org/repo/issues/402",
        "created": true
      },
      "branch": "feat/402-ipeds-completions",
      "worktree": "../project-wt-402",
      "run_id": null
    }
  ],

  "execution": {
    "mode": "parallel",
    "max_concurrent": 5,
    "status": "pending",
    "started_at": null,
    "completed_at": null
  }
}
```

### Key Design Decisions

#### 1. Workflow Snapshot in Plan

The resolved workflow is captured at plan creation time:
- **Immutability**: Resume uses the SAME workflow, not current plugin default
- **Debugging**: Know exactly what workflow was supposed to run
- **Consistency**: Plugin updates don't affect in-flight plans

#### 2. One Issue = One Branch = One Worktree = One Run

Unified model for all parallel work:

| Use Case | Treatment |
|----------|-----------|
| `ipeds/*` (5 tables) | 5 issues, 5 branches, 5 worktrees, 5 PRs |
| "Top 5 issues" | Same: 5 issues, 5 branches, 5 worktrees, 5 PRs |

Benefits:
- Clean git history per target
- Independent PRs can be reviewed/merged separately
- If one fails, others still succeed
- Clear audit trail

#### 3. Run ID on GitHub Issue

Store run_id as a GitHub label on the issue:

```
Issue #401: Implement ipeds/admissions
Labels: [faber:run-id=abc123, faber:plan=plan-abc123, type:feature]
```

Benefits:
- Easy to find run state from issue
- Resume is trivial: find issue → read run_id label → load state
- Links plan to execution

#### 4. Simple Executor

The `/faber:execute` command is intentionally simple (~50 lines):

```
1. Read plan file
2. For each item: Task(faber-manager, {...})
3. Wait for completion
4. Aggregate results
```

So simple it can't fail. The complexity is in the planning phase.

#### 5. Plan ID Naming Convention

Plan IDs follow a hierarchical naming pattern for cross-project analytics:

```
{organization}-{project}-{subproject}-{timestamp}
```

**Examples:**
- `fractary-claude-plugins-ipeds-20251208T153000`
- `acme-data-pipeline-customers-20251209T091500`
- `myorg-webapp-auth-20251210T140000`

**Benefits:**
- Globally unique across organization
- Human-readable and sortable by time
- Ready for central control plane / reporting / analytics
- Easy to identify source project from ID alone

#### 6. Fail-Safe Parallel Execution

When executing items in parallel:
- Each item runs independently
- If one item fails, others **continue** to completion
- Failures are aggregated at the end
- Final report shows which items succeeded/failed

This prevents a single failure from blocking all work.

#### 7. Resume Mode for Existing Branches

When `/faber:plan` encounters an issue that already has an associated branch:
- **Detect existing state** from issue labels and branch
- **Resume from last checkpoint** rather than starting fresh
- **Skip completed phases** and continue from where execution stopped

This enables seamless recovery from interrupted workflows.

#### 8. Automatic Worktree Cleanup

Worktrees created during plan execution are automatically cleaned up:
- When a PR is merged, its associated worktree is removed
- Uses existing `/repo:pr-merge --worktree-cleanup` behavior
- Plan tracks worktree paths for cleanup coordination
- No manual cleanup required for successful workflows

---

## Detailed Design

### Phase 1: faber-director (Planning)

**Responsibilities:**
- Parse user input (target, work_id, wildcards like `dataset/*`)
- Expand wildcards to concrete targets
- Resolve workflow via faber-config
- Create issues for each target (with run_id labels)
- Create branches and worktrees
- Save plan artifact
- **STOP** - do not invoke managers

**Size Target:** ~300-400 lines max

**Key Simplification:**
- Remove all execution logic
- Remove manager invocation
- Focus only on plan creation
- Each step is simple and unlikely to confuse the LLM

### Phase 2: faber-executor (New Command)

**File:** `commands/execute.md`

**Responsibilities:**
- Read plan file
- Spawn faber-manager agents (via Task tool)
- Parallel or serial execution (configurable)
- Aggregate results

**Size Target:** ~100 lines

**Pattern:**
```
/faber:execute plan-abc123 [--serial] [--max-concurrent 3]
```

### Phase 2b: faber-manager (Execution)

**Responsibilities (unchanged):**
- Execute workflow phases in a worktree
- Manage state within its execution
- Create commits, PRs
- Report results

**Key Change:**
- Receives complete workflow from plan (not from config)
- Run ID comes from plan item
- Isolated to single target/worktree

---

## File Structure

### Plan Storage

Plans are stored in the logs directory (not source control) for backup and archival:

```
.fractary/logs/faber/
├── plans/
│   ├── fractary-project-feature-20251208T153000.json
│   ├── fractary-project-data-20251209T091500.json
│   └── ...
├── runs/
│   └── fractary-project-feature-20251208T153000/
│       ├── items/
│       │   ├── 401/              # Per-item state
│       │   │   └── state.json
│       │   └── 402/
│       │       └── state.json
│       └── aggregate.json        # Overall execution state
└── daily/
    └── 2025-12-08/
        └── fractary-project-feature-20251208T153000.log
```

**Storage Rationale:**
- Plans are operational artifacts, not source code
- Located in `.fractary/logs/` which is typically gitignored
- Can be backed up and archived by log management systems
- Keeps repository clean while preserving audit trail

### Audit Trail

**Plan** = what we intended (workflow snapshot + targets)
**State** = where we are (per-item progress)
**Log** = what happened (detailed execution log)

---

## Commands

### `/faber:plan`

Create a plan without executing:

```bash
# Single target
/faber:plan --target customer-pipeline --work-id 123

# Wildcard expansion
/faber:plan --target "ipeds/*"

# Multiple issues
/faber:plan --work-id 101,102,103

# Top N issues from backlog
/faber:plan --backlog --top 5
```

**Output:**
```
🎯 FABER Plan Created

Plan ID: plan-abc123
Targets: 5 items
Workflow: fractary-faber:default (resolved)

Items:
  1. ipeds/admissions → Issue #401, Branch feat/401-...
  2. ipeds/completions → Issue #402, Branch feat/402-...
  3. ipeds/enrollment → Issue #403, Branch feat/403-...
  ...

Plan saved: .faber/plans/plan-abc123.json

Review the plan, then execute:
  /faber:execute plan-abc123
```

### `/faber:execute`

Execute a plan:

```bash
# Execute all items
/faber:execute plan-abc123

# Execute in serial
/faber:execute plan-abc123 --serial

# Limit concurrency
/faber:execute plan-abc123 --max-concurrent 3

# Execute specific items
/faber:execute plan-abc123 --items 401,402
```

### `/faber:run` (Convenience)

For simple single-target runs, keep the current pattern as a convenience wrapper:

```bash
/faber:run --work-id 123
```

**Behavior:**
- Creates a plan and saves it to `.fractary/logs/faber/plans/`
- Immediately executes the plan
- Plan is persisted for debugging and audit purposes
- Not ephemeral (can be referenced later if needed)

---

## State Management

### Per-Item State

Each plan item has its own state file:

```json
// .faber/runs/abc123/items/401/state.json
{
  "item_index": 0,
  "target": "ipeds/admissions",
  "issue": 401,
  "branch": "feat/401-ipeds-admissions",
  "worktree": "../project-wt-401",
  "run_id": "abc123-401",
  "status": "in_progress",
  "current_phase": "build",
  "current_step": "implement",
  "phases": {
    "frame": {"status": "completed", "completed_at": "..."},
    "architect": {"status": "completed", "completed_at": "..."},
    "build": {"status": "in_progress", "started_at": "..."},
    "evaluate": {"status": "pending"},
    "release": {"status": "pending"}
  }
}
```

### Resume Behavior

1. Find issue by number
2. Read `faber:run-id` label
3. Load state from `.faber/runs/{run_id}/items/{issue}/state.json`
4. Resume from last checkpoint

---

## Migration Path

### Phase 1: Immediate Fix

1. Simplify current faber-director (remove bloat)
2. Make it reliably invoke faber-manager
3. Fix issue #309

### Phase 2: Plan Artifact

1. Add plan file generation to director
2. Save workflow snapshot
3. Add `/faber:plan` command (plan-only mode)

### Phase 3: Executor

1. Create `/faber:execute` command
2. Move manager spawning to executor
3. Director stops after plan creation

### Phase 4: Parallel Execution

1. Add parallel spawning to executor
2. Add aggregate state tracking
3. Add progress reporting

---

## Benefits

| Concern | Before | After |
|---------|--------|-------|
| Director complexity | 1,248 lines | ~300 lines |
| Executor complexity | N/A | ~100 lines |
| Transparency | Black box | Review plan before execute |
| State management | Complex | 1 issue = 1 run_id |
| Resume | Hard | Trivial (label → state file) |
| Parallel | Not supported | Native |
| Debugging | "Why did it stop?" | Plan + state + log |
| Workflow drift | Possible | Snapshot in plan |

---

## Open Questions

### Resolved

1. ~~**Ephemeral vs Persistent Plans**~~: **RESOLVED** - All plans are persisted to `.fractary/logs/faber/plans/`. Even `/faber:run` creates a visible plan for debugging and audit purposes.

2. ~~**Failure Handling**~~: **RESOLVED** - Fail-safe mode. Items continue independently; failures aggregated at end.

3. ~~**Existing Branch Handling**~~: **RESOLVED** - Resume mode. Detect existing state and continue from last checkpoint.

4. ~~**Worktree Cleanup**~~: **RESOLVED** - Automatic cleanup on PR merge.

5. ~~**Pre-validation**~~: **RESOLVED** - No pre-validation. Trust the plan, fail fast per item during execution.

### Still Open

1. **Plan Expiration**: Do old plans need cleanup? (Consider log rotation policies)
2. **Partial Execution**: How to handle "execute items 2-4 of plan"? (Currently: `--items 401,402`)
3. **Cross-Repo Plans**: Can a plan span multiple repositories? (Future consideration)

---

## Related Issues

- **#309**: faber-director premature termination (immediate trigger)
- **#304**: Workflow inheritance resolution
- **#300**: Premature termination (earlier instance)
- **#290**: faber-manager hallucinating completion

---

## Next Steps

1. [x] Review and refine this spec
2. [x] Create GitHub issue for implementation (#314)
3. [ ] Phase 1: Simplify faber-director (fix #309)
4. [ ] Phase 2: Add plan artifact generation
5. [ ] Phase 3: Create /faber:execute command
6. [ ] Phase 4: Add parallel execution support

---

## Changelog

### 2025-12-08: Initial Refinement

**Questions Addressed:**

| Question | Decision |
|----------|----------|
| Plan ID format | Hierarchical: `{org}-{project}-{subproject}-{timestamp}` for analytics readiness |
| Plan persistence | Saved to `.fractary/logs/faber/plans/` (not ephemeral) |
| Failure mode | Fail-safe: continue other items, aggregate failures |
| Existing branches | Resume mode: detect state and continue from checkpoint |
| Pre-validation | None: trust plan, fail fast per item |
| Worktree cleanup | Automatic on PR merge |

**Sections Added:**
- §5: Plan ID Naming Convention
- §6: Fail-Safe Parallel Execution
- §7: Resume Mode for Existing Branches
- §8: Automatic Worktree Cleanup
- Storage rationale for log-based plan persistence

**Open Questions Resolved:** 5 of 8
