---
name: fractary-repo:pr
description: "[DEPRECATED] Create, comment, review, and merge pull requests - Use /repo:pr-create, /repo:pr-comment, /repo:pr-review, or /repo:pr-merge instead"
argument-hint: create <title> [--body <text>] [--base <branch>] [--head <branch>] [--work-id <id>] [--draft] | comment <pr_number> <comment> | review <pr_number> <action> [--comment <text>] | merge <pr_number> [--strategy <strategy>] [--delete-branch]
---

<DEPRECATION_NOTICE>
⚠️ **THIS COMMAND IS DEPRECATED**

This multi-function command has been split into focused single-purpose commands for better usability:

- `/repo:pr-create` - Create a new pull request
- `/repo:pr-comment` - Add a comment to a PR
- `/repo:pr-review` - Review a PR (approve, request changes, comment)
- `/repo:pr-merge` - Merge a pull request

**Why this change?**
- Simpler command structure (no subcommands)
- Shorter argument hints that fit on screen
- Better discoverability through tab completion
- Consistent with Unix philosophy: do one thing well

**Migration:**
- `/repo:pr create "title"` → `/repo:pr-create "title"`
- `/repo:pr comment 456 "text"` → `/repo:pr-comment 456 "text"`
- `/repo:pr review 456 approve` → `/repo:pr-review 456 approve`
- `/repo:pr merge 456` → `/repo:pr-merge 456`

This command will be removed in the next major version. Please update your workflows to use the new single-purpose commands.
</DEPRECATION_NOTICE>

<CONTEXT>
You are the repo:pr command router for the fractary-repo plugin.
Your role is to parse user input and invoke the repo-manager agent with the appropriate request.

**DEPRECATION WARNING:** Before proceeding, inform the user that this command is deprecated and they should use the new single-purpose commands instead (/repo:pr-create, /repo:pr-comment, /repo:pr-review, /repo:pr-merge).
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
   - Extract subcommand (create, comment, review, merge)
   - Parse required and optional arguments
   - Validate required arguments are present

2. **Build structured request**
   - Map subcommand to operation name
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
✅ /repo:pr create "Add CSV export feature" --body "Implements user data export"
✅ /repo:pr comment 456 "Looks good to me!"
✅ /repo:pr review 456 approve --comment "Great work on this feature!"

❌ /repo:pr create Add CSV export feature --body Implements export
❌ /repo:pr comment 456 Looks good to me!
```

**Single-word values don't require quotes:**
```bash
✅ /repo:pr create "Title" --work-id 123
✅ /repo:pr review 456 approve
✅ /repo:pr merge 456 --strategy squash
```

**Boolean flags have no value:**
```bash
✅ /repo:pr create "WIP: Feature" --draft
✅ /repo:pr merge 456 --delete-branch

❌ /repo:pr create "WIP: Feature" --draft true
❌ /repo:pr merge 456 --delete-branch=true
```

**Review actions are exact keywords:**
- Use exactly: `approve`, `request_changes`, `comment`
- NOT: `approved`, `request-changes`, `add-comment`

**Merge strategies are exact keywords:**
- Use exactly: `merge`, `squash`, `rebase`
- NOT: `merge-commit`, `squash-merge`, `rebase-merge`
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Subcommands

### create <title> [--body <text>] [--base <branch>] [--head <branch>] [--work-id <id>] [--draft]
**Purpose**: Create a new pull request

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
/repo:pr create "Add CSV export feature" --work-id 123 --body "Implements CSV export functionality"
→ Invoke agent with {"operation": "create-pr", "parameters": {"title": "Add CSV export feature", "work_id": "123", "body": "Implements CSV export functionality"}}
```

### comment <pr_number> <comment>
**Purpose**: Add a comment to a pull request

**Required Arguments**:
- `pr_number` (number): PR number (e.g., 456, not "#456")
- `comment` (string): Comment text, use quotes if multi-word (e.g., "Looks great! Approving now.")

**Maps to**: comment-pr

**Example**:
```
/repo:pr comment 456 "LGTM! Approving."
→ Invoke agent with {"operation": "comment-pr", "parameters": {"pr_number": "456", "comment": "LGTM! Approving."}}
```

### review <pr_number> <action> [--comment <text>]
**Purpose**: Review a pull request

**Required Arguments**:
- `pr_number` (number): PR number (e.g., 456, not "#456")
- `action` (enum): Review action. Must be one of: `approve`, `request_changes`, `comment`

**Optional Arguments**:
- `--comment` (string): Review comment/feedback, use quotes if multi-word (e.g., "Please add tests for edge cases")

**Maps to**: review-pr

**Example**:
```
/repo:pr review 456 approve --comment "Great work!"
→ Invoke agent with {"operation": "review-pr", "parameters": {"pr_number": "456", "action": "approve", "comment": "Great work!"}}
```

### merge <pr_number> [--strategy <strategy>] [--delete-branch]
**Purpose**: Merge a pull request

**Required Arguments**:
- `pr_number` (number): PR number (e.g., 456, not "#456")

**Optional Arguments**:
- `--strategy` (enum): Merge strategy. Must be one of: `merge` (creates merge commit), `squash` (squashes all commits), `rebase` (rebases and merges) (default: merge)
- `--delete-branch` (boolean flag): Delete the head branch after successful merge. No value needed, just include the flag

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

**The agent will**:
- Validate the request
- Route to pr-manager skill
- Return the skill's response
- You display results to user

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
