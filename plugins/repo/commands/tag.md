---
name: fractary-repo:tag
description: "[DEPRECATED] Create and push semantic version tags - Use /repo:tag-create, /repo:tag-push, or /repo:tag-list instead"
argument-hint: create <tag_name> [--message <text>] [--commit <sha>] [--sign] [--force] | push <tag_name|all> [--remote <name>] | list [--pattern <pattern>] [--latest <n>]
---

<DEPRECATION_NOTICE>
⚠️ **THIS COMMAND IS DEPRECATED**

This multi-function command has been split into focused single-purpose commands for better usability:

- `/repo:tag-create` - Create a new Git tag
- `/repo:tag-push` - Push tag(s) to remote
- `/repo:tag-list` - List tags with filtering

**Why this change?**
- Simpler command structure (no subcommands)
- Shorter argument hints that fit on screen
- Better discoverability through tab completion
- Consistent with Unix philosophy: do one thing well

**Migration:**
- `/repo:tag create v1.0.0` → `/repo:tag-create v1.0.0`
- `/repo:tag push v1.0.0` → `/repo:tag-push v1.0.0`
- `/repo:tag list --latest 10` → `/repo:tag-list --latest 10`

This command will be removed in the next major version. Please update your workflows to use the new single-purpose commands.
</DEPRECATION_NOTICE>

<CONTEXT>
You are the repo:tag command router for the fractary-repo plugin.
Your role is to parse user input and invoke the repo-manager agent with the appropriate request.

**DEPRECATION WARNING:** Before proceeding, inform the user that this command is deprecated and they should use the new single-purpose commands instead (/repo:tag-create, /repo:tag-push, /repo:tag-list).
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
   - Extract subcommand (create, push, list)
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

<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the **space-separated** argument syntax (consistent with work/repo plugin family):
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in quotes
- **Example**: `--message "Release version 1.0.0"` ✅
- **Wrong**: `--message Release version 1.0.0` ❌

### Quote Usage

**Always use quotes for multi-word values:**
```bash
✅ /repo:tag create v1.0.0 --message "Release version 1.0.0"
✅ /repo:tag create v1.0.0 --message "Major release with breaking changes"

❌ /repo:tag create v1.0.0 --message Release version 1.0.0
```

**Single-word values don't require quotes:**
```bash
✅ /repo:tag create v1.0.0
✅ /repo:tag push v1.0.0
✅ /repo:tag list --latest 10
```

**Boolean flags have no value:**
```bash
✅ /repo:tag create v1.0.0 --sign
✅ /repo:tag create v1.0.0 --force

❌ /repo:tag create v1.0.0 --sign true
❌ /repo:tag create v1.0.0 --force=true
```

**Tag naming conventions:**
- Use semantic versioning: `v1.0.0`, `v2.1.3`, `v0.9.0-beta`
- Tags are typically single words (no quotes needed)
- Example: `v1.0.0`, `v2.0.0-rc1`, `release-2024`
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Subcommands

### create <tag_name> [--message <text>] [--commit <sha>] [--sign] [--force]
**Purpose**: Create a new Git tag

**Required Arguments**:
- `tag_name` (string): Tag name following semantic versioning (e.g., "v1.0.0", "v2.1.3", "v0.9.0-beta")

**Optional Arguments**:
- `--message` (string): Tag annotation message, use quotes if multi-word (e.g., "Release version 1.0.0"). Creates an annotated tag (recommended for releases)
- `--commit` (string): Commit SHA to tag (default: HEAD). Example: "abc123def" or full SHA
- `--sign` (boolean flag): GPG sign the tag for verification. No value needed, just include the flag. Requires GPG key configured
- `--force` (boolean flag): Force create/update existing tag. No value needed, just include the flag. Use with caution

**Maps to**: create-tag

**Example**:
```
/repo:tag create v1.0.0 --message "Release version 1.0.0"
→ Invoke agent with {"operation": "create-tag", "parameters": {"tag_name": "v1.0.0", "message": "Release version 1.0.0"}}
```

### push <tag_name|all> [--remote <name>]
**Purpose**: Push tag(s) to remote

**Required Arguments**:
- `tag_name` (string or keyword): Tag name to push (e.g., "v1.0.0"), or the literal keyword `all` to push all tags

**Optional Arguments**:
- `--remote` (string): Remote repository name (default: origin). Examples: "origin", "upstream"

**Maps to**: push-tag

**Example**:
```
/repo:tag push v1.0.0
→ Invoke agent with {"operation": "push-tag", "parameters": {"tag": "v1.0.0"}}
```

### list [--pattern <pattern>] [--latest <n>]
**Purpose**: List tags

**Optional Arguments**:
- `--pattern` (string): Glob pattern to filter tags (e.g., "v1.*" for all v1.x.x tags, "v2.0.*" for v2.0.x)
- `--latest` (number): Show only the latest N tags (e.g., `--latest 10` for 10 most recent tags)

**Maps to**: list-tags

**Example**:
```
/repo:tag list --latest 10
→ Invoke agent with {"operation": "list-tags", "parameters": {"latest": 10}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Create tag
/repo:tag create v1.0.0

# Create with message
/repo:tag create v1.0.0 --message "Release version 1.0.0"

# Create signed tag
/repo:tag create v1.0.0 --message "Signed release" --sign

# Tag specific commit
/repo:tag create v0.9.0 --commit abc123

# Push tag
/repo:tag push v1.0.0

# Push all tags
/repo:tag push all

# List all tags
/repo:tag list

# List latest 5 tags
/repo:tag list --latest 5

# List tags matching pattern
/repo:tag list --pattern "v1.*"
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

**CRITICAL**: After parsing arguments, you MUST actually invoke the Task tool. Do NOT just describe what should be done.

**How to invoke**:
Use the Task tool with these parameters:
- **subagent_type**: "fractary-repo:repo-manager"
- **description**: Brief description of operation
- **prompt**: JSON string containing the operation and parameters

**Example Task tool invocation** (customize based on the specific operation):

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

- `create-tag` - Create new tag
- `push-tag` - Push tag to remote
- `list-tags` - List tags with filtering

**DO NOT**:
- ❌ Write text like "Use the @agent-fractary-repo:repo-manager agent"
- ❌ Show the JSON request to the user without actually invoking the Task tool
- ✅ ACTUALLY call the Task tool with the parameters shown above
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Tag already exists**:
```
Error: Tag already exists: v1.0.0
Use --force to update existing tag
```

**Invalid tag name**:
```
Error: Invalid tag name: invalid_tag
Use semantic versioning: v1.0.0, v2.1.3, etc.
```

**Tag not found**:
```
Error: Tag not found: v99.0.0
List tags: /repo:tag list
```
</ERROR_HANDLING>

<NOTES>
## Semantic Versioning

Tags should follow semantic versioning (semver):
- `v1.0.0` - Major release
- `v1.1.0` - Minor release
- `v1.0.1` - Patch release

## Tag Types

- **Lightweight tags**: Simple pointer to commit
- **Annotated tags**: Full tag object with message, tagger, date (recommended for releases)
- **Signed tags**: Annotated tags with GPG signature

## Platform Support

This command works with:
- GitHub (creates GitHub Releases for annotated tags)
- GitLab (creates GitLab Releases)
- Bitbucket

Platform is configured via `/repo:init` and stored in `.fractary/plugins/repo/config.json`.

## See Also

For detailed documentation, see: [/docs/commands/repo-tag.md](../../../docs/commands/repo-tag.md)

Related commands:
- `/repo:commit` - Create commits
- `/repo:push` - Push branches
- `/repo:pr` - Create pull requests
- `/repo:init` - Configure repo plugin
</NOTES>
