---
name: fractary-faber:execute
description: Execute a FABER plan created by /fractary-faber:plan, with optional resume support
argument-hint: '<plan-id> [--serial] [--max-concurrent <n>] [--items <ids>] [--resume]'
tools: Skill
model: claude-haiku-4-5
---

# FABER Execute Command

<CONTEXT>
You are the entry point for executing FABER plans.
Your job is to parse arguments and invoke the faber-executor skill.

This command executes a plan previously created by `/fractary-faber:plan`.
</CONTEXT>

<CRITICAL_RULES>
1. **IMMEDIATE DELEGATION** - Parse args, invoke faber-executor skill, return result
2. **PLAN REQUIRED** - Plan must exist in `logs/fractary/plugins/faber/plans/`
3. **MINIMAL PROCESSING** - Only parse arguments, nothing more
4. **USE SKILL TOOL** - Invoke faber-executor using the Skill tool, NOT Task tool
5. **NEVER USE TASK TOOL** - faber-executor is a SKILL, not an agent. Using Task tool will fail with "Agent type not found" error.
</CRITICAL_RULES>

<INPUTS>

**Syntax:**
```bash
/fractary-faber:execute <plan-id> [options]
```

**Arguments:**
| Argument | Type | Required | Description |
|----------|------|----------|-------------|
| `<plan-id>` | string | Yes | Plan ID to execute |

**Options:**
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--serial` | flag | false | Run items sequentially instead of parallel |
| `--max-concurrent <n>` | number | 5 | Maximum parallel executions |
| `--items <ids>` | string | all | Comma-separated work_ids to execute |
| `--resume` | flag | false | Resume from exact step where execution stopped |

**Examples:**
```bash
# Execute all items in plan
/fractary-faber:execute fractary-claude-plugins-csv-export-20251208T160000

# Execute in serial mode
/fractary-faber:execute fractary-claude-plugins-csv-export-20251208T160000 --serial

# Limit concurrency
/fractary-faber:execute fractary-claude-plugins-csv-export-20251208T160000 --max-concurrent 3

# Execute specific items only
/fractary-faber:execute fractary-claude-plugins-csv-export-20251208T160000 --items 123,124

# Retry failed items
/fractary-faber:execute fractary-claude-plugins-csv-export-20251208T160000 --items 125

# Resume from where execution stopped (exact step)
/fractary-faber:execute fractary-claude-plugins-csv-export-20251208T160000 --resume

# Resume specific items from their exact step
/fractary-faber:execute fractary-claude-plugins-csv-export-20251208T160000 --items 123 --resume
```

</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from user input:
1. `plan_id`: First positional argument (required)
2. `serial`: Presence of `--serial` flag
3. `max_concurrent`: Value of `--max-concurrent` flag
4. `items`: Value of `--items` flag
5. `resume`: Presence of `--resume` flag

**Validation:**
- If no `plan_id`: show error

## Step 2: Invoke faber-executor Skill

**IMPORTANT:** Use the Skill tool to invoke the faber-executor skill.

**EXACT INVOCATION** (copy this exactly):
```
Skill(skill="faber-executor")
```

**DO NOT USE:**
```
Task(subagent_type="fractary-faber:faber-executor")  ← THIS WILL FAIL
```

The faber-executor is a **SKILL**, not an agent. Using Task tool will produce:
```
Error: Agent type 'fractary-faber:faber-executor' not found
```

**Provide the following context in your invocation:**
- plan_id: {plan_id}
- serial: {serial or false}
- max_concurrent: {max_concurrent or 5}
- items: {items or null}
- resume: {resume or false}
- working_directory: {pwd}

The skill name is `faber-executor` (short form, without namespace prefix).

## Step 3: Return Response

Return the faber-executor skill's output directly.

</WORKFLOW>

<OUTPUTS>

**Success:**
The faber-executor skill's output showing execution results.

**Missing Plan ID Error:**
```
Error: Plan ID is required

Usage: /fractary-faber:execute <plan-id> [options]

Examples:
  /fractary-faber:execute fractary-project-feature-20251208T160000
  /fractary-faber:execute my-plan-id --serial

List available plans:
  ls logs/fractary/plugins/faber/plans/
```

**Plan Not Found Error:**
```
Error: Plan not found: invalid-plan-id

Check available plans:
  ls logs/fractary/plugins/faber/plans/

Or create a new plan:
  /fractary-faber:plan --work-id 123
```

</OUTPUTS>

<WARNING>
**Common Mistake: Do not confuse faber-executor (a skill) with faber-manager (an agent).**

| Component | Type | How to Invoke |
|-----------|------|---------------|
| faber-executor | **Skill** | `Skill(skill="faber-executor")` |
| faber-manager | **Agent** | `Task(subagent_type="fractary-faber:faber-manager")` |

The faber-executor skill is responsible for orchestrating plan execution. It internally spawns faber-manager agents for each work item using the Task tool.

**Your job** (this command): Invoke faber-executor as a skill.
**Executor's job**: Spawn faber-manager agents for each item.

If you use Task tool to invoke faber-executor, you will get:
```
Error: Agent type 'fractary-faber:faber-executor' not found
```

This bypasses the executor's orchestration logic (parallel execution, resume support, results aggregation).
</WARNING>

<NOTES>

## Two-Phase Architecture

```
/fractary-faber:plan
    ↓
faber-planner agent (invoked via Task tool)
    ↓
Plan artifact saved to logs/fractary/plugins/faber/plans/
    ↓
User reviews plan
    ↓
/fractary-faber:execute <plan-id> (THIS COMMAND)
    ↓
faber-executor skill (invoked via Skill tool)
    ↓
faber-manager agent(s) (spawned via Task tool by executor)
    ↓
Results aggregated
```

## Skill vs Agent Invocation

- **Skills** are invoked using the `Skill` tool: `Skill(skill="skill-name")`
- **Agents** are invoked using the `Task` tool: `Task(subagent_type="agent-name")`

The faber-executor is a **skill**, so use the Skill tool.
The faber-manager is an **agent**, which the executor skill will spawn using Task tool.

## Fail-Safe Execution

The executor uses fail-safe mode:
- Each item runs independently
- If one fails, others continue
- Failures aggregated at end

To retry failed items, use `--items` with the failed work_ids.

## Resume Support (Exact-Step)

The `--resume` flag enables resuming execution from the **exact step** where it stopped, not from phase start.

**How it works:**
1. Each plan item has a `run_id` linking it to workflow state
2. State tracks `current_phase` and `current_step_index`
3. Resume reads state and continues from exact position

**State location:** `.fractary/plugins/faber/state.json`

**Resume behavior:**
- Without `--resume`: Starts from beginning (fresh execution)
- With `--resume`: Reads state, continues from `current_step_index`
- With `--resume --items 123`: Resume only item 123 from its exact step

**Example state structure:**
```json
{
  "run_id": "fractary-claude-plugins-abc123",
  "plan_id": "fractary-claude-plugins-csv-export-20251208T160000",
  "work_id": 123,
  "current_phase": "build",
  "current_step_index": 2,
  "steps_completed": ["generate-spec", "create-branch"],
  "status": "in_progress"
}
```

## See Also

- `/fractary-faber:plan` - Create a plan
- `/fractary-faber:run` - Create and execute plan in one step
- `/fractary-faber:status` - Check workflow status

</NOTES>
