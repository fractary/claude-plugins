---
name: fractary-repo:commit
description: Create semantic commits with conventional commit format and FABER metadata
argument-hint: '["message"] [--type <type>] [--work-id <id>] [--scope <scope>] [--breaking] [--description "<text>"]'
---

<CONTEXT>
You are the repo:commit command router for the fractary-repo plugin.
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
- This command ONLY creates commits locally
- NEVER push to remote after committing
- NEVER create pull requests after committing
- NEVER chain other git operations
- User must explicitly run /repo:push to push changes
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
   - Extract commit message and options
   - Parse optional flags (type, work-id, scope, breaking, description)
   - Validate arguments

2. **Build structured request**
   - Package parameters for commit operation
   - Create JSON request with operation: "create-commit"

3. **ACTUALLY INVOKE the Task tool**
   - Use the Task tool with subagent_type="fractary-repo:repo-manager"
   - Pass the structured JSON request in the prompt parameter
   - Do NOT just describe what should be done - actually call the Task tool

4. **Return response**
   - The Task tool returns the agent's output
   - Display results to the user
</WORKFLOW>

<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the **space-separated** argument syntax (consistent with work/repo plugin family):
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in quotes
- **Example**: `--description "Optimized database queries"` ✅
- **Wrong**: `--description Optimized database queries` ❌

### Quote Usage

**Always use quotes for multi-word values:**
```bash
✅ /repo:commit "Add CSV export feature" --type feat
✅ /repo:commit "Fix authentication bug" --work-id 123 --scope auth
✅ /repo:commit "Improve performance" --description "Optimized database queries"

❌ /repo:commit Add CSV export feature --type feat
❌ /repo:commit Fix authentication bug --work-id 123
```

**Single-word values don't require quotes:**
```bash
✅ /repo:commit "Add feature" --type feat
✅ /repo:commit "Fix bug" --work-id 123
✅ /repo:commit "Update docs" --scope api
```

**Boolean flags have no value:**
```bash
✅ /repo:commit "Breaking change" --breaking
✅ /repo:commit "Remove old API" --type feat --breaking

❌ /repo:commit "Breaking change" --breaking true
❌ /repo:commit "Remove old API" --breaking=true
```

**Commit types are exact keywords:**
- Use exactly: `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `perf`, `test`
- NOT: `feature`, `bugfix`, `documentation`
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

### [message] [--type <type>] [--work-id <id>] [--scope <scope>] [--breaking] [--description <text>]
**Purpose**: Create semantic commit with conventional commit format

**Optional Arguments**:
- `message` (string): Commit message summary, use quotes if multi-word (if not provided, will be auto-generated)
- `--type` (enum): Commit type following Conventional Commits. Must be one of: `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `perf`, `test` (default: feat)
- `--work-id` (string or number): Associated work item ID for tracking (e.g., "123", "PROJ-456")
- `--scope` (string): Scope/component of changes (e.g., "auth", "api", "ui"). Single word, no quotes needed
- `--breaking` (boolean flag): Mark as breaking change (adds BREAKING CHANGE footer). No value needed, just include the flag
- `--description` (string): Extended commit description/body, use quotes if multi-word

**Maps to**: create-commit

**Example**:
```
/repo:commit "Add CSV export" --type feat --work-id 123
→ Invoke agent with {"operation": "create-commit", "parameters": {"message": "Add CSV export", "type": "feat", "work_id": "123"}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Simple commit
/repo:commit "Fix authentication bug"

# Commit with type and work ID
/repo:commit "Add CSV export feature" --type feat --work-id 123

# Commit with scope
/repo:commit "Update API endpoints" --type refactor --scope api

# Breaking change
/repo:commit "Remove legacy auth" --type feat --breaking

# With extended description
/repo:commit "Improve performance" --type perf --description "Optimized database queries"
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

**CRITICAL**: After parsing arguments, you MUST actually invoke the Task tool. Do NOT just describe what should be done.

**How to invoke**:
Use the Task tool with these parameters:
- **subagent_type**: "fractary-repo:repo-manager"
- **description**: Brief description of operation (e.g., "Create semantic commit")
- **prompt**: JSON string containing the operation and parameters

**Example Task tool invocation**:
```
Task(
  subagent_type="fractary-repo:repo-manager",
  description="Create semantic commit",
  prompt='{
    "operation": "create-commit",
    "parameters": {
      "message": "Add CSV export",
      "type": "feat",
      "work_id": "123",
      "scope": "api",
      "breaking": false,
      "description": "Implements CSV export functionality"
    }
  }'
)
```

**Request structure**:
```json
{
  "operation": "create-commit",
  "parameters": {
    "message": "commit message",
    "type": "feat|fix|chore|docs|style|refactor|perf|test",
    "work_id": "123",
    "scope": "scope",
    "breaking": true|false,
    "description": "extended description"
  }
}
```

**What the agent does**:
1. Receives the request
2. Routes to commit-creator skill
3. Executes platform-specific logic
4. Returns structured response to you
5. You display results to the user

**DO NOT**:
- ❌ Write text like "Use the @agent-fractary-repo:repo-manager agent to create a commit"
- ❌ Show the JSON request to the user without actually invoking the Task tool
- ❌ Invoke skills directly (commit-creator, etc.)
- ✅ ACTUALLY call the Task tool with the parameters shown above

## Supported Operations

- `create-commit` - Create semantic commit with FABER metadata
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Invalid commit type**:
```
Error: Invalid commit type: invalid
Valid types: feat, fix, chore, docs, style, refactor, perf, test
```

**No changes to commit**:
```
Error: No changes staged for commit
Stage changes first: git add <files>
```
</ERROR_HANDLING>

<NOTES>
## Conventional Commits

This command follows the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

## Commit Types

- **feat**: New feature
- **fix**: Bug fix
- **chore**: Maintenance
- **docs**: Documentation
- **style**: Formatting
- **refactor**: Code restructuring
- **perf**: Performance improvement
- **test**: Testing

## FABER Metadata

When used within FABER workflows, commits automatically include FABER metadata and work item references.

## Platform Support

This command works with:
- GitHub
- GitLab
- Bitbucket

Platform is configured via `/repo:init` and stored in `.fractary/plugins/repo/config.json`.

## See Also

For detailed documentation, see: [/docs/commands/repo-commit.md](../../../docs/commands/repo-commit.md)

Related commands:
- `/repo:branch` - Manage branches
- `/repo:push` - Push changes
- `/repo:pr` - Create pull requests
- `/repo:init` - Configure repo plugin
</NOTES>
