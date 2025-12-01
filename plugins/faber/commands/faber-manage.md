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
   - ALWAYS load workflow configuration from `.fractary/plugins/faber/config.json` **(in project working directory)**
   - **CRITICAL**: Load from project directory, NOT plugin installation directory (`~/.claude/plugins/marketplaces/...`)
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
- `--workflow <id>`: Workflow ID to use (overrides label detection; if not provided, detects from issue labels like `workflow:*`, then falls back to first workflow in config)
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

**Input Sanitization:**

1. **Empty work_id check:**
```
If work_id is empty or only whitespace:
  Error: work_id is required
  Usage: /faber:manage <work_id>
```

2. **Invalid characters check:**
```
Valid formats:
  - Numeric: 123, 456
  - Comma-separated numeric: 123,124,125
  - Alphanumeric (for Jira/Linear): PROJ-123, LIN-456
  - Comma-separated alphanumeric: PROJ-123,PROJ-124

Invalid formats (reject with error):
  - Special chars: 123!@#, 123$%
  - Negative numbers: -1, -123
  - Floats: 123.45
  - Empty entries: 123,,125 (detect and error)
  - Spaces: "123 124" (already handled above)

Pattern: ^[A-Z0-9,-]+$ (alphanumeric, comma, hyphen only)
```

3. **Comma-separated list validation:**
```
If work_id contains comma:
  - Split by comma
  - Check for empty entries (e.g., "123,,125")
  - Validate each ID individually
  - Check count doesn't exceed limit (max 20)

If empty entries detected:
  Error: Invalid work_id list contains empty entries
  You provided: 123,,125
  Correct format: 123,124,125

If too many items:
  Error: Too many work items (limit: 20)
  You provided: 25 items
  Consider processing in batches
```

4. **Reasonable limits:**
```
MAX_WORK_ITEMS = 20  # Safety limit for parallel execution

If count > MAX_WORK_ITEMS:
  Error: Too many work items (limit: 20)
  You provided: {count} items

  To process many items, use multiple commands:
    /faber:manage 1,2,3,...,20
    /faber:manage 21,22,23,...,40
```

**Space-Separated Detection:**
If user provides `/faber:manage 123 124 125`:
```
Error: Invalid syntax - use comma-separated IDs (no spaces)

Correct: /faber:manage 123,124,125
Incorrect: /faber:manage 123 124 125
```

**Invalid Character Detection:**
If user provides `/faber:manage 123!@#`:
```
Error: Invalid work_id format

work_id can only contain:
  - Letters (A-Z, a-z)
  - Numbers (0-9)
  - Hyphens (-)
  - Commas (,) for multiple items

Examples:
  ✅ 123
  ✅ PROJ-456
  ✅ 123,124,125
  ❌ 123!@#
  ❌ -1
  ❌ 123.45
```

## Step 1.5: Detect Workflow from Issue Labels

**BEFORE defaulting to first workflow, detect from issue labels:**

This step runs ONLY if `--workflow` flag was NOT provided.

### Implementation

1. **Determine work_id for label detection:**
   ```
   IF work_id contains comma (e.g., "48,50,52") THEN
     detection_work_id = first item (e.g., "48")
     Log: "Using first work item for workflow detection: #48"
   ELSE
     detection_work_id = work_id
   END
   ```

2. **Fetch issue labels using work plugin:**
   ```
   Use SlashCommand tool: /fractary-work:issue-fetch {detection_work_id}
   ```

   **Expected response format:**
   ```json
   {
     "result": {
       "id": "48",
       "title": "Add CSV export",
       "labels": ["workflow:dataset-evaluate", "priority:high", "enhancement"]
     }
   }
   ```

3. **Parse workflow from labels:**
   ```
   workflow_labels = filter labels matching pattern "workflow:*"

   IF workflow_labels is empty THEN
     detected_workflow = null
   ELSE IF workflow_labels has exactly one match THEN
     detected_workflow = extract text after "workflow:" (e.g., "dataset-evaluate")
   ELSE
     ERROR: Multiple workflow labels found: {workflow_labels}
     Ask user to remove conflicting labels or use --workflow flag
   END
   ```

4. **Validate detected workflow exists in config:**
   ```
   IF detected_workflow is not null THEN
     IF detected_workflow NOT IN config.workflows THEN
       ERROR: Workflow '{detected_workflow}' from label not found in config
       Available workflows: {list config.workflows}
       Use --workflow flag to override or fix the label
     END
   END
   ```

### Priority Order for Workflow Selection
1. **Explicit `--workflow` flag** (highest priority - user override)
2. **Label detection** (`workflow:*` labels) - MUST exist in config
3. **First workflow in config** (fallback - only if no label found)

### Example: Successful Detection
```
Issue #48 has labels: ["workflow:dataset-evaluate", "priority:high"]

1. No --workflow flag provided
2. Fetch issue #48 via /fractary-work:issue-fetch 48
3. Filter labels: found "workflow:dataset-evaluate"
4. Extract workflow_id: "dataset-evaluate"
5. Validate: "dataset-evaluate" exists in config.workflows ✓
6. Use dataset-evaluate workflow
```

### Example: Workflow Not Found Error
```
Issue #48 has labels: ["workflow:custom-flow", "priority:high"]

1. No --workflow flag provided
2. Fetch issue #48
3. Detect label: workflow:custom-flow
4. Validate: "custom-flow" NOT in config.workflows

ERROR: Workflow 'custom-flow' from label not found in configuration
Available workflows: default, hotfix, dataset-evaluate
Fix: Remove invalid label OR use --workflow flag to override
```

### Multi-Item Behavior
When processing multiple work items (e.g., `/faber:manage 48,50,52`):
- Workflow is detected from **FIRST work item only** (#48)
- All items in batch will use the **same workflow**
- If items require different workflows, run separate commands

### Error Handling
| Scenario | Action |
|----------|--------|
| Issue fetch fails | Log warning, continue with fallback |
| Detected workflow not in config | **ERROR** - do not fallback silently |
| Multiple `workflow:*` labels | **ERROR** - ambiguous, ask user to fix |
| No workflow labels | Continue with fallback (first workflow) |

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

## Workflow Detection from Labels

When `--workflow` flag is not provided, this command automatically detects the workflow from issue labels.

**Label Pattern Recognized:**
- `workflow:{workflow_id}` (e.g., `workflow:dataset-evaluate`)

**Priority Order:**
1. `--workflow` flag (explicit user override)
2. Label detection (`workflow:*`) - MUST exist in config or errors
3. First workflow in config (fallback - only if no label found)

**Example:**
```bash
# Issue #48 has label "workflow:dataset-evaluate"
/faber:manage 48
# → Detects and uses "dataset-evaluate" workflow

# Override with explicit flag
/faber:manage 48 --workflow hotfix
# → Uses "hotfix" workflow (ignores label)
```

**Strict Validation:**
If a `workflow:*` label is detected but the workflow doesn't exist in config, the command will **error** (not silently fallback). This respects the user's explicit intent and prevents running the wrong workflow.

**Multi-Item Batches:**
When processing multiple work items (e.g., `48,50,52`), the workflow is detected from the **first item only**. All items use the same workflow. Run separate commands if items need different workflows.

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

### Working Directory Transitions

**Initial State** (when command starts):
```
Current Directory: /path/to/repo (main working directory)
```

**After Frame Phase** (branch-manager creates worktree):
```
Current Directory: /path/to/repo/.worktrees/feat-123-description
```

**Directory Tracking**:
- **Repo Root**: Always accessible via `git rev-parse --show-toplevel`
- **Original Path**: Captured in registry as `repo_root`
- **Worktree Path**: Active working directory for workflow execution
- **State Files**: Located in worktree's `.fractary/plugins/faber/state.json`

**Why Subfolder Matters**:
- ✅ Claude can switch to `.worktrees/feat-123-*` (within project scope)
- ❌ Claude cannot switch to `../repo-wt-feat-123-*` (outside project scope)
- ✅ All file operations work normally (Read, Write, Edit tools)
- ✅ Git commands work (worktree is a full working directory)

**Example Workflow**:
```
1. User runs: /faber:manage 123
   → CWD: /path/to/repo

2. Command invokes: faber-director skill
   → CWD: /path/to/repo (still)

3. Skill invokes: faber-manager agent
   → CWD: /path/to/repo (agent context)

4. Frame phase: branch-manager creates worktree
   → CWD: /path/to/repo/.worktrees/feat-123-description (switched!)

5. Architect, Build, Evaluate phases
   → CWD: /path/to/repo/.worktrees/feat-123-description (remains)

6. Release phase: creates PR from worktree
   → CWD: /path/to/repo/.worktrees/feat-123-description (still here)

7. Workflow completes
   → CWD: /path/to/repo/.worktrees/feat-123-description (stays)
   → Worktree remains for review/cleanup
```

**Concurrent Workflows**:
```
Terminal 1:
  /faber:manage 123
  → CWD: /path/to/repo/.worktrees/feat-123-*

Terminal 2 (while #123 is running):
  /faber:manage 124
  → CWD: /path/to/repo/.worktrees/feat-124-*

No conflict! Each workflow has isolated working directory.
```

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
