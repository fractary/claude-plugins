---
name: fractary-repo:branch-create
description: Create a new Git branch with semantic naming or direct branch name
argument-hint: '"<branch-name-or-description>" [--base <branch>] [--prefix <prefix>] [--work-id <id>]'
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
- Check for work tracking integration when work_id is not provided (see WORKFLOW step 2)
- Present three numbered options if fractary-work plugin is configured (create issue+branch, branch only, or cancel)
- For Option 1: Create issue first, capture ID, then create branch with that ID automatically
- For Option 2: Create branch only without work tracking
- For Option 3: Cancel and do nothing
- Invoke the fractary-repo:repo-manager agent (or @agent-fractary-repo:repo-manager) when creating branch
- Pass structured request to the agent
- Return the agent's response to the user

**YOU MUST NOT:**
- Perform any operations yourself (except invoking /work:issue-create for Option 1)
- Invoke skills directly (the repo-manager agent handles skill invocation)
- Execute platform-specific logic (that's the agent's job)
- Force work tracking if user chooses Option 2
- Skip the prompt if in description-based mode without work_id (only skip for direct mode)

**THIS COMMAND IS A ROUTER WITH INTELLIGENT PROMPTING AND WORKFLOW AUTOMATION.**
</CRITICAL_RULES>

<WORKFLOW>
1. **Parse user input with flexible logic**
   - Determine invocation mode based on first argument
   - Extract parameters based on mode (see PARSING_LOGIC)
   - Parse optional arguments: --base, --prefix, --work-id
   - Validate required arguments are present for chosen mode

2. **Check for work tracking integration (if no --work-id provided)**
   - If work_id is NOT provided AND mode is description-based (not direct), check if fractary-work plugin is installed and configured
   - Look for `.fractary/plugins/work/config.json` to detect work plugin
   - If work plugin is available, present three options to the user:
     ```
     ℹ️  Notice: No work item specified for this branch.

     The fractary-work plugin is configured. How would you like to proceed?

     1. [RECOMMENDED] Create issue and branch (automatic)
        → Creates issue: /work:issue-create "{description}" --type {inferred_type}
        → Then creates branch: {prefix}/{issue-id}-{slug}

     2. Create branch only (no work tracking)
        → Creates branch: {prefix}/{slug}

     3. Cancel (do nothing)

     Enter your choice (1, 2, or 3):
     ```
   - Wait for user input (1, 2, or 3)
   - **Option 1 (Recommended) - Automatic Issue + Branch Creation**:
     - Invoke /work:issue-create command: `/work:issue-create "{description}" --type {inferred_type}`
     - Parse the response to extract the issue ID (e.g., "123" from "#123")
     - If issue creation succeeds:
       - Display: `✅ Created issue #{issue_id}: "{description}"`
       - Automatically proceed to create branch with that work_id
       - The branch will be named: `{prefix}/{issue_id}-{slug}`
       - Display: `✅ Created branch: {prefix}/{issue_id}-{slug}`
       - Display: `Branch is now linked to issue #{issue_id} for automatic tracking.`
     - If issue creation fails:
       - Display the error message
       - Offer fallback options (see ERROR_HANDLING)
   - **Option 2 - Branch Only**:
     - Proceed with branch creation without work tracking
     - Use the original parameters (no work_id)
     - The branch will be named: `{prefix}/{slug}`
     - Display: `✅ Created branch: {prefix}/{slug}`
   - **Option 3 - Cancel**:
     - Exit gracefully without creating anything
     - Display: "Branch creation cancelled."

3. **Build structured request**
   - Map to "create-branch" operation
   - Package parameters based on mode
   - Include work_id if provided

4. **Invoke agent**
   - Invoke fractary-repo:repo-manager agent with the request

5. **Return response**
   - The repo-manager agent will handle the operation and return results
   - Display results to the user
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

### Detection Logic

```
IF arg contains "/" THEN
  Mode 1: Direct branch name
ELSE
  Mode 2: Description-based naming
END

work_id is always optional via --work-id flag
```
</PARSING_LOGIC>

<ARGUMENT_PARSING>
## Arguments

### Required Argument:
- `<branch-name-or-description>` (string): Either a full branch name (e.g., "feature/my-branch") or a description (e.g., "add CSV export")

### Optional Arguments (all modes):
- `--base <branch>` (string): Base branch name to create from (default: main/master)
- `--prefix <type>` (string): Branch prefix - `feat`, `fix`, `hotfix`, `chore`, `docs`, `test`, `refactor`, `style`, `perf` (default: `feat`)
- `--work-id <id>` (string or number): Work item ID to link branch to (e.g., "123", "PROJ-456"). Optional.

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
```

### Work Tracking Integration Example
```bash
# Create branch without work_id (triggers work plugin prompt)
/repo:branch-create "add CSV export" --prefix feat

# Output shows:
# ℹ️  Notice: No work item specified for this branch.
#
# The fractary-work plugin is configured. How would you like to proceed?
#
# 1. [RECOMMENDED] Create issue and branch (automatic)
#    → Creates issue: /work:issue-create "add CSV export" --type feature
#    → Then creates branch: feat/123-add-csv-export
#
# 2. Create branch only (no work tracking)
#    → Creates branch: feat/add-csv-export
#
# 3. Cancel (do nothing)
#
# Enter your choice (1, 2, or 3):

# ===== OPTION 1: User enters "1" (RECOMMENDED) =====
# System automatically:
# 1. Creates issue #123: "add CSV export"
# 2. Creates branch: feat/123-add-csv-export
# 3. Output:
#    ✅ Created issue #123: "add CSV export"
#    ✅ Created branch: feat/123-add-csv-export
#    Branch is now linked to issue #123 for automatic tracking.

# ===== OPTION 2: User enters "2" =====
# System creates branch without work tracking:
# ✅ Created branch: feat/add-csv-export

# ===== OPTION 3: User enters "3" =====
# System cancels:
# Branch creation cancelled.

# ===== SKIP PROMPT: Use direct mode =====
/repo:branch-create feat/experimental-feature
# → No work tracking prompt, creates branch: feat/experimental-feature

# ===== SKIP PROMPT: Provide work_id explicitly =====
/repo:branch-create "add CSV export" --work-id 123 --prefix feat
# → No prompt, creates branch: feat/123-add-csv-export
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the repo-manager agent using declarative syntax:

**Agent**: fractary-repo:repo-manager (or @agent-fractary-repo:repo-manager)

**Request structure varies by mode**:

### Mode 1: Direct Branch Name
```json
{
  "operation": "create-branch",
  "parameters": {
    "mode": "direct",
    "branch_name": "feature/my-new-feature",
    "base_branch": "main",
    "work_id": "123"  // optional
  }
}
```

### Mode 2: Description-based Naming
```json
{
  "operation": "create-branch",
  "parameters": {
    "mode": "description",
    "description": "my experimental feature",
    "prefix": "feat",
    "base_branch": "main",
    "work_id": "123"  // optional
  }
}
```

The repo-manager agent will:
1. Receive the request with mode indicator
2. Route to appropriate skill(s) based on mode:
   - **Direct**: branch-manager only
   - **Description**: branch-namer → branch-manager (if work_id provided, includes in branch name)
3. Execute platform-specific logic (GitHub/GitLab/Bitbucket)
4. Return structured response
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing branch name or description**:
```
Error: Branch name or description is required
Usage: /repo:branch-create <branch-name-or-description> [options]
Examples:
  /repo:branch-create feature/my-branch
  /repo:branch-create "my feature description"
  /repo:branch-create "add CSV export" --work-id 123
```

**Branch already exists**:
```
Error: Branch already exists: feature/my-new-feature
Use a different name or delete the existing branch with /repo:branch-delete
```

**Invalid branch name**:
```
Error: Invalid branch name format: invalid//branch
Branch names cannot contain consecutive slashes or invalid characters
```

**Invalid option selection**:
```
Error: Invalid choice. Please enter 1, 2, or 3.

Enter your choice (1, 2, or 3):
```

**Option 1 failure (issue creation fails)**:
```
❌ Failed to create issue: [error message]

Would you like to:
  A. Retry issue creation
  B. Create branch only (without work tracking)
  C. Cancel

Enter your choice (A, B, or C):
```

**Work plugin not configured properly**:
```
Warning: fractary-work plugin detected but not properly configured.
Creating branch without work tracking.

To configure: /work:init
```
</ERROR_HANDLING>

<NOTES>
## Branch Naming Conventions

### Description-based Mode (with work_id)
When you provide `--work-id`, branches follow the pattern: `<prefix>/<work-id>-<description-slug>`

Example: `feat/123-add-csv-export`

### Description-based Mode (without work_id)
When you don't provide `--work-id`, branches follow the pattern: `<prefix>/<description-slug>`

Example: `feat/my-experimental-feature`

### Direct Mode
You specify the exact branch name: `<prefix>/<whatever-you-want>`

Example: `feature/my-custom-branch-name`

## Branch Prefixes

- **feat/**: New features
- **fix/**: Bug fixes
- **hotfix/**: Urgent production fixes
- **chore/**: Maintenance tasks
- **docs/**: Documentation changes
- **test/**: Test-related changes
- **refactor/**: Code refactoring
- **style/**: Code style/formatting changes
- **perf/**: Performance improvements

## When to Use Each Mode

- **Direct Mode**: When you want full control over branch naming, or following a specific convention
- **Description-based Mode**: For quick branch creation where the system auto-generates the name from your description
- **With --work-id**: Optional flag to link the branch to a work item (issue, ticket, etc.)

## Work Tracking Integration

This command integrates with the fractary-work plugin for issue tracking:

### Three-Option Workflow Prompt

When you create a branch **without** `--work-id` (and in description-based mode), the command checks if fractary-work is configured.

If detected, you're presented with **three numbered options**:

#### Option 1: Create Issue and Branch (RECOMMENDED)
- **Automatic workflow**: Creates issue first, then branch with that issue ID
- **Seamless**: No need to run multiple commands or copy/paste issue IDs
- **Best practice**: Ensures all branches are tracked from the start
- Infers issue type from branch prefix:
  - `feat` → `feature` or `enhancement`
  - `fix` → `bug`
  - `hotfix` → `bug` (high priority)
  - `chore` → `task` or `chore`
  - `docs` → `documentation`
  - `test` → `test`
  - `refactor` → `enhancement` or `task`

#### Option 2: Create Branch Only
- **Quick mode**: Just creates the branch without work tracking
- **Use when**: You'll add work tracking later, or don't need it for this branch
- Creates branch: `{prefix}/{description-slug}`

#### Option 3: Cancel
- **Stop**: Exits without creating anything
- **Use when**: You need to reconsider or change your approach

### Interactive Workflow Example

```bash
# 1. Command detects no work_id
/repo:branch-create "add CSV export" --prefix feat

# 2. System prompts with three options
# ℹ️  Notice: No work item specified for this branch.
#
# The fractary-work plugin is configured. How would you like to proceed?
#
# 1. [RECOMMENDED] Create issue and branch (automatic)
#    → Creates issue: /work:issue-create "add CSV export" --type feature
#    → Then creates branch: feat/123-add-csv-export
#
# 2. Create branch only (no work tracking)
#    → Creates branch: feat/add-csv-export
#
# 3. Cancel (do nothing)
#
# Enter your choice (1, 2, or 3): 1

# 3. System executes Option 1 automatically
# ✅ Created issue #123: "add CSV export"
# ✅ Created branch: feat/123-add-csv-export
# Branch is now linked to issue #123 for automatic tracking.
```

### Benefits of Work Tracking

- **Traceability**: Link commits, branches, and PRs to issues
- **Automatic closing**: PRs can auto-close issues with "closes #123"
- **Better organization**: See which branches relate to which issues
- **Team visibility**: Others can see what you're working on

### Skipping the Prompt

The three-option prompt **only appears** when:
- You're in description-based mode (no `/` in branch name)
- No `--work-id` is provided
- The fractary-work plugin is installed and configured

**To skip the prompt entirely**, use any of these approaches:

1. **Direct branch naming**: `/repo:branch-create feature/my-branch`
   - Prompt is skipped for direct mode

2. **Provide work_id explicitly**: `/repo:branch-create "description" --work-id 123`
   - Prompt is skipped when work_id is provided

3. **Select Option 2**: When prompted, enter `2` to proceed without work tracking
   - Quick escape if you don't want tracking for this branch

4. **Unconfigure work plugin**: Remove `.fractary/plugins/work/config.json`
   - Disables work tracking integration globally

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
- `/work:issue-create` - Create new work item/issue
- `/work:issue-list` - List work items
- `/work:issue-close` - Close work item
- `/work:init` - Configure work tracking plugin
</NOTES>
