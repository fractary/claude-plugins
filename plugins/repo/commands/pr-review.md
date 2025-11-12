---
name: fractary-repo:pr-review
description: Analyze or review a pull request (default: analyze if no action provided)
argument-hint: '<pr_number> [action] [--comment "<text>"]'
---

<CONTEXT>
You are the repo:pr-review command for the fractary-repo plugin.
Your role is to parse user input and invoke the repo-manager agent to review a pull request.
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
   - Extract action (optional): analyze (default), approve, request_changes, or comment
   - Parse optional argument: --comment
   - If no action provided, default to "analyze" mode

2. **Determine operation mode**
   - If action is "analyze" (or not provided): Map to "analyze-pr" operation
   - Otherwise: Map to "review-pr" operation

3. **Build structured request**
   - Package parameters based on operation mode

4. **Invoke agent**
   - Invoke fractary-repo:repo-manager agent with the request

5. **Handle response**
   - For analyze mode: Present PR analysis, review status, and recommended options
   - For review mode: Confirm review submission
   - Display results to the user
</WORKFLOW>

<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the **space-separated** argument syntax (consistent with work/repo plugin family):
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in quotes
- **Example**: `--comment "Great work on this feature!"` ✅
- **Wrong**: `--comment Great work on this feature!` ❌

### Quote Usage

**Always use quotes for multi-word comments:**
```bash
✅ /repo:pr-review 456 approve --comment "Great work on this feature!"
✅ /repo:pr-review 456 request_changes --comment "Please add tests"

❌ /repo:pr-review 456 approve --comment Great work on this feature!
```

**Review actions are exact keywords:**
- Use exactly: `analyze` (default), `approve`, `request_changes`, `comment`
- NOT: `approved`, `request-changes`, `add-comment`, `review`

**Examples:**
```bash
✅ /repo:pr-review 456
✅ /repo:pr-review 456 analyze
✅ /repo:pr-review 456 approve
✅ /repo:pr-review 456 request_changes --comment "Add tests"
✅ /repo:pr-review 456 comment --comment "Nice refactoring"
```
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Required Arguments**:
- `pr_number` (number): PR number (e.g., 456, not "#456")

**Optional Arguments**:
- `action` (enum): Action to perform. One of: `analyze` (default), `approve`, `request_changes`, `comment`
- `--comment` (string): Review comment/feedback, use quotes if multi-word (e.g., "Please add tests for edge cases")

**Maps to**: analyze-pr (when action is analyze or not provided) or review-pr (when action is approve/request_changes/comment)

**Examples**:
```
/repo:pr-review 456
→ Invoke agent with {"operation": "analyze-pr", "parameters": {"pr_number": "456"}}

/repo:pr-review 456 analyze
→ Invoke agent with {"operation": "analyze-pr", "parameters": {"pr_number": "456"}}

/repo:pr-review 456 approve --comment "Great work!"
→ Invoke agent with {"operation": "review-pr", "parameters": {"pr_number": "456", "action": "approve", "comment": "Great work!"}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Analyze PR (default - provides recommendation and options)
/repo:pr-review 456

# Explicitly analyze PR
/repo:pr-review 456 analyze

# Approve PR
/repo:pr-review 456 approve --comment "LGTM!"

# Approve without comment
/repo:pr-review 456 approve

# Request changes
/repo:pr-review 456 request_changes --comment "Please add tests"

# Add review comment
/repo:pr-review 456 comment --comment "Nice refactoring here"
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the repo-manager agent using declarative syntax:

**Agent**: fractary-repo:repo-manager (or @agent-fractary-repo:repo-manager)

**Request structure**:
```json
{
  "operation": "review-pr",
  "parameters": {
    "pr_number": "456",
    "action": "approve",
    "comment": "Great work!"
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
Usage: /repo:pr-review <pr_number> [action]
```

**Invalid action**:
```
Error: Invalid action: approved
Valid actions: analyze (default), approve, request_changes, comment
```

**PR not found**:
```
Error: Pull request not found: #999
Verify the PR number and try again
```
</ERROR_HANDLING>

<NOTES>
## Review Actions

- **analyze** (default): Analyze the PR, fetch comments/reviews, and provide recommendations
- **approve**: Approve the PR (ready to merge)
- **request_changes**: Request changes before approval
- **comment**: Add review comment without approval/rejection

## Comment vs Review

- **Comment** (`/repo:pr-comment`): General comment on the PR
- **Review** (this command): Formal review with approve/request changes/comment

## Platform Support

This command works with:
- GitHub (Pull Requests)
- GitLab (Merge Requests)
- Bitbucket (Pull Requests)

Platform is configured via `/repo:init` and stored in `.fractary/plugins/repo/config.json`.

## See Also

Related commands:
- `/repo:pr-create` - Create PRs
- `/repo:pr-comment` - Add general comments
- `/repo:pr-merge` - Merge PRs
- `/repo:init` - Configure repo plugin
</NOTES>
