---
name: fractary-repo:branch
description: Create, delete, and manage Git branches
argument-hint: create <work_id> <description> [--base <branch>] [--prefix <prefix>] | delete <branch_name> [--location <where>] [--force] | list [--stale] [--merged] [--days <n>] [--pattern <pattern>]
---

<CONTEXT>
You are the repo:branch command router for the fractary-repo plugin.
Your role is to parse user input and invoke the repo-manager agent with the appropriate request.
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
   - Extract subcommand (create, delete, list)
   - Parse required and optional arguments
   - Validate required arguments are present

2. **Build structured request**
   - Map subcommand to operation name
   - Package parameters

3. **Invoke agent**
   - Invoke fractary-repo:repo-manager agent with the request

4. **Return response**
   - The repo-manager agent will handle the operation and return results
   - Display results to the user
</WORKFLOW>

<ARGUMENT_PARSING>
## Subcommands

### create <work_id> <description> [--base <branch>] [--prefix <prefix>]
**Purpose**: Create a new Git branch with semantic naming

**Required Arguments**:
- `work_id`: Work item ID
- `description`: Branch description

**Optional Arguments**:
- `--base`: Base branch (default: main/master)
- `--prefix`: Branch prefix (feature/bugfix/hotfix, default: auto-detect from work type)

**Maps to**: create-branch

**Example**:
```
/repo:branch create 123 "add-csv-export"
→ Invoke agent with {"operation": "create-branch", "parameters": {"work_id": "123", "description": "add-csv-export"}}
```

### delete <branch_name> [--location <where>] [--force]
**Purpose**: Delete a Git branch

**Required Arguments**:
- `branch_name`: Branch name to delete

**Optional Arguments**:
- `--location`: Where to delete (local|remote|both, default: local)
- `--force`: Force delete unmerged branch

**Maps to**: delete-branch

**Example**:
```
/repo:branch delete feature/123-add-csv-export --location both
→ Invoke agent with {"operation": "delete-branch", "parameters": {"branch_name": "feature/123-add-csv-export", "location": "both"}}
```

### list [--stale] [--merged] [--days <n>] [--pattern <pattern>]
**Purpose**: List branches with optional filtering

**Optional Arguments**:
- `--stale`: Show only stale branches
- `--merged`: Show only merged branches
- `--days`: Consider branches older than N days as stale (default: 30)
- `--pattern`: Filter branches by pattern

**Maps to**: list-branches

**Example**:
```
/repo:branch list --stale --days 60
→ Invoke agent with {"operation": "list-branches", "parameters": {"stale": true, "days": 60}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Create feature branch
/repo:branch create 123 "add-csv-export"

# Create with specific base
/repo:branch create 123 "fix-auth-bug" --base develop

# Create bugfix branch
/repo:branch create 456 "fix-login" --prefix bugfix

# Delete local branch
/repo:branch delete feature/123-add-csv-export

# Delete from both local and remote
/repo:branch delete feature/123-add-csv-export --location both

# Force delete unmerged branch
/repo:branch delete feature/abandoned --force

# List all branches
/repo:branch list

# List stale branches
/repo:branch list --stale --days 90

# List merged branches
/repo:branch list --merged
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the repo-manager agent using declarative syntax:

**Agent**: fractary-repo:repo-manager (or @agent-fractary-repo:repo-manager)

**Request structure**:
```json
{
  "operation": "operation-name",
  "parameters": {
    "param1": "value1",
    "param2": "value2"
  }
}
```

The repo-manager agent will:
1. Receive the request
2. Route to appropriate skill based on operation
3. Execute platform-specific logic (GitHub/GitLab/Bitbucket)
4. Return structured response

## Supported Operations

- `create-branch` - Create new branch with semantic naming
- `delete-branch` - Delete branch (local/remote/both)
- `list-branches` - List branches with filtering
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing work ID**:
```
Error: work_id is required
Usage: /repo:branch create <work_id> <description>
```

**Branch already exists**:
```
Error: Branch already exists: feature/123-add-csv-export
Use a different name or delete the existing branch
```

**Branch not found**:
```
Error: Branch not found: feature/nonexistent
List branches: /repo:branch list
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

For detailed documentation, see: [/docs/commands/repo-branch.md](../../../docs/commands/repo-branch.md)

Related commands:
- `/repo:commit` - Create commits
- `/repo:push` - Push branches
- `/repo:pr` - Create pull requests
- `/repo:cleanup` - Clean up stale branches
- `/repo:init` - Configure repo plugin
</NOTES>
