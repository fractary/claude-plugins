# WORK-00176: Fix FABER Issues - Worktree, Workflow Selection, Unknown Skill

**Issue**: [#176](https://github.com/fractary/claude-plugins/issues/176)
**Branch**: `fix/176-faber-issues-including-no-worktree-wrong-workflow-unknown-skill`
**Status**: Active
**Created**: 2025-12-01

## Summary

This specification addresses three related bugs encountered when running FABER workflows in external projects (specifically `corthosai/etl.corthion.ai`):

1. **Worktree Not Created** - FABER claims to create a worktree but doesn't actually create one
2. **Wrong Workflow Selected** - Uses first workflow in config instead of detecting from issue labels
3. **Unknown Skill Error** - "Unknown skill: faber-manager" when the faber-director skill tries to invoke the faber-manager agent

---

## Issue Analysis

### Issue 1: Worktree Not Created

**Reported Symptom**: FABER said it was creating a worktree but nothing appeared in `.worktrees/` directory.

**Root Cause Analysis**:

From the session log, the workflow was interrupted before the Frame phase completed:
1. faber-director said it would invoke faber-manager with `worktree: true`
2. faber-manager questioned the workflow mismatch (dataset-development vs dataset-evaluate)
3. The session was interrupted before any branch/worktree creation occurred

The worktree was never created because the **workflow never reached the Frame phase**. The execution chain was broken by:
1. The "Unknown skill: faber-manager" error (Issue 3) - prevented faber-director from invoking faber-manager
2. The wrong workflow selection (Issue 2) - caused faber-manager to question the mismatch and interrupt

**This is an INDIRECT fix**: By fixing Issues 2 and 3 (agent invocation and workflow detection), the workflow will now execute properly through to the Frame phase, which creates the worktree. The worktree creation code in `frame/workflow/basic.md` was already correct - it just never got executed.

**Verification**: The worktree parameter flow was audited and is correctly documented:
- `faber-director` passes `worktree: true` to faber-manager (lines 73-80 of faber-manager/SKILL.md)
- `faber-manager` passes `--worktree` to repo-manager (line 80)
- `frame/workflow/basic.md` shows `worktree: true` in branch creation (lines 138-151)

### Issue 2: Wrong Workflow Selected

**Reported Symptom**: FABER started with `dataset-development` workflow when `dataset-evaluate` was clearly indicated in the issue labels (`workflow:dataset-evaluate`, `faber:dataset-evaluate`).

**Root Cause**: The `/faber:manage` command defaults to "first workflow in config" (line 54 of `faber-manage.md`):
```markdown
- `--workflow <id>`: Workflow ID to use (default: uses first workflow in config)
```

**Current Flow**:
```
1. User runs: /faber:manage 48
2. Command loads config.json
3. No --workflow flag provided
4. Command uses FIRST workflow (dataset-development)
5. Wrong workflow passed to faber-director
```

**Expected Flow**:
```
1. User runs: /faber:manage 48
2. Command fetches issue #48 labels
3. Detects workflow:dataset-evaluate label
4. Loads dataset-evaluate workflow from config
5. Correct workflow passed to faber-director
```

**Fix Required**: Add workflow detection from issue labels BEFORE defaulting to first workflow.

**Note**: Only `workflow:*` labels are recognized (not `faber:*`) to avoid confusion.

### Issue 3: Unknown Skill Error

**Reported Symptom**: Error "Unknown skill: faber-manager" when faber-director skill tries to invoke faber-manager.

**Root Cause Analysis**:

The architecture has a type mismatch:
- `faber-director` is a **SKILL** (invoked via Skill tool)
- `faber-manager` is an **AGENT** (invoked via Task tool with subagent_type)

**Current Architecture**:
```
/faber:manage command
    ↓ (Skill tool)
faber-director SKILL
    ↓ (Skill tool - WRONG!)
faber-manager AGENT → ERROR: "Unknown skill"
```

**The Error Occurs Because**:
The faber-director skill documentation says to invoke faber-manager using Task tool, but somewhere in the execution chain, it may be attempting to use Skill tool instead.

**Clarification from Issue Comments**:
> "I do think the assumption that a skill cannot invoke an agent is incorrect."

**Correct Behavior**: A skill CAN invoke an agent using the Task tool. The issue is likely:
1. **Incorrect tool usage** - Using `Skill(skill="faber-manager")` instead of `Task(subagent_type="fractary-faber:faber-manager")`
2. **Missing `fractary-` prefix** - Using `faber-manager` instead of `fractary-faber:faber-manager`
3. **Old agent artifact** - The archived `faber-director.md` agent (now in `agents/archived/`) may be causing confusion

---

## Implementation Plan

### Fix 1: Workflow Detection from Labels

**Location**: `plugins/faber/commands/faber-manage.md`

**Changes**:

Add new Step 1.5 between argument parsing and configuration loading:

```markdown
## Step 1.5: Detect Workflow from Issue Labels

**BEFORE defaulting to first workflow, detect from issue labels:**

1. Fetch issue details using work plugin:
   ```
   Invoke /work:issue-fetch {work_id} using SlashCommand tool
   ```

2. Extract workflow from labels:
   - Look for `workflow:{workflow_id}` pattern (e.g., `workflow:dataset-evaluate`)
   - Only `workflow:*` labels are recognized (not `faber:*`) to avoid confusion

3. Set detected workflow:
   - If label found: Use detected workflow_id
   - If no label: Continue to use --workflow flag or first workflow

**Priority Order**:
1. Explicit `--workflow` flag (highest priority - user override)
2. Label detection (`workflow:*`)
3. First workflow in config (fallback)
```

**Validation**:
- Verify detected workflow exists in configuration
- Warn if label indicates workflow not found in config

### Fix 2: Verify Worktree Parameter Flow

**Locations to Check**:
1. `plugins/faber/skills/faber-director/SKILL.md` - Pass `worktree: true` to faber-manager
2. `plugins/faber/skills/faber-manager/SKILL.md` - Pass `--worktree` to repo plugin
3. `plugins/faber/skills/frame/workflow/basic.md` - Invoke branch creation with worktree

**Changes**:

In `faber-director/SKILL.md`, ensure worktree parameter is documented and passed:
```markdown
**Build Parameters**:
{
  "work_id": "158",
  "source_type": "github",
  "source_id": "158",
  "autonomy": "guarded",
  "worktree": true  // ALWAYS true - critical for isolation
}
```

In `faber-manager/SKILL.md`, ensure Frame phase invokes repo with `--worktree`:
```markdown
When executing Frame phase branch creation:
- ALWAYS pass --worktree flag to /repo:branch-create
- Example: /repo:branch-create "description" --work-id {work_id} --worktree
```

In `frame/workflow/basic.md`, verify the actual branch creation command includes `--worktree`.

### Fix 3: Correct Agent Invocation in faber-director

**Location**: `plugins/faber/skills/faber-director/SKILL.md`

**Changes**:

Update the invocation section to be explicit about Task tool usage:

```markdown
## Step 3: Route to Execution

### Single Work Item Execution

**CRITICAL**: Use Task tool, NOT Skill tool, to invoke faber-manager agent.

**Correct Invocation**:
```
Task(
  subagent_type="fractary-faber:faber-manager",
  description="Execute FABER workflow for issue #158",
  prompt='{
    "work_id": "158",
    "source_type": "github",
    "source_id": "158",
    "autonomy": "guarded",
    "worktree": true
  }'
)
```

**WRONG - Will fail with "Unknown skill" error**:
```
Skill(skill="faber-manager")  // WRONG - faber-manager is an AGENT, not a skill
Skill(skill="fractary-faber:faber-manager")  // WRONG - still using Skill tool
```

**Key Points**:
1. faber-manager is an AGENT (defined in agents/faber-manager.md)
2. Agents are invoked via Task tool with subagent_type parameter
3. Skills are invoked via Skill tool
4. ALWAYS use full prefix: "fractary-faber:faber-manager"
```

### Fix 4: Clean Up Old Artifacts

**Action**: Verify archived agents don't cause confusion

**Files to Check**:
- `plugins/faber/agents/archived/` - Contains old agents that should not be used
- Ensure the archived directory is excluded from agent discovery

**Potential Issue**: If the old `faber-director.md` agent (now archived) is still being discovered by the plugin system, it could conflict with the new `faber-director` skill.

### Fix 5: Add Prefix Consistency Check

**Issue Comment**:
> "something else to consider, I frequently see reference to commands without the fractary- prefix and wonder if that ever is the source of issues with not finding things"

**Action**: Audit all invocations for consistent prefix usage:

| Component | Correct | Incorrect |
|-----------|---------|-----------|
| Agent | `fractary-faber:faber-manager` | `faber-manager` |
| Skill | `fractary-faber:faber-director` | `faber-director` |
| Command | `/fractary-faber:manage` | `/faber:manage` |

**Changes**:
- Update all documentation to use full `fractary-` prefix consistently
- Add note about prefix requirements in CLAUDE.md

---

## Files to Modify

### Primary Changes

1. **`plugins/faber/commands/faber-manage.md`**
   - Add workflow detection from labels (Step 1.5)
   - Update priority order for workflow selection

2. **`plugins/faber/skills/faber-director/SKILL.md`**
   - Clarify Task tool usage for agent invocation
   - Add explicit "WRONG" examples to prevent confusion
   - Ensure worktree parameter is always true

3. **`plugins/faber/skills/frame/workflow/basic.md`**
   - Verify `--worktree` flag is passed to branch creation
   - Add explicit worktree creation step if missing

### Secondary Changes

4. **`plugins/faber/skills/faber-manager/SKILL.md`**
   - Add worktree parameter documentation
   - Clarify that worktree is passed to Frame phase

5. **`CLAUDE.md`**
   - Add note about `fractary-` prefix requirement
   - Clarify agent vs skill invocation patterns

---

## Testing Plan

### Test Case 1: Workflow Label Detection

**Setup**:
1. Create issue with label `workflow:dataset-evaluate`
2. Configure project with multiple workflows including `dataset-evaluate`

**Test**:
```bash
/faber:manage {issue_number}
# Without --workflow flag
```

**Expected**:
- FABER detects `workflow:dataset-evaluate` label
- Uses `dataset-evaluate` workflow (NOT first in config)
- Logs: "Detected workflow from label: dataset-evaluate"

### Test Case 2: Worktree Creation

**Setup**:
1. Create issue
2. Run FABER workflow

**Test**:
```bash
/faber:manage {issue_number}
```

**Expected**:
- Worktree created at `.worktrees/{branch-slug}/`
- Workflow executes within worktree
- State file in worktree: `.worktrees/{branch-slug}/.fractary/plugins/faber/state.json`

### Test Case 3: Agent Invocation

**Setup**:
1. Create issue
2. Trigger faber-director skill

**Test**:
```bash
/faber:manage {issue_number}
```

**Expected**:
- faber-director skill invokes faber-manager agent successfully
- No "Unknown skill" error
- Task tool used (not Skill tool)

### Test Case 4: Prefix Consistency

**Test**:
- Search codebase for inconsistent prefix usage
- Verify all invocations use `fractary-` prefix

```bash
grep -r "subagent_type.*faber" plugins/faber/ | grep -v "fractary-faber"
# Should return no results
```

---

## Architecture Notes

### Three-Layer Architecture Defense

The issue comments question whether three-layer architecture (command → director → manager) adds complexity. Here's the defense:

**Benefits of faber-director as Skill**:

1. **Parallelization**: Can spawn multiple faber-manager agents in a single Task tool call
2. **Intent Parsing**: Complex natural language parsing isolated from orchestration
3. **Context Efficiency**: Skill runs in same context as command, preserving conversation
4. **Composability**: Can be invoked by other skills, GitHub webhooks, CLI commands

**If we removed faber-director**:
- Command would need to implement parallelization logic
- Command would become more complex
- Intent parsing would be mixed with routing
- Harder to test in isolation

**Recommendation**: Keep three-layer architecture but ensure correct tool usage:
```
Command → Skill tool → faber-director (SKILL)
                           ↓
                      Task tool → faber-manager (AGENT)
                                      ↓
                                 Skill tool → phase skills
```

### Skills CAN Invoke Agents

Clarification for the record:
- Skills ARE able to invoke agents using the Task tool
- The error "Unknown skill: faber-manager" occurs when using Skill tool for an agent
- The fix is to use the correct tool (Task) with correct subagent_type

---

## Implementation Order

1. **Fix 3** (Agent Invocation) - Highest priority, blocking issue
2. **Fix 1** (Workflow Detection) - High priority, user-facing issue
3. **Fix 2** (Worktree Flow) - Medium priority, needs investigation
4. **Fix 5** (Prefix Consistency) - Low priority, preventive measure
5. **Fix 4** (Clean Up Artifacts) - Low priority, housekeeping

---

## Success Criteria

- [ ] FABER detects workflow from issue labels before defaulting
- [ ] Worktrees are created when `worktree: true` is specified
- [ ] No "Unknown skill" errors when invoking faber-manager
- [ ] All prefixes consistently use `fractary-` format
- [ ] Tests pass for all three issue scenarios
- [ ] Documentation updated with clarifications

---

## References

- Issue: [#176](https://github.com/fractary/claude-plugins/issues/176)
- Related: SPEC-00092 (Git Worktree Support)
- Related: WORK-00165 (FABER Run Command Agent Invocation)
- Architecture: `plugins/faber/docs/architecture.md`
