---
name: fractary-faber:plan
description: Create a FABER execution plan without executing it
argument-hint: '[<target>] [--work-id <id>] [--workflow <id>] [--autonomy <level>] [--phase <phases>]'
tools: Skill
model: claude-haiku-4-5
---

# FABER Plan Command

<CONTEXT>
You are the entry point for creating FABER execution plans.
Your job is to parse arguments and invoke the faber-planner skill.

This command creates a plan but does NOT execute it. To execute, use `/faber:execute`.
</CONTEXT>

<CRITICAL_RULES>
1. **IMMEDIATE DELEGATION** - Parse args, invoke faber-planner skill, return result
2. **NO EXECUTION** - This command does NOT invoke faber-manager
3. **MINIMAL PROCESSING** - Only parse arguments, nothing more
4. **USE SKILL TOOL** - Invoke faber-planner using the Skill tool
</CRITICAL_RULES>

<INPUTS>

**Syntax:**
```bash
/faber:plan [<target>] [options]
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
/faber:plan customer-pipeline --work-id 123

# Wildcard expansion
/faber:plan "ipeds/*"

# Multiple issues
/faber:plan --work-id 101,102,103

# Phase selection
/faber:plan --work-id 123 --phase frame,architect
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

## Step 2: Invoke faber-planner Skill

**IMPORTANT:** Use the Skill tool to invoke the faber-planner skill.

```
Skill(skill="faber-planner")

Provide the following context in your invocation:
- target: {target or null}
- work_id: {work_id or null}
- workflow_override: {workflow_override or null}
- autonomy_override: {autonomy_override or null}
- phases: {phases or null}
- step_id: {step_id or null}
- prompt: {prompt or null}
- working_directory: {pwd}
```

The skill name is `faber-planner` (short form, without namespace prefix).

## Step 3: Return Response

Return the faber-planner skill's output directly.

</WORKFLOW>

<OUTPUTS>

**Success:**
The faber-planner skill's output showing plan ID and summary.

**Missing Target/Work-ID Error:**
```
Error: Either <target> or --work-id is required

Usage: /faber:plan [<target>] [options]

Examples:
  /faber:plan customer-pipeline
  /faber:plan --work-id 158
  /faber:plan "ipeds/*"
```

</OUTPUTS>

<NOTES>

## Two-Phase Architecture

```
/faber:plan (THIS COMMAND)
    |
faber-planner skill (invoked via Skill tool)
    |
Plan artifact saved to logs/fractary/plugins/faber/plans/
    |
User reviews plan
    |
/faber:execute <plan-id>
    |
faber-executor skill
    |
faber-manager agent(s)
```

## Skill vs Agent Invocation

- **Skills** are invoked using the `Skill` tool: `Skill(skill="skill-name")`
- **Agents** are invoked using the `Task` tool: `Task(subagent_type="agent-name")`

The faber-planner is a **skill**, so use the Skill tool.

## See Also

- `/faber:execute` - Execute a plan
- `/faber:run` - Create and execute plan in one step
- `/faber:status` - Check workflow status

</NOTES>
