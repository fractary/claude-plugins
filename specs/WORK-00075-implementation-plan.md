# Implementation Plan: FABER Manager Architecture Refactor

**Issue:** #214
**Spec:** WORK-00075-faber-manager-agent-refactor.md
**Branch:** feat/214-refactor-faber-manager-architecture

## Executive Summary

Refactor the FABER manager architecture to eliminate the redundant pass-through pattern where:
- **Current:** Agent (177 lines) → Skill (1,174 lines)
- **After:** Agent (~800 lines, contains orchestration) → Helper Skills (focused utilities)

## Key Discovery: Existing Scripts

The `core` skill already contains scripts for config, state, and hooks:

```
skills/core/scripts/
├── config-init.sh, config-loader.sh, config-validate.sh
├── state-init.sh, state-read.sh, state-write.sh, state-update-phase.sh, state-validate.sh, state-backup.sh, state-cancel.sh
├── hook-execute.sh, hook-list.sh, hook-test.sh, hook-validate.sh
└── workflow-*, template-*, diagnostics.sh, error-*.sh, lock-*.sh
```

**Strategy:** Create new focused skills that leverage these existing scripts rather than duplicating code.

---

## Phase 1: Create Helper Skills (Non-Breaking)

These skills can be added without changing existing behavior.

### 1.1 Create `faber-config` Skill

**Purpose:** Load and validate FABER configuration

**Location:** `plugins/faber/skills/faber-config/`

**Files to Create:**
```
skills/faber-config/
├── SKILL.md          # Skill definition (~150 lines)
└── scripts/
    └── (symlink or copy from core)
```

**Operations:**
| Operation | Script | Description |
|-----------|--------|-------------|
| `load-config` | `config-loader.sh` | Load `.fractary/plugins/faber/config.json` |
| `load-workflow` | NEW `workflow-loader.sh` | Load workflow definition from file |
| `validate-config` | `config-validate.sh` | Validate config against schema |
| `get-phases` | NEW `phases-extract.sh` | Extract phase definitions from workflow |

**SKILL.md Structure:**
```markdown
<CONTEXT>
Skill for loading and validating FABER configuration files.
Provides deterministic operations for config management.
</CONTEXT>

<OPERATIONS>
- load-config: Load main configuration file
- load-workflow: Load workflow definition
- validate-config: Validate against schema
- get-phases: Extract phase definitions
</OPERATIONS>

<WORKFLOW>
1. Receive operation request
2. Execute appropriate script
3. Return structured JSON result
</WORKFLOW>
```

**Tasks:**
- [ ] Create `skills/faber-config/SKILL.md`
- [ ] Create `scripts/workflow-loader.sh` (extract workflow from config)
- [ ] Create `scripts/phases-extract.sh` (extract phase defs)
- [ ] Test: `load-config` returns valid JSON
- [ ] Test: `validate-config` catches schema errors

---

### 1.2 Create `faber-state` Skill

**Purpose:** Manage workflow state (CRUD operations)

**Location:** `plugins/faber/skills/faber-state/`

**Files to Create:**
```
skills/faber-state/
├── SKILL.md          # Skill definition (~200 lines)
└── scripts/
    └── (leverage existing core scripts)
```

**Operations:**
| Operation | Script | Description |
|-----------|--------|-------------|
| `init-state` | `state-init.sh` | Create new workflow state |
| `read-state` | `state-read.sh` | Read current state |
| `update-phase` | `state-update-phase.sh` | Update phase status |
| `update-step` | NEW `state-update-step.sh` | Update step status |
| `record-artifact` | NEW `state-record-artifact.sh` | Add artifact to state |
| `mark-complete` | NEW `state-mark-complete.sh` | Mark workflow complete/failed |
| `validate-state` | `state-validate.sh` | Validate state structure |
| `backup-state` | `state-backup.sh` | Create state backup |

**SKILL.md Key Sections:**

```markdown
<CONTEXT>
Skill for managing FABER workflow state files.
Handles state initialization, updates, and validation.
State location: `.fractary/plugins/faber/state.json`
</CONTEXT>

<OPERATIONS>
- init-state: Create new workflow state for work_id
- read-state: Load current state
- update-phase: Update phase status (pending/in_progress/completed/failed)
- update-step: Update step status within a phase
- record-artifact: Add artifact (spec, branch, PR) to state
- mark-complete: Mark workflow as completed or failed
</OPERATIONS>

<STATE_STRUCTURE>
{
  "workflow_id": "default",
  "work_id": "123",
  "status": "in_progress",
  "current_phase": "build",
  "phases": {
    "frame": {"status": "completed", "started_at": "...", "completed_at": "..."},
    "architect": {"status": "completed", ...},
    "build": {"status": "in_progress", "steps": [...]},
    ...
  },
  "artifacts": {
    "spec_path": "specs/WORK-00123-feature.md",
    "branch_name": "feat/123-feature",
    "pr_url": null
  },
  "retry_count": 0,
  "created_at": "...",
  "updated_at": "..."
}
</STATE_STRUCTURE>
```

**Tasks:**
- [ ] Create `skills/faber-state/SKILL.md`
- [ ] Create `scripts/state-update-step.sh`
- [ ] Create `scripts/state-record-artifact.sh`
- [ ] Create `scripts/state-mark-complete.sh`
- [ ] Test: Full state lifecycle (init → update → complete)
- [ ] Test: Resume from existing state

---

### 1.3 Create `faber-hooks` Skill

**Purpose:** Execute pre/post phase hooks

**Location:** `plugins/faber/skills/faber-hooks/`

**Files to Create:**
```
skills/faber-hooks/
├── SKILL.md          # Skill definition (~150 lines)
└── scripts/
    └── (leverage existing core scripts)
```

**Operations:**
| Operation | Script | Description |
|-----------|--------|-------------|
| `list-hooks` | `hook-list.sh` | List hooks for a phase boundary |
| `execute-hook` | `hook-execute.sh` | Execute a single hook |
| `execute-all` | NEW `hooks-execute-all.sh` | Execute all hooks for boundary |
| `validate-hooks` | `hook-validate.sh` | Validate hook configuration |

**SKILL.md Key Sections:**

```markdown
<CONTEXT>
Skill for executing FABER phase hooks.
Hooks are defined in workflow config and run at phase boundaries.
Hook types: document (read instruction), script (execute), skill (invoke)
</CONTEXT>

<HOOK_BOUNDARIES>
10 hook points total (pre/post for each of 5 phases):
- pre_frame, post_frame
- pre_architect, post_architect
- pre_build, post_build
- pre_evaluate, post_evaluate
- pre_release, post_release
</HOOK_BOUNDARIES>

<OPERATIONS>
- list-hooks: Get hooks configured for a boundary
- execute-hook: Execute single hook (document/script/skill)
- execute-all: Execute all hooks for a phase boundary
- validate-hooks: Validate hook definitions
</OPERATIONS>
```

**Tasks:**
- [ ] Create `skills/faber-hooks/SKILL.md`
- [ ] Create `scripts/hooks-execute-all.sh`
- [ ] Test: Hook discovery for each boundary
- [ ] Test: Hook execution (all 3 types)

---

## Phase 2: Refactor Manager Agent (Breaking Change)

Move orchestration logic from skill to agent.

### 2.1 Agent Structure Design

**Current Agent** (177 lines):
```markdown
# Just a wrapper
1. Receive request
2. Invoke faber-manager skill
3. Return result
```

**Refactored Agent** (~800 lines):
```markdown
# Orchestration engine

<CONTEXT>
Universal FABER workflow orchestrator.
Owns the complete workflow lifecycle: Frame → Architect → Build → Evaluate → Release
Has direct tool access for state management and user interaction.
</CONTEXT>

<TOOLS>
- Skill (invoke helper skills and phase skills)
- Bash (execute scripts)
- Read/Write (direct file access)
- AskUserQuestion (approval gates)
</TOOLS>

<WORKFLOW>
## Step 1: Load Configuration
Invoke faber-config skill: load-config

## Step 2: Load or Create State
Invoke faber-state skill: read-state or init-state

## Step 3: Initialize Logging
Invoke fractary-logs:workflow-event-emitter

## Step 4: Determine Execution Scope
Parse start_from_phase, stop_at_phase, phase_only parameters

## Step 5: Phase Orchestration Loop
FOR each phase in [frame, architect, build, evaluate, release]:

  ### Pre-Phase
  - Check if phase enabled
  - Check execution scope
  - Invoke faber-state: update-phase (in_progress)
  - Invoke faber-hooks: execute-all (pre_{phase})

  ### Automatic Entry Primitives
  IF phase == architect:
    - Classify work type (ANALYSIS/SIMPLE/MODERATE/COMPLEX)
  IF phase == build:
    - Create branch (if not exists in state)
    - Create worktree (if configured)

  ### Phase Execution
  FOR each step in phase.steps:
    - Update step status
    - Execute step (invoke skill or follow instruction)
    - Capture artifacts
    - Update state with results

  ### Automatic Exit Primitives
  IF phase == release:
    - Create PR (if commits exist and not in state)

  ### Post-Phase
  - Validate phase completion
  - Invoke faber-hooks: execute-all (post_{phase})
  - Invoke faber-state: update-phase (completed)
  - Check autonomy gates (AskUserQuestion if needed)

  ### Retry Logic (Build-Evaluate)
  IF phase == evaluate AND result == FAIL:
    - Increment retry_count
    - IF retry_count < max_retries: GOTO build
    - ELSE: Mark workflow failed

## Step 6: Completion
- Invoke faber-state: mark-complete
- Generate summary
- Return results
</WORKFLOW>

<AUTOMATIC_PRIMITIVES>
## Work Type Classification (Architect Entry)
Analyze issue metadata to determine:
- ANALYSIS: Research, investigation, no code changes
- SIMPLE: Typo fix, config change, < 50 lines
- MODERATE: Single feature, single component
- COMPLEX: Multiple components, architectural changes

## Branch Creation (Build Entry)
Automatically create branch if:
- work_type expects commits (not ANALYSIS)
- branch not already recorded in state
Uses: /repo:branch-create --work-id {work_id}

## PR Creation (Release Exit)
Automatically create PR if:
- commits exist on branch
- PR not already recorded in state
- autonomy level allows
Uses: /repo:pr-create
</AUTOMATIC_PRIMITIVES>

<AUTONOMY_GATES>
Based on config autonomy.level and autonomy.require_approval_for:
- dry-run: No actual changes, just log what would happen
- assist: Stop before release for approval
- guarded: Execute fully, pause at release for confirmation
- autonomous: Execute without pauses
</AUTONOMY_GATES>
```

### 2.2 Migration Strategy

**Step-by-step migration:**

1. **Create new agent file** as `agents/faber-manager-v2.md`
2. **Implement orchestration logic** section by section:
   - Configuration loading (using faber-config skill)
   - State management (using faber-state skill)
   - Phase loop structure
   - Automatic primitives
   - Hook execution (using faber-hooks skill)
   - Autonomy gates
3. **Test in parallel** with existing agent
4. **Swap files**: Rename `faber-manager.md` → `faber-manager-v1.md`, `faber-manager-v2.md` → `faber-manager.md`
5. **Verify all commands still work**

**Tasks:**
- [ ] Create `agents/faber-manager-v2.md` scaffold
- [ ] Implement Step 1: Configuration loading
- [ ] Implement Step 2: State management
- [ ] Implement Step 3: Logging initialization
- [ ] Implement Step 4: Execution scope
- [ ] Implement Step 5: Phase orchestration loop
- [ ] Implement automatic primitives (classify, branch, PR)
- [ ] Implement autonomy gates
- [ ] Implement Step 6: Completion handling
- [ ] Add error handling throughout
- [ ] Test with simple workflow
- [ ] Test with full workflow
- [ ] Swap agent files

---

## Phase 3: Integration Testing

### 3.1 Test Scenarios

| Test | Command | Expected Outcome |
|------|---------|-----------------|
| Single issue workflow | `/faber:run 214` | Full FABER cycle completes |
| Phase-only execution | `/faber:frame 214` | Only frame phase runs |
| Resume from state | `/faber:run 214` (after interrupt) | Resumes from current phase |
| Parallel execution | `/faber:run 100-105` | Multiple workflows in worktrees |
| Approval gate | `/faber:run 214 --autonomy guarded` | Pauses at release |
| Retry loop | (failing tests) | Build-Evaluate retries |
| Dry run | `/faber:run 214 --autonomy dry-run` | No changes, logs actions |

### 3.2 Verification Checklist

- [ ] `/faber:init` creates valid config
- [ ] `/faber:status` reads state correctly
- [ ] `/faber:run` executes full workflow
- [ ] `/faber:frame` executes single phase
- [ ] State file updates correctly at each step
- [ ] Hooks execute at correct boundaries
- [ ] Artifacts recorded in state
- [ ] PR created automatically at release
- [ ] Retry loop works (max 3 retries)
- [ ] Autonomy gates pause correctly

---

## Phase 4: Cleanup

### 4.1 Files to Delete

After successful testing:

```
DELETE: skills/faber-manager/SKILL.md (1,174 lines)
DELETE: skills/faber-manager/workflow/automatic-primitives.md (405 lines)
DELETE: skills/faber-manager/ (entire directory)
```

### 4.2 Files to Update

```
UPDATE: agents/faber-manager.md (now contains orchestration)
UPDATE: .claude-plugin/plugin.json (remove faber-manager skill reference if any)
UPDATE: README.md (architecture documentation)
UPDATE: docs/ARCHITECTURE.md (if exists)
```

### 4.3 Documentation Updates

- [ ] Update architecture diagrams
- [ ] Update skill inventory
- [ ] Add migration notes
- [ ] Update CLAUDE.md references

---

## Risk Mitigation

### Risk 1: Breaking Existing Workflows
**Mitigation:**
- Create v2 agent alongside v1
- Test thoroughly before swap
- Keep v1 as backup initially

### Risk 2: Agent Becomes Too Large
**Mitigation:**
- Helper skills keep deterministic ops separate
- Agent focuses on orchestration decisions
- Can extract more helpers if needed

### Risk 3: Context Limits
**Mitigation:**
- Helper skills reduce agent context
- Scripts handle heavy lifting
- Lazy loading of workflow details

### Risk 4: Script Dependencies
**Mitigation:**
- Audit all script usages before moving
- Update paths in new skills
- Test each script independently

---

## Success Criteria

From the spec:

1. [ ] No `faber-manager` skill exists (only agent)
2. [ ] Manager agent contains orchestration logic (~800 lines)
3. [ ] Helper skills exist: faber-config, faber-state, faber-hooks
4. [ ] Helper skills are script-backed
5. [ ] All existing functionality preserved
6. [ ] All tests pass
7. [ ] Documentation updated

---

## Appendix: File Inventory

### Files to Create
| File | Lines | Purpose |
|------|-------|---------|
| `skills/faber-config/SKILL.md` | ~150 | Config loading skill |
| `skills/faber-config/scripts/workflow-loader.sh` | ~50 | Load workflow def |
| `skills/faber-config/scripts/phases-extract.sh` | ~30 | Extract phases |
| `skills/faber-state/SKILL.md` | ~200 | State management skill |
| `skills/faber-state/scripts/state-update-step.sh` | ~40 | Update step |
| `skills/faber-state/scripts/state-record-artifact.sh` | ~30 | Record artifact |
| `skills/faber-state/scripts/state-mark-complete.sh` | ~40 | Mark complete |
| `skills/faber-hooks/SKILL.md` | ~150 | Hook execution skill |
| `skills/faber-hooks/scripts/hooks-execute-all.sh` | ~60 | Execute all hooks |
| `agents/faber-manager.md` (rewrite) | ~800 | Orchestration agent |

### Files to Delete
| File | Lines | Reason |
|------|-------|--------|
| `skills/faber-manager/SKILL.md` | 1,174 | Consolidated into agent |
| `skills/faber-manager/workflow/automatic-primitives.md` | 405 | Logic moved to agent |

### Net Change
- **Before:** 1,579 lines in manager skill
- **After:** ~1,550 lines across agent + 3 helper skills
- **Result:** Similar size, better organization
