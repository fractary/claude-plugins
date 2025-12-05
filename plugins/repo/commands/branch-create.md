---
name: fractary-repo:branch-create
description: Create a new Git branch with semantic naming or direct branch name
model: claude-haiku-4-5
argument-hint: '["<branch-name-or-description>"] [--base <branch>] [--prefix <prefix>] [--work-id <id>] [--worktree] [--spec-create]'
---

<CONTEXT>
You are the repo:branch-create command for the fractary-repo plugin.
Your role is to parse user input and invoke the repo-manager agent to create a new branch.

This command supports:
- **Direct branch names**: Provide the full branch name (e.g., "feature/my-branch")
- **Description-based naming**: Provide description + optional prefix (auto-generates branch name)
- **Optional work tracking**: Add --work-id flag to link branch to work item (optional)
</CONTEXT>

<CRITICAL_RULES>
**YOU MUST:**
- Parse the command arguments from user input using flexible parsing logic
- Invoke the fractary-repo:repo-manager agent with the parsed parameters
- Pass the structured request to the agent
- Return the agent's response to the user

**YOU MUST NOT:**
- Perform any operations yourself
- Invoke skills directly (the repo-manager agent handles skill invocation)
- Execute platform-specific logic (that's the agent's job)
- Detect or check for work plugin availability (the agent handles this)
- Present prompts or make decisions (the agent handles orchestration)

**THIS COMMAND IS ONLY A ROUTER.**

**Note**: The repo-manager agent handles all work tracking integration, including:
- Detecting if fractary-work plugin is configured
- Presenting the three-option prompt (create issue+branch, branch only, cancel)
- Invoking /fractary-work:issue-create if user selects Option 1
- Extracting and displaying URLs for created resources
</CRITICAL_RULES>

<WORKFLOW>
1. **Parse user input**
   - Determine invocation mode based on arguments (see PARSING_LOGIC)
   - Extract parameters based on mode
   - Parse optional arguments: --base, --prefix, --work-id, --worktree, --spec-create
   - Validate required arguments are present

2. **Handle Semantic Mode (if applicable)**
   - If Mode 3 detected (no first arg, only --work-id):
     a. Invoke `/fractary-work:issue-fetch {work_id}` using SlashCommand tool
     b. Extract issue title and type from response
     c. If --prefix not provided, infer from issue type:
        - feature/enhancement → feat
        - bug/defect → fix
        - documentation → docs
        - chore/maintenance → chore
        - default → feat
     d. Use issue title as description
     e. Proceed with description-based naming flow

3. **Build structured request**
   - Map to "create-branch" operation
   - Package parameters based on mode:
     - Direct mode: branch_name, base_branch, work_id (optional), create_worktree, spec_create
     - Description mode: description, prefix, base_branch, work_id (optional), create_worktree, spec_create
     - Semantic mode: description (from issue), prefix (from issue type), base_branch, work_id, create_worktree, spec_create

4. **ACTUALLY INVOKE the Task tool**
   - Use the Task tool with subagent_type="fractary-repo:repo-manager"
   - Pass the structured JSON request in the prompt parameter
   - The agent will handle:
     - Work plugin detection (if work_id not provided)
     - User prompting (three-option workflow)
     - Issue creation (if user selects Option 1)
     - Branch creation
     - Worktree creation (if create_worktree is true)
     - URL extraction and display

5. **Return agent response**
   - The Task tool returns the agent's output
   - Display it to the user (prompts, success messages, URLs, errors)
</WORKFLOW>

<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the **space-separated** argument syntax (consistent with work/repo plugin family):
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in quotes
- **Example**: `--base "feature branch"` ✅
- **Wrong**: `--base feature branch` ❌

### Quote Usage

**Always use quotes for multi-word values:**
```bash
✅ /repo:branch-create 123 "add CSV export feature"
✅ /repo:branch-create 123 "fix authentication bug" --base develop

❌ /repo:branch-create 123 add CSV export feature
❌ /repo:branch-create 123 fix authentication bug --base develop
```

**Single-word values don't require quotes:**
```bash
✅ /repo:branch-create 123 add-csv-export
✅ /repo:branch-create 123 fix-bug --prefix bugfix
✅ /repo:branch-create 123 add-feature --base develop
```

**Branch names and descriptions:**
- **Hyphenated descriptions** (recommended): Use hyphens, no quotes needed
  - `add-csv-export` ✅
  - `fix-authentication-bug` ✅
- **Multi-word descriptions**: Must use quotes
  - `"add CSV export"` ✅
  - `"fix authentication bug"` ✅
</ARGUMENT_SYNTAX>

<PARSING_LOGIC>
## Flexible Argument Parsing

This command intelligently determines the invocation mode based on the arguments:

### Mode 1: Direct Branch Name
**Pattern**: First arg contains `/` (looks like a branch name)
```bash
/repo:branch-create feature/my-new-feature
/repo:branch-create bugfix/authentication-fix --base develop
/repo:branch-create feature/123-add-export --work-id 123
```

**Parsing**:
- `branch_name` = first argument
- `base_branch` = --base value or "main"
- `work_id` = --work-id value (optional)
- Create branch directly with the specified name

### Mode 2: Description-based Naming
**Pattern**: First arg doesn't contain `/`
```bash
/repo:branch-create "my experimental feature" --prefix feat
/repo:branch-create "add CSV export" --prefix feat --work-id 123
/repo:branch-create "quick-fix" --prefix fix
```

**Parsing**:
- `description` = first argument
- `prefix` = --prefix value or "feat"
- `work_id` = --work-id value (optional)
- Generate branch name: `{prefix}/{work_id-}{description-slug}` if work_id provided, otherwise `{prefix}/{description-slug}`

### Mode 3: Semantic Mode (Work-ID Only)
**Pattern**: No first arg, only `--work-id` provided
```bash
/repo:branch-create --work-id 123
/repo:branch-create --work-id 123 --prefix feat
/repo:branch-create --work-id 123 --base develop
```

**Parsing**:
- `work_id` = --work-id value (required)
- `prefix` = --prefix value or inferred from issue type
- Fetch issue title from work plugin
- Use issue title as description
- Generate branch name: `{prefix}/{work_id-}{issue-title-slug}`

**Process**:
1. Invoke `/fractary-work:issue-fetch {work_id}` to retrieve issue details
2. Extract issue title from response
3. Infer prefix from issue type if not provided (feature→feat, bug→fix, etc.)
4. Use title as description for branch naming
5. Proceed with description-based naming flow

### Detection Logic

```
IF no first argument AND --work-id provided THEN
  Mode 3: Semantic mode (fetch issue title)
ELSE IF first arg contains "/" THEN
  Mode 1: Direct branch name
ELSE IF first arg provided THEN
  Mode 2: Description-based naming
ELSE
  ERROR: Either branch name/description OR --work-id is required
END
```
</PARSING_LOGIC>

<ARGUMENT_PARSING>
## Arguments

### Required Argument:
- `<branch-name-or-description>` (string): Either a full branch name (e.g., "feature/my-branch") or a description (e.g., "add CSV export")
  - **EXCEPTION**: This argument is optional if `--work-id` is provided. When only `--work-id` is given, the issue title is fetched automatically.

### Optional Arguments (all modes):
- `--base <branch>` (string): Base branch name to create from (default: main/master)
- `--prefix <type>` (string): Branch prefix - `feat`, `fix`, `hotfix`, `chore`, `docs`, `test`, `refactor`, `style`, `perf` (default: `feat`)
- `--work-id <id>` (string or number): Work item ID to link branch to (e.g., "123", "PROJ-456"). Optional, but if provided alone (without description), enables semantic mode where issue title is fetched automatically.
- `--worktree` (boolean flag): Create a git worktree for parallel development. No value needed, just include the flag
- `--spec-create` (boolean flag): Automatically create a specification after branch creation (requires fractary-spec plugin and --work-id). No value needed, just include the flag

### Maps to Operation
All modes map to: `create-branch` operation in repo-manager agent
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

### Mode 1: Direct Branch Name
```bash
# Create branch with explicit name
/repo:branch-create feature/my-new-feature

# Create from specific base branch
/repo:branch-create bugfix/auth-issue --base develop

# Create with work item tracking
/repo:branch-create feature/123-csv-export --work-id 123

# Create hotfix branch
/repo:branch-create hotfix/critical-security-patch --base production
```

### Mode 2: Description-based Naming
```bash
# Create feature branch from description (auto-generates: feat/my-experimental-feature)
/repo:branch-create "my experimental feature"

# Specify branch type (auto-generates: fix/quick-authentication-fix)
/repo:branch-create "quick authentication fix" --prefix fix

# Link to work item (auto-generates: feat/123-add-csv-export)
/repo:branch-create "add CSV export" --work-id 123

# Full example with all options (auto-generates: feat/456-new-dashboard)
/repo:branch-create "new dashboard" --prefix feat --work-id 456 --base develop

# Create branch with worktree for parallel development
/repo:branch-create "add CSV export" --work-id 123 --worktree
# Result: feat/123-add-csv-export + worktree at ../repo-wt-feat-123-add-csv-export

# Create branch and automatically create spec (requires work_id)
/repo:branch-create "add CSV export" --work-id 123 --spec-create
# Result: feat/123-add-csv-export + spec file created

# Full workflow: branch + worktree + spec
/repo:branch-create "add CSV export" --work-id 123 --worktree --spec-create
# Result: feat/123-add-csv-export + worktree + spec file
```

### Mode 3: Semantic Mode (Work-ID Only)
```bash
# Fetch issue #123 and use its title as description
/repo:branch-create --work-id 123
# If issue #123 title is "Add CSV export feature"
# Result: feat/123-add-csv-export-feature

# Specify branch type (overrides inferred type from issue)
/repo:branch-create --work-id 456 --prefix fix
# Even if issue is type "feature", uses "fix" prefix
# Result: fix/456-{issue-title-slug}

# Create from specific base branch
/repo:branch-create --work-id 789 --base develop
# Result: feat/789-{issue-title-slug} (created from develop)

# Create with worktree
/repo:branch-create --work-id 138 --worktree
# Fetches issue #138 title, creates branch + worktree
# Result: {prefix}/138-{issue-title-slug} + worktree at ../repo-wt-{prefix}-138-{issue-title-slug}
```

### Work Tracking Integration Example
```bash
# Without work_id - triggers prompt (handled by repo-manager agent)
/repo:branch-create "add CSV export" --prefix feat
# Agent presents: 3 options (create issue+branch, branch only, cancel)

# With work_id - skips prompt
/repo:branch-create "add CSV export" --work-id 123 --prefix feat
# Result: feat/123-add-csv-export

# Direct mode - skips prompt
/repo:branch-create feat/experimental-feature
# Result: feat/experimental-feature
```

For detailed workflow examples, see the Work Tracking Integration section below.
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

**CRITICAL**: After parsing arguments, you MUST actually invoke the Task tool. Do NOT just describe what should be done.

**How to invoke**:
Use the Task tool with these parameters:
- **subagent_type**: "fractary-repo:repo-manager"
- **description**: Brief description of what you're doing (e.g., "Create branch for work item 123")
- **prompt**: JSON string containing the operation and parameters

**Example Task tool invocations**:

### Mode 1: Direct Branch Name
```
Task(
  subagent_type="fractary-repo:repo-manager",
  description="Create branch feature/my-new-feature",
  prompt='{
    "operation": "create-branch",
    "parameters": {
      "mode": "direct",
      "branch_name": "feature/my-new-feature",
      "base_branch": "main",
      "work_id": "123",
      "create_worktree": false,
      "spec_create": false
    }
  }'
)
```

### Mode 2: Description-based Naming
```
Task(
  subagent_type="fractary-repo:repo-manager",
  description="Create branch from description",
  prompt='{
    "operation": "create-branch",
    "parameters": {
      "mode": "description",
      "description": "my experimental feature",
      "prefix": "feat",
      "base_branch": "main",
      "work_id": "123",
      "create_worktree": false,
      "spec_create": false
    }
  }'
)
```

### With Worktree
```
Task(
  subagent_type="fractary-repo:repo-manager",
  description="Create branch with worktree",
  prompt='{
    "operation": "create-branch",
    "parameters": {
      "mode": "description",
      "description": "add CSV export",
      "prefix": "feat",
      "work_id": "123",
      "create_worktree": true,
      "spec_create": false
    }
  }'
)
```

### With Spec Creation
```
Task(
  subagent_type="fractary-repo:repo-manager",
  description="Create branch with spec",
  prompt='{
    "operation": "create-branch",
    "parameters": {
      "mode": "description",
      "description": "add CSV export",
      "prefix": "feat",
      "work_id": "123",
      "create_worktree": false,
      "spec_create": true
    }
  }'
)
```

**What the agent does**:
1. Receives the request with mode indicator
2. Routes to appropriate skill(s) based on mode:
   - **Direct**: branch-manager only
   - **Description**: branch-namer → branch-manager
3. Executes platform-specific logic (GitHub/GitLab/Bitbucket)
4. Returns structured response to you
5. You display the response to the user

**DO NOT**:
- ❌ Write text like "Use the @agent-fractary-repo:repo-manager agent to create a branch"
- ❌ Show the JSON request to the user without actually invoking the Task tool
- ❌ Invoke skills directly
- ✅ ACTUALLY call the Task tool with the parameters shown above
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle at the **command level** (argument parsing):

**Missing branch name/description AND work-id**:
```
Error: Either branch name/description OR --work-id is required
Usage: /repo:branch-create <branch-name-or-description> [options]
       /repo:branch-create --work-id <id> [options]
Examples:
  /repo:branch-create feature/my-branch
  /repo:branch-create "my feature description"
  /repo:branch-create "add CSV export" --work-id 123
  /repo:branch-create --work-id 123
```

**Work plugin not available (semantic mode)**:
```
Error: Cannot fetch issue details - work plugin not configured
To use semantic mode (--work-id only), you need:
1. Install fractary-work plugin
2. Run /fractary-work:init to configure it
3. Then retry: /repo:branch-create --work-id {id}

Or provide a description: /repo:branch-create "description" --work-id {id}
```

**Issue not found (semantic mode)**:
```
Error: Issue #{work_id} not found
Please verify the issue ID exists in your work tracking system
Or provide a description: /repo:branch-create "description" --work-id {work_id}
```

**Invalid argument format**:
```
Error: Invalid argument format
Expected: /repo:branch-create <branch-name-or-description> [options]
```

All other errors are handled by the repo-manager agent, including:
- Branch already exists
- Invalid branch name format
- Invalid option selection (in work tracking prompt)
- Issue creation failures
- Work plugin configuration issues
- Network errors
- Permission errors
</ERROR_HANDLING>

<NOTES>
## Branch Naming Conventions

**Description mode with work_id**: `<prefix>/<work-id>-<slug>` (e.g., `feat/123-add-csv-export`)
**Description mode without work_id**: `<prefix>/<slug>` (e.g., `feat/my-experimental-feature`)
**Direct mode**: Exact name you specify (e.g., `feature/my-custom-branch-name`)

**Common prefixes**: `feat`, `fix`, `hotfix`, `chore`, `docs`, `test`, `refactor`, `style`, `perf`

## Work Tracking Integration

This command integrates with the fractary-work plugin for issue tracking.

**Important**: The work tracking integration is handled by the **repo-manager agent**, not by this command. The command simply routes your request to the agent, which then detects work plugin availability and manages the workflow.

### Three-Option Workflow Prompt

When you create a branch **without** `--work-id` (and in description-based mode), the **repo-manager agent** checks if fractary-work is configured.

If detected, the **agent** presents you with **three numbered options**:
1. **[RECOMMENDED] Create issue and branch** - Automatic workflow, creates issue first then branch
2. **Create branch only** - Skip work tracking
3. **Cancel** - Do nothing

The agent infers issue type from branch prefix (feat→feature, fix→bug, etc.)

### How It Works

1. **No work_id provided** (description mode) → Agent checks for fractary-work plugin
2. **Plugin detected** → Agent presents 3 options:
   - Option 1: Create issue + branch automatically
   - Option 2: Create branch only
   - Option 3: Cancel
3. **Option 1 selected** → Agent creates issue, captures ID, creates branch with that ID
4. **URLs displayed** → Direct links to created issue and branch

### Skipping the Prompt

The prompt only appears in description mode without `--work-id`. To skip:
- Use direct mode: `/repo:branch-create feature/my-branch`
- Provide `--work-id`: `/repo:branch-create "desc" --work-id 123`
- Select Option 2 when prompted

## Platform Support

This command works with:
- GitHub
- GitLab
- Bitbucket

Platform is configured via `/repo:init` and stored in `.fractary/plugins/repo/config.json`.

## See Also

### Repo Plugin Commands
- `/repo:branch-delete` - Delete branches
- `/repo:branch-list` - List branches
- `/repo:commit` - Create commits
- `/repo:push` - Push branches
- `/repo:pr-create` - Create pull requests
- `/repo:init` - Configure repo plugin

### Work Plugin Integration
- `/fractary-work:issue-create` - Create new work item/issue
- `/fractary-work:issue-list` - List work items
- `/fractary-work:issue-close` - Close work item
- `/fractary-work:init` - Configure work tracking plugin
</NOTES>
