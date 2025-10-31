---
name: fractary-repo:pr
description: Create, comment, review, and merge pull requests
argument-hint: create <title> [--body <text>] [--base <branch>] [--head <branch>] [--work-id <id>] [--draft] | comment <pr_number> <comment> | review <pr_number> <action> [--comment <text>] | merge <pr_number> [--strategy <strategy>] [--delete-branch]
---

<CONTEXT>
You are the repo:pr command router for the fractary-repo plugin.
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
- This command ONLY manages pull requests (create, comment, review, merge)
- NEVER push branches before creating PR (assume already pushed)
- NEVER commit changes before creating PR
- NEVER chain other git operations
- For create: User must have already pushed branch with /repo:push
- For merge: ONLY merge the PR, do not perform post-merge operations
- EXCEPTION: If explicit continuation flags exist (not currently implemented)

**THIS COMMAND IS ONLY A ROUTER.**
</CRITICAL_RULES>

<WORKFLOW>
1. **Parse user input**
   - Extract subcommand (create, comment, review, merge)
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

### create <title> [--body <text>] [--base <branch>] [--head <branch>] [--work-id <id>] [--draft]
**Purpose**: Create a new pull request

**Required Arguments**:
- `title`: PR title

**Optional Arguments**:
- `--body`: PR description
- `--base`: Base branch (default: main/master)
- `--head`: Head branch (default: current branch)
- `--work-id`: Associated work item ID
- `--draft`: Create as draft PR

**Maps to**: create-pr

**Example**:
```
/repo:pr create "Add CSV export feature" --work-id 123 --body "Implements CSV export functionality"
→ Invoke agent with {"operation": "create-pr", "parameters": {"title": "Add CSV export feature", "work_id": "123", "body": "Implements CSV export functionality"}}
```

### comment <pr_number> <comment>
**Purpose**: Add a comment to a pull request

**Required Arguments**:
- `pr_number`: PR number
- `comment`: Comment text

**Maps to**: comment-pr

**Example**:
```
/repo:pr comment 456 "LGTM! Approving."
→ Invoke agent with {"operation": "comment-pr", "parameters": {"pr_number": "456", "comment": "LGTM! Approving."}}
```

### review <pr_number> <action> [--comment <text>]
**Purpose**: Review a pull request

**Required Arguments**:
- `pr_number`: PR number
- `action`: Review action (approve|request_changes|comment)

**Optional Arguments**:
- `--comment`: Review comment

**Maps to**: review-pr

**Example**:
```
/repo:pr review 456 approve --comment "Great work!"
→ Invoke agent with {"operation": "review-pr", "parameters": {"pr_number": "456", "action": "approve", "comment": "Great work!"}}
```

### merge <pr_number> [--strategy <strategy>] [--delete-branch]
**Purpose**: Merge a pull request

**Required Arguments**:
- `pr_number`: PR number

**Optional Arguments**:
- `--strategy`: Merge strategy (merge|squash|rebase, default: merge)
- `--delete-branch`: Delete branch after merge

**Maps to**: merge-pr

**Example**:
```
/repo:pr merge 456 --strategy squash --delete-branch
→ Invoke agent with {"operation": "merge-pr", "parameters": {"pr_number": "456", "strategy": "squash", "delete_branch": true}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Create PR
/repo:pr create "Add CSV export feature" --work-id 123

# Create draft PR
/repo:pr create "WIP: Refactor auth module" --draft

# Create with custom base
/repo:pr create "Hotfix: Fix login bug" --base main --head hotfix/urgent-fix

# Add comment
/repo:pr comment 456 "Tested locally - works great!"

# Approve PR
/repo:pr review 456 approve --comment "LGTM!"

# Request changes
/repo:pr review 456 request_changes --comment "Please add tests"

# Merge PR
/repo:pr merge 456

# Squash and merge
/repo:pr merge 456 --strategy squash --delete-branch
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

- `create-pr` - Create new pull request
- `comment-pr` - Add comment to PR
- `review-pr` - Review pull request
- `merge-pr` - Merge pull request
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing title**:
```
Error: title is required
Usage: /repo:pr create <title>
```

**PR not found**:
```
Error: Pull request not found: #999
Verify the PR number and try again
```

**Invalid merge strategy**:
```
Error: Invalid merge strategy: invalid
Valid strategies: merge, squash, rebase
```
</ERROR_HANDLING>

<NOTES>
## Pull Request Best Practices

- Use descriptive titles
- Include work item ID for tracking
- Provide clear description of changes
- Link related issues
- Request reviews from relevant team members

## Merge Strategies

- **merge**: Creates merge commit (preserves full history)
- **squash**: Squashes all commits into one
- **rebase**: Rebases and merges (linear history)

## Platform Support

This command works with:
- GitHub (Pull Requests)
- GitLab (Merge Requests)
- Bitbucket (Pull Requests)

Platform is configured via `/repo:init` and stored in `.fractary/plugins/repo/config.json`.

## See Also

For detailed documentation, see: [/docs/commands/repo-pr.md](../../../docs/commands/repo-pr.md)

Related commands:
- `/repo:branch` - Manage branches
- `/repo:commit` - Create commits
- `/repo:push` - Push changes
- `/repo:init` - Configure repo plugin
</NOTES>
