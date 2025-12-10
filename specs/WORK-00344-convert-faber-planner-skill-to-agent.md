# WORK-00344: Convert faber-planner Skill to Agent

**Issue**: [#344](https://github.com/fractary/claude-plugins/issues/344)
**Type**: Refactor
**Created**: 2025-12-10
**Refined**: 2025-12-10
**Branch**: `refactor/344-convert-faber-planner-skill-to-agent-for-reliable-invocation`

---

## Problem Statement

The Skill tool is not being reliably invoked by Claude. When the `/fractary-faber:plan` command instructs Claude to "invoke the faber-planner skill," Claude inconsistently:

1. **Uses the Skill tool correctly** (desired behavior)
2. **Uses Task tool with general-purpose agent** to approximate the skill's behavior (wrong)
3. **Does the work directly** without invoking anything (wrong)

This was observed in a real session where `/fractary-faber:plan --work-id 335` was executed. Instead of invoking the `faber-planner` skill via the Skill tool, Claude used the Task tool with a general-purpose agent to create the plan artifact itself.

## Root Cause Analysis

Claude's analysis of the behavior:

> The Skill tool semantics ("run this command") can be interpreted as "do what this command does" rather than "call this specific skill."

> The Task tool has clearer "hand off and wait" semantics that result in more reliable delegation.

Key insight: The Task tool's agent invocation pattern creates explicit delegation, while the Skill tool pattern can be confused with "do the work yourself."

## Proposed Solution

Convert `faber-planner` from a **skill** to an **agent** that is invoked via the Task tool.

### Why This Should Work

1. **Task tool semantics are clearer**: "spawn specialized agent, wait for result"
2. **Skill tool semantics are ambiguous**: "run this command" can be interpreted as "do what this does"
3. **Agents have established patterns**: Claude already reliably uses agents like `fractary-repo:repo-manager`

## Implementation Plan

### Step 1: Create Agent File

**File**: `plugins/faber/agents/faber-planner.md`

Transform the skill SKILL.md content to agent format with YAML frontmatter:

```markdown
---
name: faber-planner
description: Creates FABER execution plans without executing them. Phase 1 of two-phase architecture.
model: claude-opus-4-5
tools:
  - Skill
  - SlashCommand
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# FABER Planner Agent

<CONTEXT>
You are the **FABER Planner**, responsible for creating execution plans.
...
</CONTEXT>

<CRITICAL_RULES>
...
</CRITICAL_RULES>

<WORKFLOW>
...
</WORKFLOW>

<OUTPUTS>
...
</OUTPUTS>
```

**Key decisions:**
- **Model**: Use `claude-opus-4-5` (more reliable for complex planning)
- **Tools**: Keep same tools as skill via YAML frontmatter
- **Skill invocation**: Agent CAN invoke other skills (e.g., `faber-config`) via Skill tool

The content should be largely the same as `plugins/faber/skills/faber-planner/SKILL.md`, adapted to agent XML structure.

### Step 2: Update Plugin Manifest

**File**: `plugins/faber/.claude-plugin/plugin.json`

Add faber-planner to the agents array:

```json
{
  "name": "fractary-faber",
  "version": "3.0.0",
  "description": "FABER workflow orchestration plugin",
  "commands": "./commands/",
  "agents": [
    "./agents/faber-director.md",
    "./agents/faber-manager.md",
    "./agents/faber-planner.md"
  ],
  "skills": "./skills/"
}
```

### Step 3: Update Plan Command

**File**: `plugins/faber/commands/plan.md`

Change from Skill tool invocation to Task tool invocation:

**Before** (current):
```markdown
## Step 2: Invoke faber-planner Skill

Skill: faber-planner
Parameters:
  target: {target or null}
  work_id: {work_id or null}
  ...
```

**After** (new):
```markdown
## Step 2: Invoke faber-planner Agent

Use the Task tool with:
- subagent_type: "fractary-faber:faber-planner"
- description: "Create FABER plan for work item {work_id}"
- prompt: JSON with parsed parameters

Task(
  subagent_type="fractary-faber:faber-planner",
  description="Create FABER plan for work item {work_id}",
  prompt='{
    "target": "{target or null}",
    "work_id": "{work_id}",
    "workflow_override": "{workflow_override or null}",
    "autonomy_override": "{autonomy_override or null}",
    "phases": "{phases or null}",
    "step_id": "{step_id or null}",
    "prompt": "{prompt or null}",
    "working_directory": "{pwd}"
  }'
)
```

### Step 4: Remove Existing Skill

**Decision**: Remove the skill entirely (no deprecation period needed)

- Delete `plugins/faber/skills/faber-planner/` directory
- This is an internal refactor with no external consumers
- Clean removal avoids confusion about which to use

### Step 5: Update Documentation

Update any references to faber-planner as a skill:
- `plugins/faber/docs/` if it mentions the skill
- `CLAUDE.md` if it references planner invocation patterns
- Any workflow documentation

## Files to Modify

| File | Action |
|------|--------|
| `plugins/faber/agents/faber-planner.md` | CREATE - New agent file |
| `plugins/faber/.claude-plugin/plugin.json` | EDIT - Add to agents array |
| `plugins/faber/commands/plan.md` | EDIT - Change to Task tool invocation |
| `plugins/faber/skills/faber-planner/` | DELETE - Remove skill directory |

## Success Criteria

1. `/fractary-faber:plan --work-id <id>` invokes the faber-planner agent via Task tool
2. Plan artifacts are created correctly (same output as before)
3. No fallback to general-purpose agent or direct execution
4. Existing plan functionality is preserved

## Testing

1. Run `/fractary-faber:plan --work-id <test-id>`
2. Verify Task tool is used with `subagent_type="fractary-faber:faber-planner"`
3. Verify plan artifact is created at expected location
4. Verify plan content matches expected format

## Scope Boundaries

**In Scope**:
- Convert faber-planner skill to agent
- Update plan command to use Task tool
- Remove/deprecate old skill

**Out of Scope**:
- faber-executor (remains a skill per issue description)
- Other faber skills
- Changes to plan artifact format

## Notes

- The faber-executor skill should remain as a skill - this issue is specifically about faber-planner
- This pattern may be applied to other critical skills if this proves successful
- The architectural question of skills vs agents for reliability is worth tracking

---

## Changelog

### 2025-12-10 - Refinement Round 1
**Questions answered:**
1. **Agent Tools**: Use YAML frontmatter (same format as skills)
2. **Model**: Use `claude-opus-4-5` for more reliable planning
3. **Skill Dependencies**: Agent CAN invoke other skills via Skill tool
4. **Cleanup**: Remove skill entirely (no deprecation needed)

---

*Generated from conversation context and GitHub issue #344*
