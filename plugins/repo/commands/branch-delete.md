---
name: fractary-repo:branch-delete
description: Delete a Git branch (local, remote, or both)
argument-hint: <branch_name> [--location <where>] [--force] [--worktree-cleanup]
---

<CONTEXT>
You are the repo:branch-delete command for the fractary-repo plugin.
Your role is to parse user input and invoke the repo-manager agent to delete a branch.
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
   - Extract branch_name (required)
   - Parse optional arguments: --location, --force
   - Validate required arguments are present

2. **Build structured request**
   - Map to "delete-branch" operation
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
- **Example**: `--location both` ✅
- **Boolean flags have no value**: `--force` ✅ (NOT `--force true`)

### Quote Usage

**Always use quotes for multi-word values:**
```bash
✅ /repo:branch-delete "feature/old branch name"

❌ /repo:branch-delete feature/old branch name
```

**Single-word values don't require quotes:**
```bash
✅ /repo:branch-delete feature/123-old-feature
✅ /repo:branch-delete feature/123-old-feature --location both
✅ /repo:branch-delete feature/abandoned --force
```
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Required Arguments**:
- `branch_name` (string): Full branch name to delete (e.g., "feature/123-add-export", use quotes if contains spaces)

**Optional Arguments**:
- `--location` (enum): Where to delete the branch. Must be one of: `local`, `remote`, `both` (default: local)
- `--force` (boolean flag): Force delete unmerged branch. No value needed, just include the flag
- `--worktree-cleanup` (boolean flag): Automatically clean up worktree for deleted branch. No value needed, just include the flag. If not provided and worktree exists, user will be prompted

**Maps to**: delete-branch

**Example**:
```
/repo:branch-delete feature/123-add-csv-export --location both
→ Invoke agent with {"operation": "delete-branch", "parameters": {"branch_name": "feature/123-add-csv-export", "location": "both"}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Delete local branch
/repo:branch-delete feature/123-add-csv-export

# Delete from both local and remote
/repo:branch-delete feature/123-add-csv-export --location both

# Force delete unmerged branch
/repo:branch-delete feature/abandoned --force

# Delete remote branch only
/repo:branch-delete feature/old-feature --location remote
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the repo-manager agent using declarative syntax:

**Agent**: fractary-repo:repo-manager (or @agent-fractary-repo:repo-manager)

**Request structure**:
```json
{
  "operation": "delete-branch",
  "parameters": {
    "branch_name": "feature/123-add-csv-export",
    "location": "both",
    "force": true
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

**Missing branch name**:
```
Error: branch_name is required
Usage: /repo:branch-delete <branch_name>
```

**Branch not found**:
```
Error: Branch not found: feature/nonexistent
List branches: /repo:branch-list
```

**Unmerged branch (without --force)**:
```
Error: Branch has unmerged changes: feature/123-wip
Use --force to delete anyway, or merge the changes first
```
</ERROR_HANDLING>

<NOTES>
## Safety Considerations

- Deleting branches is irreversible (unless commits are still in reflog)
- Use `--force` carefully - it will delete branches with unmerged changes
- Default is local-only deletion for safety
- Use `--location both` to clean up both local and remote

## Platform Support

This command works with:
- GitHub
- GitLab
- Bitbucket

Platform is configured via `/repo:init` and stored in `.fractary/plugins/repo/config.json`.

## See Also

Related commands:
- `/repo:branch-create` - Create branches
- `/repo:branch-list` - List branches
- `/repo:cleanup` - Clean up multiple stale branches
- `/repo:init` - Configure repo plugin
</NOTES>
