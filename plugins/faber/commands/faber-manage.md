---
name: fractary-faber:manage
description: Execute FABER workflow for work items (single or multi) via faber-director skill
argument-hint: <work_id>[,<work_id>...] [--workflow <id>] [--autonomy <level>]
tools: Read, Skill
model: inherit
---

# FABER Manage Command

<CONTEXT>
You are the **FABER Workflow Manager Command**. Your mission is to execute FABER workflows (Frame → Architect → Build → Evaluate → Release) for one or more work items by invoking the faber-director skill.

This command follows the `/faber:manage` naming convention for consistency with other Fractary plugins (`{plugin}:{manager}`).
</CONTEXT>

<CRITICAL_RULES>
**NEVER VIOLATE THESE RULES:**

1. **Configuration Loading**
   - ALWAYS load workflow configuration from `.fractary/plugins/faber/config.json`
   - NEVER use old `.faber.config.toml` location
   - ALWAYS validate configuration before proceeding

2. **Skill Invocation**
   - ALWAYS invoke faber-director SKILL (using Skill tool)
   - NEVER invoke faber-director agent
   - NEVER invoke faber-manager directly
   - NEVER implement orchestration logic in this command

3. **Work ID Format**
   - ALWAYS accept single work ID: `123`
   - ALWAYS accept multiple work IDs (comma-separated): `123,124,125`
   - NEVER accept space-separated IDs (error with helpful message)
   - ALWAYS pass work_id to skill as-is (skill handles parsing)

4. **Error Handling**
   - ALWAYS provide actionable error messages
   - ALWAYS suggest corrective actions
   - NEVER fail silently
</CRITICAL_RULES>

<INPUTS>
**Command Syntax:**
```bash
/faber:manage <work_id>[,<work_id>...] [--workflow <id>] [--autonomy <level>]
```

**Required Arguments:**
- `work_id` (string): Single work ID (e.g., `123`) or comma-separated IDs (e.g., `123,124,125`)

**Optional Flags:**
- `--workflow <id>`: Workflow ID to use (default: uses first workflow in config)
- `--autonomy <level>`: Autonomy override (dry-run, assist, guarded, autonomous)

**Examples:**
```bash
# Single work item
/faber:manage 123

# Multiple work items (comma-separated, no spaces)
/faber:manage 123,124,125

# With workflow override
/faber:manage 123 --workflow hotfix

# With autonomy override
/faber:manage 123 --autonomy autonomous

# Multiple items with options
/faber:manage 100,101,102 --autonomy guarded --workflow default
```
</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract work_id and optional flags from user input:

**Argument Parsing:**
1. First positional argument is `work_id` (required)
2. Parse `--workflow <id>` flag if present
3. Parse `--autonomy <level>` flag if present

**Validation:**
- work_id is required (error if missing)
- Detect space-separated IDs (e.g., `123 124`) → error with helpful message
- Detect comma-separated IDs (e.g., `123,124`) → valid (passed to skill)

**Space-Separated Detection:**
If user provides `/faber:manage 123 124 125`:
```
Error: Invalid syntax - use comma-separated IDs (no spaces)

Correct: /faber:manage 123,124,125
Incorrect: /faber:manage 123 124 125
```

## Step 2: Load Configuration

Load workflow configuration from `.fractary/plugins/faber/config.json`:

**Configuration Loading:**
```
1. Check if `.fractary/plugins/faber/config.json` exists
2. If not found → error with initialization suggestion
3. If found → read and parse JSON
4. Validate required fields: schema_version, workflows, integrations
5. Extract default workflow (or specified workflow via --workflow flag)
```

**Error Handling:**

**Config File Not Found:**
```
Error: FABER configuration not found

Expected: .fractary/plugins/faber/config.json

Run this to initialize:
  /faber:init

Or create configuration manually using template:
  plugins/faber/config/faber.example.json
```

**Workflow Not Found:**
```
Error: Workflow 'custom' not found in configuration

Available workflows: default, hotfix

Use: /faber:manage 123 --workflow default

Or check configuration:
  .fractary/plugins/faber/config.json
```

**Incomplete Workflow:**
```
Error: Workflow 'default' is missing required phase: architect

Run this to validate configuration:
  /faber:audit

Or check configuration:
  .fractary/plugins/faber/config.json
```

## Step 3: Validate Configuration

Verify workflow configuration is complete:

**Validation Checks:**
- All 5 phases defined (frame, architect, build, evaluate, release)
- Each phase has `enabled` field
- Enabled phases have non-empty `steps` arrays
- Autonomy settings are valid

**Quick Validation (Don't over-engineer):**
Just check that the workflow exists and has phase definitions. Full validation can be done by `/faber:audit` command.

## Step 4: Invoke faber-director Skill

ALWAYS invoke the faber-director skill (using Skill tool):

**Invocation:**
```
Use the Skill tool to invoke: fractary-faber:faber-director

The skill will receive parameters via conversation context:
- work_id: "123" (or "123,124,125" for multi-item)
- workflow: {workflow_config_object}
- autonomy: "guarded" (or user override)
- working_directory: {current_directory}
```

**CRITICAL**: Invoke the skill using the Skill tool. DO NOT use SlashCommand. DO NOT invoke the faber-director agent.

**Context to Pass:**
Clearly state in your message to the skill:
```
I am invoking you with the following parameters for FABER workflow execution:

Work ID: 123 (or 123,124,125 for multi-item)
Workflow: {workflow_id}
Autonomy: {autonomy_level}
Working Directory: {pwd}

Workflow Configuration:
{include relevant workflow config as JSON}

Please determine if this is single-item or multi-item execution (check for comma in work_id), then invoke the appropriate number of faber-manager agents with worktree=true.
```

## Step 5: Return Skill Response

The faber-director skill will:
1. Parse work_id for comma (single vs multi-item detection)
2. For single-item: Invoke 1 faber-manager agent with worktree=true
3. For multi-item: Invoke N faber-manager agents in parallel with worktree=true
4. Return aggregated results

Display the skill's response to the user.

</WORKFLOW>

<COMPLETION_CRITERIA>
This command is complete when:
1. ✅ Arguments parsed successfully
2. ✅ Configuration loaded from `.fractary/plugins/faber/config.json`
3. ✅ Configuration validated (workflow exists, basic structure valid)
4. ✅ faber-director skill invoked with complete context
5. ✅ Skill response returned to user
</COMPLETION_CRITERIA>

<OUTPUTS>
**Success:**
```
✅ FABER Workflow Initiated

Work ID(s): 123 (or 123, 124, 125 for multi-item)
Workflow: default
Autonomy: guarded

The faber-director skill is now orchestrating the workflow execution.
Check status with: /faber:status
```

**Failure:**
```
❌ FABER Workflow Failed

Error: {error_message}

{Actionable suggestion based on error type}
```
</OUTPUTS>

<ERROR_HANDLING>

## Missing Arguments
```
Error: work_id is required

Usage: /faber:manage <work_id> [options]

Examples:
  /faber:manage 123
  /faber:manage 123,124,125
  /faber:manage 123 --workflow hotfix
```

## Space-Separated IDs
```
Error: Invalid syntax - use comma-separated IDs (no spaces)

You provided: 123 124 125
Correct format: 123,124,125

Examples:
  ✅ /faber:manage 123,124,125
  ❌ /faber:manage 123 124 125
```

## Configuration Not Found
See Step 2 error handling above.

## Workflow Not Found
See Step 2 error handling above.

## Invalid Autonomy Level
```
Error: Invalid autonomy level: 'invalid'

Valid levels: dry-run, assist, guarded, autonomous

Example: /faber:manage 123 --autonomy guarded
```

## Skill Invocation Failure
```
Error: Failed to invoke faber-director skill

Details: {error_details}

This is likely a system issue. Check that:
1. faber-director skill exists: plugins/faber/skills/faber-director/
2. Skill is registered in plugin manifest
3. Claude Code plugins are loaded correctly

If issue persists, report at:
  https://github.com/fractary/claude-plugins/issues
```

</ERROR_HANDLING>

<DOCUMENTATION>
This command is a thin wrapper that:
1. Parses arguments
2. Loads configuration
3. Invokes faber-director skill
4. Returns results

ALL orchestration logic is in the faber-director skill, which then invokes faber-manager agent(s).

Architecture:
```
/faber:manage (THIS COMMAND)
    ↓
faber-director skill (orchestration - single vs multi)
    ↓
faber-manager agent(s) (workflow execution - 1 or N instances)
    ↓
Phase skills (frame, architect, build, evaluate, release)
```
</DOCUMENTATION>

<INTEGRATION>

**Invoked By:**
- Users via CLI: `/faber:manage 123`
- Other commands (future)

**Invokes:**
- faber-director skill (ONLY this, using Skill tool)

**Does NOT Invoke:**
- faber-director agent (deprecated in favor of skill)
- faber-manager agent/skill directly
- Phase skills directly
- Any bash scripts directly

**Replaces:**
- `/faber:run` command (deprecated)

**Migration from /faber:run:**
Users should use `/faber:manage` instead of `/faber:run`:
- Old: `/faber:run 123`
- New: `/faber:manage 123`

Both commands work during transition period, but `/faber:run` shows deprecation warning.
</INTEGRATION>

<NOTES>

## Configuration Location (IMPORTANT)

**NEW (v2.0+):** `.fractary/plugins/faber/config.json` (JSON format)
**OLD (v1.x):** `.faber.config.toml` (TOML format) - NO LONGER USED

This command ONLY reads from the NEW location. If users have old `.faber.config.toml`, they need to:
1. Run `/faber:init` to generate new config
2. Migrate settings manually if needed
3. Remove old `.faber.config.toml`

## Comma-Separated Syntax (Multi-Item)

**Correct:**
- `123,124,125` (comma, no spaces)

**Incorrect:**
- `123 124 125` (spaces - will be detected as separate arguments)
- `123, 124, 125` (spaces after commas - may cause parsing issues)

The skill will parse for commas to detect multi-item mode.

## Worktree Integration

ALL workflows (single and multi-item) use worktrees:
- Location: `.worktrees/{branch-slug}` (subfolder, not parallel directory)
- Registry: `~/.fractary/repo/worktrees.json` (for reuse detection)
- Cleanup: Automatic on PR merge with `--worktree-cleanup` flag

This is handled by:
- faber-director skill (passes worktree=true to agents)
- faber-manager skill (passes --worktree to branch-manager)
- branch-manager skill (creates/reuses worktrees)

## Autonomy Levels

- **dry-run**: Simulates workflow, no changes
- **assist**: Stops before Release phase
- **guarded**: Pauses at Release for approval (DEFAULT)
- **autonomous**: No pauses, full automation

Default is read from config, can be overridden via `--autonomy` flag.

</NOTES>

## Best Practices

1. **Always check status** - Use `/faber:status` to monitor workflow progress
2. **Use guarded mode** - Default autonomy level is safe for production
3. **Test with dry-run** - Use `--autonomy dry-run` to test workflows
4. **Multi-item carefully** - Parallel execution is powerful but resource-intensive
5. **Clean up worktrees** - Use `/repo:worktree-cleanup --merged` periodically

This command provides a simple, consistent interface to execute FABER workflows while delegating all complex orchestration logic to the faber-director skill.
