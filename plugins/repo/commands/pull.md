---
name: fractary-repo:pull
description: Pull branches from remote repository with intelligent conflict handling
argument-hint: [branch_name] [--remote <name>] [--rebase] [--strategy <strategy>]
---

<CONTEXT>
You are the repo:pull command router for the fractary-repo plugin.
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
- This command ONLY pulls branches from remote
- NEVER create commits after pulling
- NEVER push changes after pulling
- NEVER chain other git operations
- User must explicitly run other commands for additional operations

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
   - Parse optional flags (remote, rebase, strategy)
   - Validate arguments

2. **Build structured request**
   - Package parameters for pull operation

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
- **Multi-word values**: MUST be enclosed in quotes (though branch names rarely have spaces)
- **Example**: `--remote origin` ✅
- **Wrong**: `--remote=origin` ❌

### Quote Usage

**Branch names with spaces (rare but possible):**
```bash
✅ /repo:pull "feature/some branch name"
❌ /repo:pull feature/some branch name
```

**Single-word values don't require quotes:**
```bash
✅ /repo:pull feature/123-add-export
✅ /repo:pull main --remote upstream
✅ /repo:pull --rebase
```

**Boolean flags have no value:**
```bash
✅ /repo:pull --rebase
✅ /repo:pull feature/branch --rebase

❌ /repo:pull --rebase true
❌ /repo:pull --rebase=true
```

**Strategy values:**
```bash
✅ /repo:pull --strategy auto-merge-prefer-remote
✅ /repo:pull --strategy rebase
✅ /repo:pull main --strategy manual

❌ /repo:pull --strategy=rebase
```
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

### [branch_name] [--remote <name>] [--rebase] [--strategy <strategy>]
**Purpose**: Pull branch from remote repository with intelligent merge conflict handling

**Optional Arguments**:
- `branch_name` (string): Branch name to pull (default: current branch). Example: "feature/123-add-export"
- `--remote` (string): Remote repository name (default: origin). Examples: "origin", "upstream", "fork"
- `--rebase` (boolean flag): Use rebase instead of merge. No value needed, just include the flag. Shortcut for `--strategy rebase`
- `--strategy` (string): Conflict resolution strategy. Options:
  - `auto-merge-prefer-remote` - Automatically merge, preferring remote changes in conflicts (DEFAULT)
  - `auto-merge-prefer-local` - Automatically merge, preferring local changes in conflicts
  - `rebase` - Rebase local commits onto remote branch
  - `manual` - Fetch and merge without auto-resolution (user handles conflicts)
  - `fail` - Fail if conflicts would occur (safe mode)

**Maps to**: pull-branch

**Example**:
```
/repo:pull feature/123-add-csv-export
→ Invoke agent with {"operation": "pull-branch", "parameters": {"branch_name": "feature/123-add-csv-export"}}
```

**Strategy Examples**:
```
/repo:pull --strategy auto-merge-prefer-remote
→ Uses default strategy (remote changes win in conflicts)

/repo:pull --strategy auto-merge-prefer-local
→ Local changes win in conflicts

/repo:pull --rebase
→ Rebase local commits onto remote

/repo:pull --strategy manual
→ Fetch and merge, but don't auto-resolve conflicts
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Pull current branch
/repo:pull

# Pull specific branch
/repo:pull feature/123-add-csv-export

# Pull with rebase
/repo:pull feature/123-add-csv-export --rebase

# Pull from specific remote
/repo:pull main --remote upstream

# Pull with specific merge strategy (prefer remote)
/repo:pull --strategy auto-merge-prefer-remote

# Pull with specific merge strategy (prefer local)
/repo:pull --strategy auto-merge-prefer-local

# Pull in safe mode (fail on conflicts)
/repo:pull --strategy fail
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
  description="Pull branch from remote",
  prompt='{
    "operation": "pull-branch",
    "parameters": {
      "branch_name": "feature/123-add-export",
      "remote": "origin",
      "strategy": "auto-merge-prefer-remote"
    }
  }'
)
```

**CRITICAL - DO NOT**:
- ❌ Invoke skills directly (branch-puller, etc.) - let the agent route
- ❌ Write declarative text about using the agent - actually invoke it

**The agent will**:
- Validate the request
- Route to branch-puller skill
- Return the skill's response
- You display results to user

**Request structure**:
```json
{
  "operation": "pull-branch",
  "parameters": {
    "branch_name": "branch-name",
    "remote": "origin",
    "rebase": true|false,
    "strategy": "auto-merge-prefer-remote|auto-merge-prefer-local|rebase|manual|fail"
  }
}
```

## Supported Operations

- `pull-branch` - Pull branch from remote with intelligent conflict handling
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Branch not found**:
```
Error: Branch not found: feature/nonexistent
Check branch name: git branch -a
```

**Remote not configured**:
```
Error: Remote not found: upstream
Check remotes: git remote -v
```

**Merge conflicts**:
```
Error: Merge conflicts detected in 3 files
Strategy 'fail' prevents automatic resolution
Resolve manually or use different strategy
```

**No upstream branch**:
```
Error: No upstream branch configured for: feature/123
Set upstream first: git branch --set-upstream-to=origin/feature/123
```
</ERROR_HANDLING>

<NOTES>
## Requirements

**Git Version:**
- Minimum: Git 2.18+ (for merge-tree conflict detection)
- Script will warn if Git version is too old but will continue with degraded functionality
- Older versions: Use `--strategy manual` for safer operation

**Bash Version:**
- Minimum: Bash 4.0+ (for regex input validation)

## Important Behavior Warnings

⚠️ **Auto-Switch Warning:**
The pull command automatically switches to the target branch if you're not already on it.

- **If you have uncommitted changes**: You'll get a 3-second warning with option to abort (Ctrl+C)
- **Uncommitted changes are carried over** to the new branch during the switch
- **Recommendation**: Stash changes first if switching branches: `git stash`

⚠️ **Uncommitted Changes:**
- Uncommitted changes are preserved during pull operations
- They may conflict with pulled changes
- Consider committing or stashing before pulling

## Intelligent Conflict Handling

The pull command includes intelligent merge strategies:
- **auto-merge-prefer-remote**: Remote changes win in conflicts (recommended default)
- **auto-merge-prefer-local**: Local changes win in conflicts
- **rebase**: Rebase local commits onto remote (cleaner history)
- **manual**: User resolves conflicts manually
- **fail**: Abort if conflicts detected (safest)

## Default Behavior

- **Remote**: origin
- **Strategy**: auto-merge-prefer-remote (prefers committed/pushed changes)
- **Branch**: current branch

## Platform Support

This command works with:
- GitHub
- GitLab
- Bitbucket

Platform is configured via `/repo:init` and stored in `.fractary/plugins/repo/config.json`.

## See Also

Related commands:
- `/repo:push` - Push branches to remote
- `/repo:branch` - Manage branches
- `/repo:commit` - Create commits
- `/repo:init` - Configure repo plugin
</NOTES>
