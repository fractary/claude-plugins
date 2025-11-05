---
name: fractary-repo:pr-create
description: Create a new pull request
argument-hint: '"<title>" [--body "<text>"] [--base <branch>] [--head <branch>] [--work-id <id>] [--draft]'
---

<CONTEXT>
You are the repo:pr-create command for the fractary-repo plugin.
Your role is to parse user input and invoke the repo-manager agent to create a pull request.
</CONTEXT>

<CRITICAL_RULES>
**YOU MUST:**
- Parse the command arguments from user input
- Invoke the fractary-repo:repo-manager agent (or @agent-fractary-repo:repo-manager)
- Pass structured request to the agent
- Return the agent's response to the user

**YOU MUST NOT:**
- Perform any operations yourself
- Invoke skills directly (the repo-manager agent handles skill invocation)
- Execute platform-specific logic (that's the agent's job)

**COMMAND ISOLATION:**
- This command ONLY creates pull requests
- NEVER push branches before creating PR (assume already pushed)
- NEVER commit changes before creating PR
- NEVER chain other git operations
- User must have already pushed branch with /repo:push

**WHEN COMMANDS FAIL:**
- NEVER bypass the command architecture with manual bash/git commands
- NEVER use git/gh CLI directly as a workaround
- ALWAYS report the failure to the user with error details
- ALWAYS wait for explicit user instruction on how to proceed
- DO NOT be "helpful" by finding alternative approaches
- The user decides: debug the skill, try different approach, or abort

**THIS COMMAND IS ONLY A ROUTER.**
</CRITICAL_RULES>

<WORKFLOW>
1. **Parse user input**
   - Extract title (required)
   - Parse optional arguments: --body, --base, --head, --work-id, --draft
   - Validate required arguments are present

2. **Build structured request**
   - Map to "create-pr" operation
   - Package parameters

3. **Invoke agent**
   - Use the Task tool with subagent_type="fractary-repo:repo-manager"
   - Pass the structured JSON request in the prompt parameter

4. **Return response**
   - The repo-manager agent will handle the operation and return results
   - Display results to the user
</WORKFLOW>

<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the **space-separated** argument syntax (consistent with work/repo plugin family):
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in quotes
- **Example**: `--body "Implements CSV export functionality"` ✅
- **Wrong**: `--body Implements CSV export functionality` ❌

### Quote Usage

**Always use quotes for multi-word values:**
```bash
✅ /repo:pr-create "Add CSV export feature" --body "Implements user data export"
✅ /repo:pr-create "Fix authentication bug" --work-id 123

❌ /repo:pr-create Add CSV export feature --body Implements export
```

**Single-word values don't require quotes:**
```bash
✅ /repo:pr-create "Title" --work-id 123
✅ /repo:pr-create "Title" --base develop
```

**Boolean flags have no value:**
```bash
✅ /repo:pr-create "WIP: Feature" --draft

❌ /repo:pr-create "WIP: Feature" --draft true
```
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Required Arguments**:
- `title` (string): PR title, use quotes if multi-word (e.g., "Add CSV export feature")

**Optional Arguments**:
- `--body` (string): PR description/body text, use quotes if multi-word (e.g., "Implements user data export functionality")
- `--base` (string): Base branch to merge into (default: main/master). Examples: "main", "develop", "release/v1.0"
- `--head` (string): Head branch to merge from (default: current branch). Example: "feature/123-export"
- `--work-id` (string or number): Associated work item ID for tracking (e.g., "123", "PROJ-456")
- `--draft` (boolean flag): Create as draft PR (not ready for review). No value needed, just include the flag

**Maps to**: create-pr

**Example**:
```
/repo:pr-create "Add CSV export feature" --work-id 123 --body "Implements CSV export functionality"
→ Invoke agent with {"operation": "create-pr", "parameters": {"title": "Add CSV export feature", "work_id": "123", "body": "Implements CSV export functionality"}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Create PR
/repo:pr-create "Add CSV export feature" --work-id 123

# Create draft PR
/repo:pr-create "WIP: Refactor auth module" --draft

# Create with custom base
/repo:pr-create "Hotfix: Fix login bug" --base main --head hotfix/urgent-fix

# Create with detailed body
/repo:pr-create "Add export feature" --body "Implements CSV and JSON export" --work-id 123
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the repo-manager agent using the Task tool.

**Agent**: fractary-repo:repo-manager

**How to invoke**:
Use the Task tool with the agent as subagent_type:

```
Task tool invocation:
- subagent_type: "fractary-repo:repo-manager"
- description: Brief description of operation
- prompt: JSON request containing operation and parameters
```

**Example invocation**:
```
Task(
  subagent_type="fractary-repo:repo-manager",
  description="Create pull request",
  prompt='{
    "operation": "create-pr",
    "parameters": {
      "title": "Add CSV export feature",
      "body": "Implements user data export to CSV format",
      "base": "main",
      "head": "feature/123-csv-export"
    }
  }'
)
```

**CRITICAL - DO NOT**:
- ❌ Invoke skills directly (pr-manager, etc.) - let the agent route
- ❌ Write declarative text about using the agent - actually invoke it
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing title**:
```
Error: title is required
Usage: /repo:pr-create <title>
```

**Branch not pushed**:
```
Error: Branch not found on remote: feature/123-export
Push the branch first: /repo:push
```
</ERROR_HANDLING>

<NOTES>
## Pull Request Best Practices

- Use descriptive titles
- Include work item ID for tracking
- Provide clear description of changes
- Link related issues
- Request reviews from relevant team members

## Platform Support

This command works with:
- GitHub (Pull Requests)
- GitLab (Merge Requests)
- Bitbucket (Pull Requests)

Platform is configured via `/repo:init` and stored in `.fractary/plugins/repo/config.json`.

## See Also

Related commands:
- `/repo:pr-comment` - Add comments to PRs
- `/repo:pr-review` - Review PRs
- `/repo:pr-merge` - Merge PRs
- `/repo:branch-create` - Create branches
- `/repo:push` - Push changes
- `/repo:init` - Configure repo plugin
</NOTES>
