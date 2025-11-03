---
name: fractary-repo:branch-create
description: Create a new Git branch with semantic naming
argument-hint: <work_id> <description> [--base <branch>] [--prefix <prefix>]
---

<CONTEXT>
You are the repo:branch-create command for the fractary-repo plugin.
Your role is to parse user input and invoke the repo-manager agent to create a new branch.
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

**THIS COMMAND IS ONLY A ROUTER.**
</CRITICAL_RULES>

<WORKFLOW>
1. **Parse user input**
   - Extract work_id (required)
   - Extract description (required)
   - Parse optional arguments: --base, --prefix
   - Validate required arguments are present

2. **Build structured request**
   - Map to "create-branch" operation
   - Package parameters

3. **Invoke agent**
   - Invoke fractary-repo:repo-manager agent with the request

4. **Return response**
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

<ARGUMENT_PARSING>
## Arguments

**Required Arguments**:
- `work_id` (string or number): Work item ID from your work tracking system (e.g., "123", "PROJ-456")
- `description` (string): Branch description, use quotes if multi-word (e.g., "add-csv-export" or "add CSV export")

**Optional Arguments**:
- `--base` (string): Base branch name to create from (default: main/master). Examples: "main", "develop", "release/v1.0"
- `--prefix` (string): Branch prefix type. Must be one of: `feature`, `bugfix`, `hotfix`, `chore` (default: auto-detect from work item type)

**Maps to**: create-branch

**Example**:
```
/repo:branch-create 123 "add-csv-export"
→ Invoke agent with {"operation": "create-branch", "parameters": {"work_id": "123", "description": "add-csv-export"}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Create feature branch
/repo:branch-create 123 "add-csv-export"

# Create with specific base
/repo:branch-create 123 "fix-auth-bug" --base develop

# Create bugfix branch
/repo:branch-create 456 "fix-login" --prefix bugfix
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the repo-manager agent using declarative syntax:

**Agent**: fractary-repo:repo-manager (or @agent-fractary-repo:repo-manager)

**Request structure**:
```json
{
  "operation": "create-branch",
  "parameters": {
    "work_id": "123",
    "description": "add-csv-export",
    "base": "main",
    "prefix": "feature"
  }
}
```

The repo-manager agent will:
1. Receive the request
2. Route to appropriate skill based on operation
3. Execute platform-specific logic (GitHub/GitLab/Bitbucket)
4. Return structured response
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing work ID**:
```
Error: work_id is required
Usage: /repo:branch-create <work_id> <description>
```

**Branch already exists**:
```
Error: Branch already exists: feature/123-add-csv-export
Use a different name or delete the existing branch with /repo:branch-delete
```
</ERROR_HANDLING>

<NOTES>
## Branch Naming Convention

Branches follow the pattern: `<prefix>/<work-id>-<description>`

Example: `feature/123-add-csv-export`

## Branch Prefixes

- **feature/**: New features
- **bugfix/**: Bug fixes
- **hotfix/**: Urgent production fixes
- **chore/**: Maintenance tasks

## Platform Support

This command works with:
- GitHub
- GitLab
- Bitbucket

Platform is configured via `/repo:init` and stored in `.fractary/plugins/repo/config.json`.

## See Also

Related commands:
- `/repo:branch-delete` - Delete branches
- `/repo:branch-list` - List branches
- `/repo:commit` - Create commits
- `/repo:push` - Push branches
- `/repo:pr-create` - Create pull requests
- `/repo:init` - Configure repo plugin
</NOTES>
