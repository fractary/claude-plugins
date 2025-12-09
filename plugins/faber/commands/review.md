---
name: fractary-faber:review
description: Review implementation against issue and specification to ensure completeness and quality
tools: Task
model: claude-opus-4-5
---

# FABER Review Command

<CONTEXT>
You are the entry point for reviewing implementation in FABER workflows.
Your job is to invoke the issue-reviewer skill to analyze code changes against the issue/spec and verify implementation completeness.

This command runs automatically at the START of the Evaluate phase to ensure implementation meets requirements before any other evaluation steps.
</CONTEXT>

<CRITICAL_RULES>
1. **IMMEDIATE DELEGATION** - Parse args, invoke issue-reviewer skill via Task tool, return result
2. **COMPREHENSIVE ANALYSIS** - Review against issue description, comments, and specification
3. **CLEAR STATUS CODES** - Return one of: success, warning, failure
4. **USE TASK TOOL** - Invoke via Task tool for deterministic execution

</CRITICAL_RULES>

<INPUTS>

**Syntax:**
```bash
/fractary-faber:review [options]
```

**Options:**
| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `--work-id <id>` | string | Yes | Work item identifier (issue number) |
| `--run-id <id>` | string | No | FABER workflow run ID |

**Examples:**
```bash
# Review implementation for issue #123
/fractary-faber:review --work-id 123

# Review with full workflow context
/fractary-faber:review --work-id 123 --run-id fractary/claude-plugins/abc123
```

</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from user input:
1. `work_id`: Value of `--work-id` flag (required)
2. `run_id`: Value of `--run-id` flag (optional)

## Step 2: Invoke Issue-Reviewer Skill

**Use the Task tool to invoke the issue-reviewer skill atomically.**

Pass complete review context:
```
Task(
  subagent_type="fractary-faber:faber-manager",
  description="Review implementation completeness",
  prompt={
    "operation": "execute-phase-step",
    "phase": "evaluate",
    "step": "review",
    "parameters": {
      "work_id": {work_id},
      "run_id": {run_id}
    }
  }
)
```

## Step 3: Return Response

Return the issue-reviewer skill's output directly, showing review results and status.

</WORKFLOW>

<OUTPUTS>

**Success (success status):**
- Issue/spec implemented as requested
- No issues found
- Ready to continue

**Warning (warning status):**
- Issue/spec implemented as requested
- Minor improvements identified
- Ready to continue with notes

**Failure (failure status):**
- Issue/spec NOT implemented as requested, OR
- Medium/major/critical issues found
- May require rework

Each status includes:
- Specific findings with file:line references
- Analysis of implementation completeness
- Any required fixes

</OUTPUTS>

<NOTES>

## Review Scope

The issue-reviewer skill analyzes:
1. **Against Issue Description** - Does implementation match issue requirements?
2. **Against All Comments** - Are requirements from issue comments addressed?
3. **Against Specification** - If spec exists, does implementation match spec?
4. **Code Quality** - Any obvious issues with implementation?

## Model Used

Uses claude-opus-4-5 for complex analysis of code changes against specifications.

## Graceful Degradation

If specification is missing:
- Analyzes against issue description only
- Continues with available context
- Reports if spec was expected but not found

## Non-Blocking on Errors

If context gathering fails:
- Reports the error
- Continues with available data
- Does not block the workflow

## See Also

- `/fractary-faber:run` - Complete workflow from frame to release
- `/fractary-faber:status` - Check workflow status
- `/fractary-spec:create` - Generate specification (for review comparison)

</NOTES>
