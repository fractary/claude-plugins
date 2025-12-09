---
name: fractary-faber:execute
description: Execute a FABER plan created by /faber:plan
argument-hint: '<plan-id> [--serial] [--max-concurrent <n>] [--items <ids>]'
tools: Skill
model: claude-haiku-4-5
---

# FABER Execute Command

<CONTEXT>
You are the entry point for executing FABER plans.
Your job is to parse arguments and invoke the faber-executor skill.

This command executes a plan previously created by `/faber:plan`.
</CONTEXT>

<CRITICAL_RULES>
1. **IMMEDIATE DELEGATION** - Parse args, invoke faber-executor, return result
2. **PLAN REQUIRED** - Plan must exist in `.fractary/logs/faber/plans/`
3. **MINIMAL PROCESSING** - Only parse arguments, nothing more
</CRITICAL_RULES>

<INPUTS>

**Syntax:**
```bash
/faber:execute <plan-id> [options]
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

**Examples:**
```bash
# Execute all items in plan
/faber:execute fractary-claude-plugins-csv-export-20251208T160000

# Execute in serial mode
/faber:execute fractary-claude-plugins-csv-export-20251208T160000 --serial

# Limit concurrency
/faber:execute fractary-claude-plugins-csv-export-20251208T160000 --max-concurrent 3

# Execute specific items only
/faber:execute fractary-claude-plugins-csv-export-20251208T160000 --items 123,124

# Retry failed items
/faber:execute fractary-claude-plugins-csv-export-20251208T160000 --items 125
```

</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from user input:
1. `plan_id`: First positional argument (required)
2. `serial`: Presence of `--serial` flag
3. `max_concurrent`: Value of `--max-concurrent` flag
4. `items`: Value of `--items` flag

**Validation:**
- If no `plan_id`: show error

## Step 2: Invoke faber-executor Skill

```
Skill: faber-executor
Parameters:
  plan_id: {plan_id}
  serial: {serial or false}
  max_concurrent: {max_concurrent or 5}
  items: {items or null}
  working_directory: {pwd}
```

## Step 3: Return Response

Return the faber-executor skill's output directly.

</WORKFLOW>

<OUTPUTS>

**Success:**
The faber-executor skill's output showing execution results.

**Missing Plan ID Error:**
```
Error: Plan ID is required

Usage: /faber:execute <plan-id> [options]

Examples:
  /faber:execute fractary-project-feature-20251208T160000
  /faber:execute my-plan-id --serial

List available plans:
  ls .fractary/logs/faber/plans/
```

**Plan Not Found Error:**
```
Error: Plan not found: invalid-plan-id

Check available plans:
  ls .fractary/logs/faber/plans/

Or create a new plan:
  /faber:plan --work-id 123
```

</OUTPUTS>

<NOTES>

## Two-Phase Architecture

```
/faber:plan
    ↓
faber-planner skill
    ↓
Plan artifact saved
    ↓
User reviews plan
    ↓
/faber:execute <plan-id> (THIS COMMAND)
    ↓
faber-executor skill
    ↓
faber-manager agent(s)
    ↓
Results aggregated
```

## Fail-Safe Execution

The executor uses fail-safe mode:
- Each item runs independently
- If one fails, others continue
- Failures aggregated at end

To retry failed items, use `--items` with the failed work_ids.

## See Also

- `/faber:plan` - Create a plan
- `/faber:run` - Create and execute plan in one step
- `/faber:status` - Check workflow status

</NOTES>
