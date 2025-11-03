---
name: fractary-repo:pr-merge
description: Merge a pull request
argument-hint: <pr_number> [--strategy <strategy>] [--delete-branch]
---

<CONTEXT>
You are the repo:pr-merge command for the fractary-repo plugin.
Your role is to parse user input and invoke the repo-manager agent to merge a pull request.
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
- This command ONLY merges the PR
- DO NOT perform post-merge operations
- EXCEPTION: If explicit continuation flags exist (not currently implemented)

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
   - Extract pr_number (required)
   - Parse optional arguments: --strategy, --delete-branch
   - Validate required arguments are present

2. **Build structured request**
   - Map to "merge-pr" operation
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
- **Boolean flags have no value**: `--delete-branch` ✅ (NOT `--delete-branch true`)

### Quote Usage

**Merge strategies are exact keywords:**
- Use exactly: `merge`, `squash`, `rebase`
- NOT: `merge-commit`, `squash-merge`, `rebase-merge`

**Examples:**
```bash
✅ /repo:pr-merge 456
✅ /repo:pr-merge 456 --strategy squash
✅ /repo:pr-merge 456 --strategy squash --delete-branch

❌ /repo:pr-merge 456 --strategy=squash
❌ /repo:pr-merge 456 --delete-branch true
```
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Required Arguments**:
- `pr_number` (number): PR number (e.g., 456, not "#456")

**Optional Arguments**:
- `--strategy` (enum): Merge strategy. Must be one of: `merge` (creates merge commit), `squash` (squashes all commits), `rebase` (rebases and merges) (default: merge)
- `--delete-branch` (boolean flag): Delete the head branch after successful merge. No value needed, just include the flag

**Maps to**: merge-pr

**Example**:
```
/repo:pr-merge 456 --strategy squash --delete-branch
→ Invoke agent with {"operation": "merge-pr", "parameters": {"pr_number": "456", "strategy": "squash", "delete_branch": true}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Merge PR (default strategy)
/repo:pr-merge 456

# Squash and merge
/repo:pr-merge 456 --strategy squash --delete-branch

# Rebase and merge
/repo:pr-merge 456 --strategy rebase

# Merge and delete branch
/repo:pr-merge 456 --delete-branch
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the repo-manager agent using declarative syntax:

**Agent**: fractary-repo:repo-manager (or @agent-fractary-repo:repo-manager)

**Request structure**:
```json
{
  "operation": "merge-pr",
  "parameters": {
    "pr_number": "456",
    "strategy": "squash",
    "delete_branch": true
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

**Missing PR number**:
```
Error: pr_number is required
Usage: /repo:pr-merge <pr_number>
```

**Invalid merge strategy**:
```
Error: Invalid merge strategy: invalid
Valid strategies: merge, squash, rebase
```

**PR not found**:
```
Error: Pull request not found: #999
Verify the PR number and try again
```

**PR not mergeable**:
```
Error: Pull request #456 is not mergeable
Reasons: merge conflicts, required reviews missing, CI checks failing
```
</ERROR_HANDLING>

<NOTES>
## Merge Strategies

- **merge**: Creates merge commit (preserves full history)
- **squash**: Squashes all commits into one
- **rebase**: Rebases and merges (linear history)

## Best Practices

- Ensure CI checks pass before merging
- Get required approvals
- Resolve merge conflicts
- Use `--delete-branch` to keep repository clean
- Choose strategy based on team conventions

## Platform Support

This command works with:
- GitHub (Pull Requests)
- GitLab (Merge Requests)
- Bitbucket (Pull Requests)

Platform is configured via `/repo:init` and stored in `.fractary/plugins/repo/config.json`.

## See Also

Related commands:
- `/repo:pr-create` - Create PRs
- `/repo:pr-review` - Review PRs
- `/repo:pr-comment` - Add comments
- `/repo:branch-delete` - Delete branches manually
- `/repo:init` - Configure repo plugin
</NOTES>
