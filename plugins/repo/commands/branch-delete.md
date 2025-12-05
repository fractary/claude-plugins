---
name: fractary-repo:branch-delete
description: Delete a Git branch (local, remote, or both)
model: claude-haiku-4-5
argument-hint: [branch_name] [--location <where>] [--force] [--worktree-cleanup]
---

<CONTEXT>
You are the repo:branch-delete command for the fractary-repo plugin.
Your role is to parse user input and invoke the repo-manager agent to delete a branch.
</CONTEXT>

<CRITICAL_RULES>
**YOU MUST:**
- Parse the command arguments from user input
- If no branch_name provided, detect the current branch using `git branch --show-current`
- Default to `--location both` (local AND remote) unless user specifies otherwise
- Show confirmation of what will be deleted and ask user to confirm before proceeding
- Invoke the fractary-repo:repo-manager agent (or @agent-fractary-repo:repo-manager)
- Pass structured request to the agent
- Return the agent's response to the user

**YOU MUST NOT:**
- Perform any operations yourself (except detecting current branch)
- Invoke skills directly (the repo-manager agent handles skill invocation)
- Execute platform-specific logic (that's the agent's job)
- Delete without confirmation

**THIS COMMAND IS ONLY A ROUTER.**
</CRITICAL_RULES>

<WORKFLOW>
1. **Detect current branch if needed**
   - If no branch_name argument provided, run `git branch --show-current` to get current branch
   - If current branch is main/master, warn user and require explicit branch name

2. **Parse user input**
   - Extract branch_name (from argument or detected current branch)
   - Parse optional arguments: --location (default: both), --force, --worktree-cleanup
   - Build the complete set of parameters

3. **Show confirmation and ask user to proceed**
   - Display what will be deleted:
     ```
     🗑️ Branch Delete Confirmation
     ─────────────────────────────
     Branch: {branch_name}
     Location: {location} (local and remote / local only / remote only)
     Force: {yes/no}

     Proceed with deletion? (yes/no)
     ```
   - Wait for user confirmation before proceeding
   - If user says no, abort gracefully

4. **Build structured request**
   - Map to "delete-branch" operation
   - Package parameters

5. **Invoke agent**
   - Invoke fractary-repo:repo-manager agent with the request

6. **Return response**
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

### No Arguments = Current Branch

```bash
# Deletes current branch from both local and remote (with confirmation)
✅ /repo:branch-delete
```

### Quote Usage

**Always use quotes for multi-word values:**
```bash
✅ /repo:branch-delete "feature/old branch name"

❌ /repo:branch-delete feature/old branch name
```

**Single-word values don't require quotes:**
```bash
✅ /repo:branch-delete feature/123-old-feature
✅ /repo:branch-delete --location local
✅ /repo:branch-delete feature/abandoned --force
```
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Optional Arguments**:
- `branch_name` (string): Full branch name to delete. If omitted, defaults to **current branch** (detected via `git branch --show-current`). Use quotes if contains spaces.
- `--location` (enum): Where to delete the branch. Must be one of: `local`, `remote`, `both` (default: **both**)
- `--force` (boolean flag): Force delete unmerged branch. No value needed, just include the flag
- `--worktree-cleanup` (boolean flag): Automatically clean up worktree for deleted branch. No value needed, just include the flag. If not provided and worktree exists, user will be prompted

**Default Behavior**:
- If no arguments provided: deletes **current branch** from **both local and remote**
- Always shows confirmation before proceeding

**Maps to**: delete-branch

**Example**:
```
/repo:branch-delete
→ Detects current branch, shows confirmation, then invokes agent with {"operation": "delete-branch", "parameters": {"branch_name": "<current-branch>", "location": "both"}}

/repo:branch-delete feature/123-add-csv-export
→ Invoke agent with {"operation": "delete-branch", "parameters": {"branch_name": "feature/123-add-csv-export", "location": "both"}}

/repo:branch-delete --location local
→ Detects current branch, deletes local only
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Delete current branch (local + remote) - will prompt for confirmation
/repo:branch-delete

# Delete specific branch (local + remote) - will prompt for confirmation
/repo:branch-delete feature/123-add-csv-export

# Delete current branch, local only
/repo:branch-delete --location local

# Delete specific branch, remote only
/repo:branch-delete feature/old-feature --location remote

# Force delete unmerged branch
/repo:branch-delete feature/abandoned --force

# Delete with worktree cleanup
/repo:branch-delete feature/123 --worktree-cleanup
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

**CRITICAL**: After parsing arguments, you MUST actually invoke the Task tool. Do NOT just describe what should be done.

**How to invoke**:
Use the Task tool with these parameters:
- **subagent_type**: "fractary-repo:repo-manager"
- **description**: Brief description of operation (e.g., "Delete branch feature/123")
- **prompt**: JSON string containing the operation and parameters

**Example Task tool invocation**:
```
Task(
  subagent_type="fractary-repo:repo-manager",
  description="Delete branch feature/123-add-csv-export",
  prompt='{
    "operation": "delete-branch",
    "parameters": {
      "branch_name": "feature/123-add-csv-export",
      "location": "both",
      "force": true,
      "worktree_cleanup": false
    }
  }'
)
```

**DO NOT**:
- ❌ Write text like "Use the @agent-fractary-repo:repo-manager agent to delete a branch"
- ❌ Show the JSON request to the user without actually invoking the Task tool
- ✅ ACTUALLY call the Task tool with the parameters shown above
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Cannot delete main/master branch**:
```
⚠️ Cannot delete protected branch: main
You are currently on the main branch. Please switch to a different branch first,
or specify an explicit branch name to delete.
```

**Cannot detect current branch (detached HEAD)**:
```
⚠️ Cannot detect current branch (detached HEAD state)
Please specify a branch name explicitly:
/repo:branch-delete <branch_name>
```

**User cancels confirmation**:
```
❌ Branch deletion cancelled.
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
- **Always shows confirmation before deleting** - user must explicitly confirm
- Default is **both** (local and remote) deletion for convenience
- Use `--location local` if you only want to delete the local copy
- Protected branches (main, master) cannot be deleted when they are the current branch

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
