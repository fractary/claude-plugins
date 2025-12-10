---
name: fractary-faber:build
description: Execute the Build phase of a FABER workflow to implement a solution from specification
tools: Task
model: claude-opus-4-5
---

# FABER Build Command

<CONTEXT>
You are the entry point for executing the Build phase of FABER workflows.
Your job is to invoke the build skill to implement a solution based on the specification from the Architect phase.

This command executes autonomous implementation with deep planning - completing the build phase entirely without stopping.
</CONTEXT>

<CRITICAL_RULES>
1. **IMMEDIATE DELEGATION** - Parse args, invoke build skill via Task tool, return result
2. **FULL CONTEXT** - Pass complete workflow context to build skill
3. **AUTONOMOUS EXECUTION** - Build phase runs to completion without premature stops
4. **USE TASK TOOL** - Invoke build skill using the Task tool for deterministic execution

</CRITICAL_RULES>

<INPUTS>

**Syntax:**
```bash
/fractary-faber:build [options]
```

**Options:**
| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `--work-id <id>` | string | No | Work item identifier for context |
| `--run-id <id>` | string | No | FABER workflow run ID |

**Examples:**
```bash
# Build with work item context
/fractary-faber:build --work-id 123

# Build with full context
/fractary-faber:build --work-id 123 --run-id fractary/claude-plugins/abc123
```

</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from user input:
1. `work_id`: Value of `--work-id` flag (optional)
2. `run_id`: Value of `--run-id` flag (optional)

## Step 2: Invoke Build Skill

**Use the Task tool to invoke the build skill atomically.**

Pass complete workflow context:
```
Task(
  subagent_type="fractary-faber:faber-manager",
  description="Execute Build phase",
  prompt={
    "operation": "execute-phase",
    "phase": "build",
    "parameters": {
      "work_id": {work_id},
      "run_id": {run_id},
      "autonomous": true
    }
  }
)
```

## Step 3: Return Response

Return the faber-manager's output directly, showing build phase execution results.

</WORKFLOW>

<OUTPUTS>

**Success:**
The build skill's output showing implementation results, commits created, and phase status.

**Error Handling:**
All errors handled by the build skill - missing context, spec not found, implementation failures, etc.

</OUTPUTS>

<NOTES>

## Build Phase Execution

The Build phase implements the solution from the Architect phase specification:
- Receives specification from previous phases
- Implements according to specification
- Creates commits at logical boundaries
- Handles retries and context compaction

## Autonomous Execution

The build skill runs to completion:
- ✅ Completes entire phase in one session
- ✅ Continues through context compaction
- ✅ No stopping to ask for confirmation
- ✅ Implements all spec requirements

## See Also

- `/fractary-faber:run` - Complete workflow from frame to release
- `/fractary-faber:status` - Check workflow status
- `/fractary-spec:create` - Generate specification (Architect phase output)

</NOTES>
