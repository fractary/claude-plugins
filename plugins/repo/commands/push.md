---
name: fractary-repo:push
description: Push branches to remote repository with safety checks
argument-hint: [branch_name] [--remote <name>] [--set-upstream] [--force]
---

<CONTEXT>
You are the repo:push command router for the fractary-repo plugin.
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

**COMMAND ISOLATION:**
- This command ONLY pushes branches to remote
- NEVER create pull requests after pushing
- NEVER commit changes before pushing
- NEVER chain other git operations
- User must explicitly run /repo:pr create to open pull requests
- EXCEPTION: If explicit --create-pr flag provided (not currently implemented)

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
   - Extract branch name and options
   - Parse optional flags (remote, set-upstream, force)
   - Validate arguments

2. **Build structured request**
   - Package parameters for push operation

3. **Invoke agent**
   - Invoke fractary-repo:repo-manager agent with the request

4. **Return response**
   - The repo-manager agent will handle the operation and return results
   - Display results to the user
</WORKFLOW>

<ARGUMENT_PARSING>
## Arguments

### [branch_name] [--remote <name>] [--set-upstream] [--force]
**Purpose**: Push branch to remote repository

**Optional Arguments**:
- `branch_name`: Branch to push (default: current branch)
- `--remote`: Remote name (default: origin)
- `--set-upstream`: Set upstream tracking
- `--force`: Force push (use with caution)

**Maps to**: push-branch

**Example**:
```
/repo:push feature/123-add-csv-export --set-upstream
→ Invoke agent with {"operation": "push-branch", "parameters": {"branch": "feature/123-add-csv-export", "set_upstream": true}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Push current branch
/repo:push

# Push specific branch
/repo:push feature/123-add-csv-export

# Push and set upstream
/repo:push feature/123-add-csv-export --set-upstream

# Push to specific remote
/repo:push main --remote upstream

# Force push (use carefully!)
/repo:push feature/rebased-branch --force
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the repo-manager agent using declarative syntax.

**Agent**: @agent-fractary-repo:repo-manager

**How to invoke**:
State the action and agent in natural language:

```
Push the branch using the @agent-fractary-repo:repo-manager agent with the following request:
{
  "operation": "push-branch",
  "parameters": {
    "branch": "feature/123-add-export",
    "remote": "origin",
    "set_upstream": true
  }
}
```

The plugin system routes declarative agent references automatically.

**CRITICAL - DO NOT**:
- ❌ Use Skill tool to invoke agents
- ❌ Use Task tool to invoke agents
- ❌ Invoke skills directly (branch-pusher, etc.) - let the agent route

**The agent will**:
- Validate the request
- Route to branch-pusher skill
- Return the skill's response
- You display results to user

**Request structure**:
```json
{
  "operation": "push-branch",
  "parameters": {
    "branch": "branch-name",
    "remote": "origin",
    "set_upstream": true|false,
    "force": true|false
  }
}
```

## Supported Operations

- `push-branch` - Push branch to remote with safety checks
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Branch not found**:
```
Error: Branch not found: feature/nonexistent
Check branch name: git branch -a
```

**No upstream configured**:
```
Error: No upstream branch configured
Use --set-upstream to configure: /repo:push --set-upstream
```

**Force push to protected branch**:
```
Error: Cannot force push to protected branch: main
Force push is blocked for safety
```
</ERROR_HANDLING>

<NOTES>
## Safety Checks

The push command includes safety checks:
- Warns before force pushing
- Blocks force push to main/master
- Checks if branch has upstream tracking
- Validates remote exists

## Platform Support

This command works with:
- GitHub
- GitLab
- Bitbucket

Platform is configured via `/repo:init` and stored in `.fractary/plugins/repo/config.json`.

## See Also

For detailed documentation, see: [/docs/commands/repo-push.md](../../../docs/commands/repo-push.md)

Related commands:
- `/repo:branch` - Manage branches
- `/repo:commit` - Create commits
- `/repo:pr` - Create pull requests
- `/repo:init` - Configure repo plugin
</NOTES>
