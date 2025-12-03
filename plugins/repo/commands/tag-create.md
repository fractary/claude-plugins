---
name: fractary-repo:tag-create
description: Create a new Git tag
model: claude-haiku-4-5
argument-hint: '<tag_name> [--message "<text>"] [--commit <sha>] [--sign] [--force]'
---

<CONTEXT>
You are the repo:tag-create command for the fractary-repo plugin.
Your role is to parse user input and invoke the repo-manager agent to create a tag.
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
   - Extract tag_name (required)
   - Parse optional arguments: --message, --commit, --sign, --force
   - Validate required arguments are present

2. **Build structured request**
   - Map to "create-tag" operation
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
- **Boolean flags have no value**: `--sign` ✅ (NOT `--sign true`)

### Quote Usage

**Always use quotes for multi-word values:**
```bash
✅ /repo:tag-create v1.0.0 --message "Release version 1.0.0"
✅ /repo:tag-create v1.0.0 --message "Major release with breaking changes"

❌ /repo:tag-create v1.0.0 --message Release version 1.0.0
```

**Single-word values don't require quotes:**
```bash
✅ /repo:tag-create v1.0.0
✅ /repo:tag-create v1.0.0 --commit abc123
```

**Boolean flags have no value:**
```bash
✅ /repo:tag-create v1.0.0 --sign
✅ /repo:tag-create v1.0.0 --force

❌ /repo:tag-create v1.0.0 --sign true
```

**Tag naming conventions:**
- Use semantic versioning: `v1.0.0`, `v2.1.3`, `v0.9.0-beta`
- Tags are typically single words (no quotes needed)
- Example: `v1.0.0`, `v2.0.0-rc1`, `release-2024`
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

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
/repo:tag-create v1.0.0 --message "Release version 1.0.0"
→ Invoke agent with {"operation": "create-tag", "parameters": {"tag_name": "v1.0.0", "message": "Release version 1.0.0"}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Create tag
/repo:tag-create v1.0.0

# Create with message
/repo:tag-create v1.0.0 --message "Release version 1.0.0"

# Create signed tag
/repo:tag-create v1.0.0 --message "Signed release" --sign

# Tag specific commit
/repo:tag-create v0.9.0 --commit abc123

# Force update existing tag
/repo:tag-create v1.0.0 --message "Updated release" --force
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
  "operation": "create-tag",
  "parameters": {
    "tag_name": "v1.0.0",
    "message": "Release version 1.0.0",
    "commit": "abc123",
    "sign": true,
    "force": false
  }
}
```

The repo-manager agent will:
1. Receive the request
2. Route to appropriate skill based on operation
3. Execute platform-specific logic (GitHub/GitLab/Bitbucket)
4. Return structured response

**DO NOT**:
- ❌ Write text like "Use the @agent-fractary-repo:repo-manager agent"
- ❌ Show the JSON request to the user without actually invoking the Task tool
- ✅ ACTUALLY call the Task tool with the parameters shown above
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing tag name**:
```
Error: tag_name is required
Usage: /repo:tag-create <tag_name>
```

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

Related commands:
- `/repo:tag-push` - Push tags to remote
- `/repo:tag-list` - List tags
- `/repo:commit` - Create commits
- `/repo:init` - Configure repo plugin
</NOTES>
