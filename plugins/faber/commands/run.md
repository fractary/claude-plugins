---
name: fractary-faber:run
description: Execute FABER workflow with target-first design, flexible phase control, resume/rerun capability, and label-based configuration
argument-hint: '[<target>] [--work-id <id>] [--resume <run-id>] [--rerun <run-id>] [--phase <phases>] [--step <step-id>] [--workflow <id>] [--autonomy <level>] [--prompt "<text>"]'
tools: Skill
model: claude-haiku-4-5
---

# FABER Run Command

<CONTEXT>
You are the **primary entry point** for FABER workflows. Your job is to parse user input and immediately invoke the `faber-director` skill with structured parameters.

This is the consolidated command that replaces:
- `/fractary-faber:direct` (deprecated)
- `/fractary-faber:faber` (removed)
- Phase-specific commands: `/fractary-faber:frame`, `/fractary-faber:architect`, etc. (deprecated)

This command follows the principle: **commands never do work** - they immediately delegate to skills/agents.
</CONTEXT>

<CRITICAL_RULES>
**NEVER VIOLATE THESE RULES:**

1. **Immediate Delegation**
   - IMMEDIATELY invoke faber-director skill after parsing arguments
   - DO NOT load configuration - director does this
   - DO NOT fetch issues - director does this
   - DO NOT detect workflows from labels - director does this
   - DO NOT validate work IDs or targets exist - director does this

2. **Target-First Design**
   - Target is the primary argument (what to work on)
   - Work-id is optional (provides issue context)
   - Target can be: artifact name, natural language, or omitted (when --work-id provided)

3. **Minimal Processing**
   - ONLY parse raw arguments
   - ONLY extract optional flags
   - ONLY capture working directory
   - Pass everything else to director skill unchanged

4. **Single Responsibility**
   - This command has ONE job: invoke faber-director skill
   - All intelligence is in the director skill
   - All workflow execution is in the manager agent
</CRITICAL_RULES>

<INPUTS>
**Command Syntax:**
```bash
/fractary-faber:run [<target>] [options]
```

**Arguments:**

| Argument | Type | Required | Description |
|----------|------|----------|-------------|
| `<target>` | string | No | What to work on: artifact name, blog post, dataset, module, or freeform natural language. If omitted, requires `--work-id` and target is inferred from issue. |

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--work-id <id>` | string | - | Work item ID (GitHub issue, Jira ticket, Linear issue). Fetches issue details and checks labels for configuration. |
| `--resume <run-id>` | string | - | Resume a previous run from where it failed/paused. Format: `org/project/uuid`. |
| `--rerun <run-id>` | string | - | Re-run a previous run with a new run_id (for different parameters). Inherits metadata from original. |
| `--workflow <id>` | string | `default` | Workflow to use (e.g., `default`, `hotfix`). Can be detected from issue labels. |
| `--autonomy <level>` | string | `guarded` | Autonomy level: `dry-run`, `assist`, `guarded`, `autonomous`. Can be detected from issue labels. |
| `--phase <phases>` | string | all | Comma-separated phases to execute (e.g., `frame,architect`). **No spaces**. |
| `--step <step-id>` | string | - | Specific step to execute. Format: `phase:step-name` (e.g., `build:implement`). Mutually exclusive with `--phase`. |
| `--prompt "<text>"` | string | - | Additional custom instructions to guide the workflow. |

**Examples:**
```bash
# Artifact-first approach (primary use case)
/fractary-faber:run customer-analytics-v2 --work-id 158

# Target with workflow override
/fractary-faber:run "2024-12-product-launch" --workflow content

# Natural language request
/fractary-faber:run "implement the authentication feature from issue 158"

# Work-id only (target inferred from issue)
/fractary-faber:run --work-id 158

# Phase selection
/fractary-faber:run target --work-id 158 --phase frame,architect

# Single step execution
/fractary-faber:run target --work-id 158 --step build:implement

# With custom instructions
/fractary-faber:run api-refactor --work-id 300 --prompt "This is a breaking change. Update dependent services."

# Dry run
/fractary-faber:run target --work-id 158 --autonomy dry-run

# Resume a failed/paused run
/fractary-faber:run --resume fractary/my-project/a1b2c3d4-e5f6-7890-abcd-ef1234567890

# Resume from a specific step
/fractary-faber:run --resume fractary/my-project/a1b2c3d4-... --step build:implement

# Re-run with different autonomy
/fractary-faber:run --rerun fractary/my-project/a1b2c3d4-... --autonomy autonomous

# Full combination
/fractary-faber:run dashboard --work-id 200 --phase build,evaluate --autonomy guarded --prompt "Focus on accessibility"
```
</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from user input:

1. **target**: First positional argument (optional)
   - If starts with `--`: not a target, it's a flag
   - If contains natural language: use as-is
   - If omitted: will be inferred from issue

2. **work_id**: Value of `--work-id` flag (optional)
3. **resume**: Value of `--resume` flag (optional, format: `org/project/uuid`)
4. **rerun**: Value of `--rerun` flag (optional, format: `org/project/uuid`)
5. **workflow_override**: Value of `--workflow` flag (optional)
6. **autonomy_override**: Value of `--autonomy` flag (optional)
7. **phases**: Value of `--phase` flag (optional, comma-separated, no spaces)
8. **step_id**: Value of `--step` flag (optional, format: `phase:step-name`)
9. **prompt**: Value of `--prompt` flag (optional, may be quoted)

**Parsing Rules:**
- First non-flag argument is `target`
- `--work-id <value>` extracts work_id
- `--resume <value>` extracts resume run_id
- `--rerun <value>` extracts rerun run_id
- `--workflow <value>` extracts workflow_override
- `--autonomy <value>` extracts autonomy_override
- `--phase <value>` extracts phases (comma-separated, NO SPACES)
- `--step <value>` extracts step_id
- `--prompt "<value>"` extracts prompt (handle quotes)

**Validation:**
- If no `target` AND no `--work-id` AND no `--resume` AND no `--rerun`: show error
- If both `--resume` AND `--rerun` provided: show error (mutually exclusive)
- If `--resume` or `--rerun` AND `--work-id`: `--work-id` is ignored (run already has work_id)
- If `--phase` contains spaces: show error
- If `--step` doesn't match pattern `phase:step-name`: show error
- If `--autonomy` is invalid level: show error
- If both `--phase` and `--step` provided: show error (mutually exclusive)
- If `--resume` or `--rerun` doesn't match format `org/project/uuid`: show error

**Error if no target, work-id, resume, or rerun:**
```
Error: Either <target>, --work-id, --resume, or --rerun is required

Usage: /fractary-faber:run [<target>] [options]

Examples:
  /fractary-faber:run customer-pipeline
  /fractary-faber:run --work-id 158
  /fractary-faber:run --resume fractary/project/uuid
  /fractary-faber:run --rerun fractary/project/uuid --autonomy autonomous
```

## Step 2: Invoke faber-director Skill

**IMMEDIATELY** invoke the faber-director skill using the Skill tool:

```
Skill(skill="fractary-faber:faber-director")
```

**Pass context in your message:**
```
I am invoking you to execute a FABER workflow with the following parameters:

Target: {target or "not specified - infer from issue"}
Work ID: {work_id or "not specified"}
Resume Run ID: {resume or "not specified - new run"}
Rerun Run ID: {rerun or "not specified - new run"}
Workflow Override: {workflow_override or "not specified"}
Autonomy Override: {autonomy_override or "not specified"}
Phases: {phases or "all phases"}
Step ID: {step_id or "not specified - full phases"}
Prompt: {prompt or "no additional instructions"}
Working Directory: {pwd}

Please:
1. Load configuration from .fractary/plugins/faber/config.json
2. If resume provided:
   - Load run state and metadata from run directory
   - Determine next step to execute
   - Skip generating new run_id
3. Else if rerun provided:
   - Load original run metadata
   - Generate new run_id with rerun_of relationship
   - Apply any parameter overrides
4. Else (new run):
   - If work_id provided: fetch issue, check labels for configuration
   - Generate new run_id
   - Initialize run directory
5. Parse target (artifact name, natural language, or infer from issue)
6. Detect workflow from labels or override or default
7. Apply label-detected values (workflow, autonomy, phases) with CLI overrides taking precedence
8. Validate phases (check prerequisites if needed)
9. Spawn faber-manager agent(s) to execute the workflow with:
   - run_id
   - is_resume (true if resume, false otherwise)
   - resume_context (if resume)
   - phases list (if specified)
   - step_id (if specified)
   - additional_instructions (prompt)
```

## Step 3: Return Response

Return whatever the faber-director skill returns. Do not process or modify its output.

</WORKFLOW>

<COMPLETION_CRITERIA>
This command is complete when:
1. Arguments parsed (or error shown for missing/invalid input)
2. faber-director skill invoked with context
3. Skill response returned to user
</COMPLETION_CRITERIA>

<OUTPUTS>
**Success:**
The faber-director skill's output is displayed directly to the user.

**Missing Target/Work-ID Error:**
```
Error: Either <target> or --work-id is required

Usage: /fractary-faber:run [<target>] [options]

Examples:
  /fractary-faber:run customer-pipeline
  /fractary-faber:run --work-id 158
  /fractary-faber:run "implement feature from issue 158"
```

**Invalid Phase Format Error:**
```
Error: --phase must be comma-separated with no spaces

Correct: --phase frame,architect,build
Wrong:   --phase frame, architect, build
```

**Invalid Step Format Error:**
```
Error: --step must be in format 'phase:step-name'

Examples:
  --step build:implement
  --step evaluate:test
  --step release:create-pr
```

**Invalid Autonomy Level Error:**
```
Error: Invalid autonomy level: 'invalid'

Valid levels: dry-run, assist, guarded, autonomous
```

**Mutual Exclusivity Error (phase/step):**
```
Error: --phase and --step are mutually exclusive

Use --phase for complete phases: --phase build,evaluate
Use --step for single step: --step build:implement
```

**Mutual Exclusivity Error (resume/rerun):**
```
Error: --resume and --rerun are mutually exclusive

Use --resume to continue an existing run from where it stopped
Use --rerun to start a new run based on a previous one (with changes)
```

**Invalid Run ID Format Error:**
```
Error: Invalid run ID format: 'invalid'

Run ID must be in format: org/project/uuid
Example: fractary/my-project/a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

**Run Not Found Error:**
```
Error: Run not found: 'fractary/project/uuid'

The run directory does not exist. Check the run ID or use /fractary-faber:status to list available runs.
```
</OUTPUTS>

<ERROR_HANDLING>

## Missing Arguments
If no target, work_id, resume, or rerun provided:
- Show usage error with examples
- Do NOT invoke director skill

## Invalid Phase Format
If `--phase` contains spaces:
- Show error explaining comma-separated format
- Do NOT invoke director skill

## Invalid Step Format
If `--step` doesn't match `phase:step-name`:
- Show error with valid format examples
- Do NOT invoke director skill

## Invalid Autonomy Level
If `--autonomy` value is not valid:
- Show error with valid options
- Do NOT invoke director skill

## Mutual Exclusivity (phase/step)
If both `--phase` and `--step` provided:
- Show error explaining they are mutually exclusive
- Do NOT invoke director skill

## Mutual Exclusivity (resume/rerun)
If both `--resume` and `--rerun` provided:
- Show error explaining they are mutually exclusive
- Do NOT invoke director skill

## Invalid Run ID Format
If `--resume` or `--rerun` value doesn't match `org/project/uuid` format:
- Show error with valid format example
- Do NOT invoke director skill

## All Other Errors
All other errors (config not found, issue not found, run not found, workflow failed, label parsing, etc.) are handled by the faber-director skill. This command does NOT handle them.

</ERROR_HANDLING>

<NOTES>

## Architecture

```
/fractary-faber:run (THIS COMMAND - lightweight parser)
    |
    v
faber-director skill (intelligence layer)
    - Loads config
    - Fetches issue (if work_id)
    - Detects labels for configuration
    - Validates phases
    - Parses natural language target
    |
    v
faber-manager agent (execution layer)
    - Executes workflow phases
    - Manages state
    - Handles retries
```

## Replaces (Deprecated Commands)

| Deprecated | Replacement |
|------------|-------------|
| `/fractary-faber:direct 158` | `/fractary-faber:run --work-id 158` |
| `/fractary-faber:faber run 158` | `/fractary-faber:run --work-id 158` |
| `/fractary-faber:frame 158` | `/fractary-faber:run --work-id 158 --phase frame` |
| `/fractary-faber:architect 158` | `/fractary-faber:run --work-id 158 --phase frame,architect` |
| `/fractary-faber:build 158` | `/fractary-faber:run --work-id 158 --phase build` |
| `/fractary-faber:evaluate 158` | `/fractary-faber:run --work-id 158 --phase evaluate` |
| `/fractary-faber:release 158` | `/fractary-faber:run --work-id 158 --phase release` |

## Label-Based Configuration

When `--work-id` is provided, the director skill checks issue labels for configuration:

| Label | Maps To |
|-------|---------|
| `faber:workflow=hotfix` | `--workflow hotfix` |
| `faber:autonomy=autonomous` | `--autonomy autonomous` |
| `faber:phase=frame,architect` | `--phase frame,architect` |
| `faber:step=build:implement` | `--step build:implement` |
| `faber:target=customer-pipeline` | `<target>` |

**Priority:** CLI args > Issue labels > Config defaults

## Step ID Format

Steps use the format `phase:step-name`:

- `frame:fetch-work`
- `frame:classify`
- `architect:generate-spec`
- `build:implement`
- `build:commit`
- `evaluate:test`
- `evaluate:review`
- `release:update-project-docs`
- `release:create-pr`

## See Also

- `faber-director` skill: Intelligence layer
- `faber-manager` agent: Execution layer
- `/fractary-faber:status`: Query workflow state
- `/fractary-faber:init`: Initialize FABER config
- Specification: `/specs/SPEC-00107-faber-run-command-consolidation.md`

</NOTES>
