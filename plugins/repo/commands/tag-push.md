---
name: fractary-repo:tag-push
description: Push tag(s) to remote repository
model: claude-haiku-4-5
argument-hint: <tag_name|all> [--remote <name>]
---

<CONTEXT>
You are the repo:tag-push command for the fractary-repo plugin.
Your role is to parse user input and invoke the repo-manager agent to push tags to remote.
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
   - Extract tag_name or "all" (required)
   - Parse optional argument: --remote
   - Validate required arguments are present

2. **Build structured request**
   - Map to "push-tag" operation
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
- **Single-word values don't require quotes**

### Quote Usage

**Tag names are typically single words:**
```bash
✅ /repo:tag-push v1.0.0
✅ /repo:tag-push all
✅ /repo:tag-push v1.0.0 --remote origin
```

**The keyword "all" pushes all tags:**
```bash
✅ /repo:tag-push all
✅ /repo:tag-push all --remote upstream
```
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Required Arguments**:
- `tag_name` (string or keyword): Tag name to push (e.g., "v1.0.0"), or the literal keyword `all` to push all tags

**Optional Arguments**:
- `--remote` (string): Remote repository name (default: origin). Examples: "origin", "upstream"

**Maps to**: push-tag

**Example**:
```
/repo:tag-push v1.0.0
→ Invoke agent with {"operation": "push-tag", "parameters": {"tag": "v1.0.0"}}
```

**Push all tags example**:
```
/repo:tag-push all
→ Invoke agent with {"operation": "push-tag", "parameters": {"tag": "all"}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Push single tag
/repo:tag-push v1.0.0

# Push all tags
/repo:tag-push all

# Push to specific remote
/repo:tag-push v1.0.0 --remote upstream

# Push all tags to upstream
/repo:tag-push all --remote upstream
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
  "operation": "push-tag",
  "parameters": {
    "tag": "v1.0.0",
    "remote": "origin"
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
Error: tag name or "all" is required
Usage: /repo:tag-push <tag_name|all>
```

**Tag not found**:
```
Error: Tag not found: v99.0.0
List tags: /repo:tag-list
```

**Remote not configured**:
```
Error: Remote not found: upstream
Use /repo:init to configure remotes
```
</ERROR_HANDLING>

<NOTES>
## Push Behavior

- **Single tag**: Pushes only the specified tag
- **All tags**: Pushes all local tags to remote
- **Default remote**: origin (can be overridden with --remote)

## Use Cases

- Release workflow: Create tag, then push it
- Synchronize tags: Push all tags after cloning
- Multi-remote: Push to different remotes (origin, upstream)

## Platform Support

This command works with:
- GitHub (creates GitHub Releases for annotated tags)
- GitLab (creates GitLab Releases)
- Bitbucket

Platform is configured via `/repo:init` and stored in `.fractary/plugins/repo/config.json`.

## See Also

Related commands:
- `/repo:tag-create` - Create tags
- `/repo:tag-list` - List tags
- `/repo:push` - Push branches
- `/repo:init` - Configure repo plugin
</NOTES>
