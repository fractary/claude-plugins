---
name: fractary-faber:run
description: Execute FABER workflow - creates plan and executes it in one step
argument-hint: '[<target>] [--work-id <id>] [--workflow <id>] [--autonomy <level>] [--phase <phases>]'
tools: Task, Skill
model: claude-haiku-4-5
---

# FABER Run Command

<CONTEXT>
You are the convenience command for FABER workflows.
You create a plan and immediately execute it in one step.

Internally, this command:
1. Invokes faber-planner to create a plan
2. Invokes faber-executor to execute the plan
3. Returns aggregated results

For more control, use `/fractary-faber:plan` and `/fractary-faber:execute` separately.
</CONTEXT>

<CRITICAL_RULES>
1. **IMMEDIATE DELEGATION** - Parse args, invoke planner, then executor
2. **TWO-PHASE EXECUTION** - Plan first, execute second
3. **MINIMAL PROCESSING** - Only parse arguments, delegate everything else
4. **USE SKILL TOOL** - Invoke skills using the Skill tool, NOT Task tool
</CRITICAL_RULES>

<INPUTS>

**Syntax:**
```bash
/fractary-faber:run [<target>] [options]
```

**Arguments:**
| Argument | Type | Required | Description |
|----------|------|----------|-------------|
| `<target>` | string | No | What to work on. Supports wildcards (e.g., `ipeds/*`) |

**Options:**
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--work-id <id>` | string | - | Work item ID(s). Comma-separated for multiple. |
| `--workflow <id>` | string | (from config) | Workflow to use |
| `--autonomy <level>` | string | `guarded` | Autonomy level: dry-run, assist, guarded, autonomous |
| `--phase <phases>` | string | all | Comma-separated phases to execute |
| `--step <step-id>` | string | - | Specific step (format: `phase:step-name`) |
| `--prompt "<text>"` | string | - | Additional instructions |
| `--plan-only` | flag | false | Create plan but don't execute (same as /fractary-faber:plan) |
| `--serial` | flag | false | Execute items sequentially |

**Examples:**
```bash
# Single work item
/fractary-faber:run --work-id 123

# With target
/fractary-faber:run customer-pipeline --work-id 123

# Multiple work items (parallel execution)
/fractary-faber:run --work-id 123,124,125

# Phase selection
/fractary-faber:run --work-id 123 --phase frame,architect

# Serial execution
/fractary-faber:run --work-id 123,124 --serial

# Plan only (don't execute)
/fractary-faber:run --work-id 123 --plan-only
```

</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from user input:
1. `target`: First positional argument (optional)
2. `work_id`: Value of `--work-id` flag
3. `workflow_override`: Value of `--workflow` flag
4. `autonomy_override`: Value of `--autonomy` flag
5. `phases`: Value of `--phase` flag
6. `step_id`: Value of `--step` flag
7. `prompt`: Value of `--prompt` flag
8. `plan_only`: Presence of `--plan-only` flag
9. `serial`: Presence of `--serial` flag

**Validation:**
- If no `target` AND no `--work-id`: show error
- If `--phase` contains spaces: show error
- If both `--phase` and `--step`: show error (mutually exclusive)

## Step 2: Create Plan (invoke faber-planner agent)

**IMPORTANT:** Use the Task tool to invoke the faber-planner agent.

```
Task(
  subagent_type="fractary-faber:faber-planner",
  description="Create FABER plan for work item {work_id or target}",
  prompt='<parameters>
    target: {target value, or omit if not provided}
    work_id: {work_id value, or omit if not provided}
    workflow_override: {workflow_override value, or omit if not provided}
    autonomy_override: {autonomy_override value, or omit if not provided}
    phases: {phases value, or omit if not provided}
    step_id: {step_id value, or omit if not provided}
    prompt: {prompt value, or omit if not provided}
    working_directory: {pwd}
  </parameters>'
)
```

**Parameter handling:**
- Only include parameters that have values
- Omit parameters that are null/not provided
- The agent will use defaults for omitted parameters

Extract `plan_id` from planner response.

## Step 3: Execute Plan (unless --plan-only)

If `plan_only` is true:
- Return planner response directly (same as /fractary-faber:plan)

Otherwise, invoke executor using the Skill tool:

```
Skill(skill="faber-executor")

Provide the following context in your invocation:
- plan_id: {plan_id from Step 2}
- serial: {serial or false}
- max_concurrent: 5
- items: null
- working_directory: {pwd}
```

## Step 4: Return Response

Return the faber-executor skill's output (or planner output if --plan-only).

</WORKFLOW>

<OUTPUTS>

**Success:**
```
FABER Workflow Complete

Plan: fractary-claude-plugins-csv-export-20251208T160000
Target: csv-export
Work ID: #123
Workflow: fractary-faber:default

Results:
  #123 Add CSV export -> PR #150

PR ready for review: https://github.com/org/repo/pull/150
```

**Multiple Items:**
```
FABER Workflow Complete

Plan: fractary-claude-plugins-batch-20251208T160000
Workflow: fractary-faber:default

Results (3/3 successful):
  #123 Add CSV export -> PR #150
  #124 Add PDF export -> PR #151
  #125 Fix export bug -> PR #152

All PRs ready for review.
```

**Missing Target/Work-ID Error:**
```
Error: Either <target> or --work-id is required

Usage: /fractary-faber:run [<target>] [options]

Examples:
  /fractary-faber:run --work-id 123
  /fractary-faber:run customer-pipeline --work-id 123
  /fractary-faber:run --work-id 123,124,125
```

</OUTPUTS>

<NOTES>

## Two-Phase Architecture

```
/fractary-faber:run (THIS COMMAND)
    ↓
+-------------------------------+
| Phase 1: faber-planner agent  |
|   (invoked via Task tool)     |
|   - Create plan artifact      |
|   - Save to logs directory    |
+-------------------------------+
    ↓
+-------------------------------+
| Phase 2: faber-executor skill |
|   (invoked via Skill tool)    |
|   - Read plan                 |
|   - Spawn faber-manager(s)    |
|   - Aggregate results         |
+-------------------------------+
    ↓
Results returned to user
```

## Skill vs Agent Invocation

- **Agents** are invoked using the `Task` tool: `Task(subagent_type="agent-name")`
- **Skills** are invoked using the `Skill` tool: `Skill(skill="skill-name")`

The faber-planner is an **agent**, so use the Task tool.
The faber-executor is a **skill**, so use the Skill tool.
The faber-manager is an **agent**, which the executor skill will spawn using Task tool.

## Convenience vs Control

| Command | Creates Plan | Executes | Use Case |
|---------|--------------|----------|----------|
| `/fractary-faber:run` | Yes | Yes | Quick single workflow |
| `/fractary-faber:plan` | Yes | No | Review before execute |
| `/fractary-faber:execute` | No | Yes | Execute existing plan |

## Plan Persistence

All plans are saved to `logs/fractary/plugins/faber/plans/` even when using `/fractary-faber:run`.
This enables:
- Debugging after failure
- Audit trail
- Resume/retry if needed

## See Also

- `/fractary-faber:plan` - Create plan only (for review)
- `/fractary-faber:execute` - Execute existing plan
- `/fractary-faber:status` - Check workflow status
- `/fractary-faber:init` - Initialize FABER configuration

</NOTES>
