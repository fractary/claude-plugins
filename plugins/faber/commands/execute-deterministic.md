---
name: fractary-faber:execute-deterministic
description: Execute a FABER plan using the deterministic executor (prototype) - prevents step skipping
argument-hint: '<plan-id> [--run-id <id>] [--resume-from <n>] [--serialized-input] [--dry-run] [--verbose]'
tools: Bash
---

# FABER Deterministic Execute Command

<CONTEXT>
This command executes a FABER plan using the **deterministic executor prototype**.

Unlike the standard `/fractary-faber:execute` which uses an LLM-based orchestrator,
this command uses a bash script that owns the workflow loop, preventing the "hallucinated
completion" problem where steps are skipped.

**Key Difference:**
- Standard executor: LLM controls which step runs next (can skip)
- Deterministic executor: Bash controls which step runs next (cannot skip)
</CONTEXT>

<CRITICAL_RULES>
1. **USE BASH TOOL** - Execute the deterministic executor script directly
2. **PLAN REQUIRED** - Plan must exist in `logs/fractary/plugins/faber/plans/`
3. **PASS THROUGH** - Forward all arguments to the script unchanged
4. **NO LLM ORCHESTRATION** - The bash script handles orchestration
</CRITICAL_RULES>

<INPUTS>

**Syntax:**
```bash
/fractary-faber:execute-deterministic <plan-id> [options]
```

**Arguments:**
| Argument | Type | Required | Description |
|----------|------|----------|-------------|
| `<plan-id>` | string | Yes | Plan ID to execute |

**Options:**
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--run-id <id>` | string | auto-generated | Custom run identifier |
| `--resume-from <n>` | number | 0 | Resume from step index N (0-based) |
| `--session-id <id>` | string | - | Resume existing Claude session |
| `--serialized-input` | flag | false | Send all steps in single message (reduces API calls) |
| `--dry-run` | flag | false | Show what would be executed without running |
| `--verbose` | flag | false | Enable verbose output |

**Examples:**
```bash
# Execute plan with deterministic executor (standard mode - one message per step)
/fractary-faber:execute-deterministic fractary-claude-plugins-csv-export-20251208T160000

# Serialized input mode - send all steps in single message (fewer API calls)
/fractary-faber:execute-deterministic fractary-claude-plugins-csv-export-20251208T160000 --serialized-input

# Dry run to see what would execute
/fractary-faber:execute-deterministic fractary-claude-plugins-csv-export-20251208T160000 --dry-run

# Resume from step 5 after a failure
/fractary-faber:execute-deterministic fractary-claude-plugins-csv-export-20251208T160000 --resume-from 5

# Verbose mode for debugging
/fractary-faber:execute-deterministic fractary-claude-plugins-csv-export-20251208T160000 --verbose
```

</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from user input:
1. `plan_id`: First positional argument (required)
2. All other options: Pass through unchanged

**Validation:**
- If no `plan_id`: show error with usage

## Step 2: Locate Plan File

Plan files are stored at:
```
logs/fractary/plugins/faber/plans/{plan_id}.json
```

Verify the file exists before proceeding.

## Step 3: Generate Run ID (if not provided)

If `--run-id` is not provided, generate one:
```
{repo-slug}/{work-id}/{timestamp}
```

Example: `fractary/claude-plugins/123/20251210T160000`

## Step 4: Execute Deterministic Executor Script

Run the script with Bash tool:

```bash
plugins/faber/skills/deterministic-executor/scripts/execute-workflow.sh \
  --plan logs/fractary/plugins/faber/plans/{plan_id}.json \
  --run-id "{run_id}" \
  [other options passed through]
```

## Step 5: Return Output

Return the script's output directly. The script handles:
- Progress display
- Event emission
- State tracking
- Error reporting
- Resume instructions on failure

</WORKFLOW>

<OUTPUTS>

**Success:**
The deterministic executor script output showing workflow completion.

**Missing Plan ID Error:**
```
Error: Plan ID is required

Usage: /fractary-faber:execute-deterministic <plan-id> [options]

Examples:
  /fractary-faber:execute-deterministic fractary-project-feature-20251208T160000
  /fractary-faber:execute-deterministic my-plan-id --dry-run

List available plans:
  ls logs/fractary/plugins/faber/plans/
```

**Plan Not Found Error:**
```
Error: Plan not found: {plan_id}

Check available plans:
  ls logs/fractary/plugins/faber/plans/

Or create a new plan:
  /fractary-faber:plan --work-id 123
```

</OUTPUTS>

<NOTES>

## When to Use This Command

Use the deterministic executor when:
- You've experienced step-skipping with the standard executor
- You need guaranteed execution of every step
- You want external verification of critical steps (PR creation, merges)
- You're debugging workflow issues

## Architecture

```
/fractary-faber:execute-deterministic
    ↓
execute-workflow.sh (bash - owns the loop)
    ↓
For each step:
    1. emit_event step_start (deterministic)
    2. update_state in_progress (deterministic)
    3. claude --resume (execute step)
    4. verify_step (external evidence check)
    5. emit_event step_complete (deterministic)
    6. update_state completed (deterministic)
```

## Comparison with Standard Executor

| Feature | Standard (`/execute`) | Deterministic (standard) | Deterministic (serialized) |
|---------|----------------------|--------------------------|----------------------------|
| Orchestration | LLM-based | Bash script | Bash script |
| Step skipping | Possible | Impossible | Monitored |
| API calls | N steps | N+1 calls | 2 calls |
| External verification | No | Yes | Yes |
| State updates | LLM-emitted | Deterministic | Deterministic |
| Event emission | LLM-emitted | Deterministic | Deterministic |
| Resume support | By phase | By exact step | By exact step |

## Execution Modes

**Standard Mode (default):**
- One Claude API call per step
- Bash controls iteration, Claude executes each step
- Highest guarantee against step skipping

**Serialized Input Mode (`--serialized-input`):**
- All steps sent in a single message
- Claude receives complete step list upfront
- Fewer API calls (2 total: init + execute)
- Bash verifies results after completion
- Trade-off: relies on Claude to execute sequentially

## Prototype Status

This is a **prototype** being developed as an alternative to the LLM-based executor.
It may be promoted to the default executor after validation.

## See Also

- `/fractary-faber:execute` - Standard LLM-based executor
- `/fractary-faber:plan` - Create a plan
- `/fractary-faber:status` - Check workflow status

</NOTES>
