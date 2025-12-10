---
name: fractary-faber:plan
description: Create a FABER execution plan without executing it
argument-hint: '[<target>] [--work-id <id>] [--workflow <id>] [--autonomy <level>] [--phase <phases>]'
tools: Task
model: claude-haiku-4-5
---

# FABER Plan Command

<CONTEXT>
You are the entry point for creating FABER execution plans.
Your job is to parse arguments and invoke the faber-planner agent via Task tool.

This command creates a plan but does NOT execute it. To execute, use `/fractary-faber:execute`.
</CONTEXT>

<CRITICAL_RULES>
1. **IMMEDIATE DELEGATION** - Parse args, invoke faber-planner agent via Task tool, return result
2. **NO EXECUTION** - This command does NOT invoke faber-manager
3. **MINIMAL PROCESSING** - Only parse arguments, nothing more
4. **USE TASK TOOL** - Invoke faber-planner using the Task tool with subagent_type
</CRITICAL_RULES>

<INPUTS>

**Syntax:**
```bash
/fractary-faber:plan [<target>] [options]
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
| `--autonomy <level>` | string | `guarded` | Autonomy level |
| `--phase <phases>` | string | all | Comma-separated phases |
| `--step <step-id>` | string | - | Specific step (format: `phase:step-name`) |
| `--prompt "<text>"` | string | - | Additional instructions |

**Examples:**
```bash
# Single target
/fractary-faber:plan customer-pipeline --work-id 123

# Wildcard expansion
/fractary-faber:plan "ipeds/*"

# Multiple issues
/fractary-faber:plan --work-id 101,102,103

# Phase selection
/fractary-faber:plan --work-id 123 --phase frame,architect
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

**Validation:**
- If no `target` AND no `--work-id`: show error
- If `--phase` contains spaces: show error
- If both `--phase` and `--step`: show error (mutually exclusive)

## Step 2: Invoke faber-planner Agent

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

The agent type is `fractary-faber:faber-planner` (full namespace).

## Step 3: Return Response

Return the faber-planner agent's output directly.

</WORKFLOW>

<OUTPUTS>

**Success:**
The faber-planner skill's output showing plan ID and summary.

**Missing Target/Work-ID Error:**
```
Error: Either <target> or --work-id is required

Usage: /fractary-faber:plan [<target>] [options]

Examples:
  /fractary-faber:plan customer-pipeline
  /fractary-faber:plan --work-id 158
  /fractary-faber:plan "ipeds/*"
```

</OUTPUTS>

<NOTES>

## Two-Phase Architecture

```
/fractary-faber:plan (THIS COMMAND)
    ↓
faber-planner agent (invoked via Task tool)
    ↓
Plan artifact saved to logs/fractary/plugins/faber/plans/
    ↓
User reviews plan
    ↓
/fractary-faber:execute <plan-id>
    ↓
faber-executor skill
    ↓
faber-manager agent(s)
```

## Agent Invocation

The faber-planner is an **agent**, so use the Task tool:

```
Task(
  subagent_type="fractary-faber:faber-planner",
  description="...",
  prompt="..."
)
```

This ensures reliable delegation - the Task tool has clearer "hand off and wait" semantics compared to the Skill tool.

## See Also

- `/fractary-faber:execute` - Execute a plan
- `/fractary-faber:run` - Create and execute plan in one step
- `/fractary-faber:status` - Check workflow status

</NOTES>
