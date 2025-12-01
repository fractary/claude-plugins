---
name: fractary-faber:direct
description: Execute FABER workflow via natural language or work item ID
argument-hint: <work_id | "natural language request"> [--workflow <id>] [--autonomy <level>]
tools: Skill
model: inherit
---

# FABER Direct Command

<CONTEXT>
You are the **lightweight entry point** for FABER workflows. Your ONLY job is to capture user input and immediately invoke the `faber-director` skill.

This command follows the principle: **commands never do work** - they immediately delegate to skills/agents.
</CONTEXT>

<CRITICAL_RULES>
**NEVER VIOLATE THESE RULES:**

1. **Immediate Delegation**
   - IMMEDIATELY invoke faber-director skill after parsing arguments
   - DO NOT load configuration - director does this
   - DO NOT fetch issues - director does this
   - DO NOT detect workflows from labels - director does this
   - DO NOT validate work IDs exist - director does this

2. **Minimal Processing**
   - ONLY parse raw arguments
   - ONLY extract optional flags (--workflow, --autonomy)
   - ONLY capture working directory
   - Pass everything else to director skill unchanged

3. **Single Responsibility**
   - This command has ONE job: invoke faber-director skill
   - All intelligence is in the director skill
   - All workflow execution is in the manager agent/skill
</CRITICAL_RULES>

<INPUTS>
**Command Syntax:**
```bash
/faber:direct <work_id | "natural language"> [--workflow <id>] [--autonomy <level>]
```

**Required Argument:**
- First positional argument: Work item ID (e.g., `123`) OR natural language request (e.g., `"implement issues 100 and 101"`)

**Optional Flags:**
- `--workflow <id>`: Override workflow selection (e.g., `default`, `hotfix`)
- `--autonomy <level>`: Override autonomy level (`dry-run`, `assist`, `guarded`, `autonomous`)

**Examples:**
```bash
# Single work item
/faber:direct 123

# Natural language
/faber:direct "implement issue 123"

# Multiple items
/faber:direct 100,101,102

# With workflow override
/faber:direct 123 --workflow hotfix

# With autonomy override
/faber:direct 123 --autonomy autonomous

# Combined
/faber:direct 123 --workflow default --autonomy guarded
```
</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from user input:
1. **raw_input**: The first positional argument (work_id or natural language)
2. **workflow_override**: Value of `--workflow` flag (if provided)
3. **autonomy_override**: Value of `--autonomy` flag (if provided)

**Parsing Rules:**
- First non-flag argument is `raw_input`
- `--workflow <value>` extracts workflow_override
- `--autonomy <value>` extracts autonomy_override
- If no arguments provided, error with usage

**Error if no input:**
```
Error: work_id or request is required

Usage: /faber:direct <work_id | "request"> [options]

Examples:
  /faber:direct 123
  /faber:direct "implement issue 123"
  /faber:direct 100,101,102
  /faber:direct 123 --workflow hotfix
```

## Step 2: Invoke faber-director Skill

**IMMEDIATELY** invoke the faber-director skill using the Skill tool:

```
Skill(skill="fractary-faber:faber-director")
```

**Pass context in your message:**
```
I am invoking you to execute a FABER workflow with the following parameters:

Raw Input: {raw_input}
Workflow Override: {workflow_override or "not specified"}
Autonomy Override: {autonomy_override or "not specified"}
Working Directory: {pwd}

Please:
1. Load configuration from .fractary/plugins/faber/config.json
2. Parse the raw input to identify work item(s)
3. Fetch issue(s) for context and workflow detection
4. Determine workflow (from labels or override or default)
5. Spawn faber-manager agent(s) to execute the workflow
```

## Step 3: Return Response

Return whatever the faber-director skill returns. Do not process or modify its output.

</WORKFLOW>

<COMPLETION_CRITERIA>
This command is complete when:
1. Arguments parsed (or error shown for missing input)
2. faber-director skill invoked with context
3. Skill response returned to user
</COMPLETION_CRITERIA>

<OUTPUTS>
**Success:**
The faber-director skill's output is displayed directly to the user.

**Argument Error:**
```
Error: work_id or request is required

Usage: /faber:direct <work_id | "request"> [options]

Examples:
  /faber:direct 123
  /faber:direct "implement issue 123"
  /faber:direct 100,101,102
```

**Invalid Flag Error:**
```
Error: Invalid autonomy level: 'invalid'

Valid levels: dry-run, assist, guarded, autonomous
```
</OUTPUTS>

<ERROR_HANDLING>

## Missing Arguments
If no work_id or request provided:
- Show usage error
- List examples
- Do NOT invoke director skill

## Invalid Autonomy Level
If `--autonomy` value is not valid:
- Show error with valid options
- Do NOT invoke director skill

## All Other Errors
All other errors (config not found, issue not found, workflow failed, etc.) are handled by the faber-director skill. This command does NOT handle them.

</ERROR_HANDLING>

<NOTES>

## Why This Command is Lightweight

The previous `/faber:manage` command was complex:
- Loaded configuration
- Fetched issues for workflow detection
- Validated workflows
- Had 5+ steps before invoking director

This led to the command stopping partway through (Issue #187).

This command has ONE responsibility: invoke the director skill. All intelligence lives in the skill layer.

## Architecture

```
/faber:direct (THIS COMMAND - ~50 lines of logic)
    ↓ immediately invokes
faber-director skill (intelligence layer)
    ↓ spawns 1 or N
faber-manager agent (execution layer)
```

## Replaces

This command replaces:
- `/faber:manage` (deleted)
- `/faber:run` (deleted)

## See Also

- `faber-director` skill: The intelligence layer that parses input, detects workflows, handles parallelization
- `faber-manager` agent: Executes single workflow (all 5 phases)
- `/faber:status`: Query workflow state (future)

</NOTES>
