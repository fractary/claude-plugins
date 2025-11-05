# Agent Requirements Gathering Workflow

This workflow defines how to gather requirements for creating a new agent.

## Required Information

1. **Agent Name** - Identifier (kebab-case)
2. **Agent Type** - "manager" or "handler"
3. **Description** - Brief purpose statement
4. **Responsibility** - Primary responsibility (1-2 sentences)
5. **Tools** - Claude Code tools to use
6. **Plugin Name** - Target plugin location

## Optional Information

7. **Skills to Invoke** - List of skills this agent will use
8. **Agents to Invoke** - Other agents this agent will call
9. **Domain Context** - Domain-specific information
10. **Critical Rules** - Additional rules beyond defaults

## Gathering Process

### 1. Check Provided Parameters

Check which parameters were already provided in `provided_params`:
- If `agent_name` is provided: Use it (already validated by command)
- If `agent_type` is provided: Validate it's "manager" or "handler"
- If `description` is provided: Use it
- If `tools` is provided: Use it, otherwise default to "Bash, Skill"
- If `plugin_name` is provided: Validate plugin exists

### 2. Prompt for Missing Required Information

#### Agent Type (if not provided)

```
Please specify the agent type:

  1. manager - Owns complete domain workflow (most common)
     Example: workflow-manager, data-analyzer

  2. handler - Multi-provider adapter for abstraction
     Example: handler-iac-terraform, handler-hosting-aws

Enter type (manager/handler):
```

**Validation:**
- Must be exactly "manager" or "handler"
- Case-insensitive, but normalize to lowercase

#### Description (if not provided)

```
Please provide a brief description of the agent:

This description will appear in the frontmatter and documentation.

Examples:
  • "Orchestrates complete FABER workflows"
  • "Manages data analysis pipelines"
  • "Handles Terraform infrastructure operations"

Enter description:
```

**Validation:**
- Not empty
- Between 10-200 characters
- Starts with capital letter
- Clear and specific

#### Responsibility (always prompt)

```
What is the primary responsibility of this agent?

This is a 1-2 sentence statement of what the agent does.

Examples:
  • "orchestrating complete FABER workflows from Frame through Release"
  • "managing data analysis workflows including fetch, clean, analyze, and report"
  • "executing Terraform operations for infrastructure provisioning"

Enter responsibility:
```

**Validation:**
- Not empty
- Starts with lowercase (will be inserted after "responsible for")
- Ends without period (formatting handled by template)

### 3. Prompt for Plugin Name (if not provided)

```
Which plugin should this agent be added to?

Detected plugins in this repository:
  • faber
  • faber-app
  • faber-cloud
  • work
  • repo
  • file
  [list all plugins found in plugins/ directory]

Enter plugin name (or press Enter to detect from current directory):
```

**Validation:**
- Plugin directory must exist in `plugins/`
- If empty, detect from current working directory
- Agent will be created in `plugins/{plugin_name}/agents/{agent_name}.md`

### 4. Prompt for Tools (if not provided)

```
Which Claude Code tools should this agent use?

Common combinations:
  • "Bash, Skill" - Standard for most agents (invoke skills, run scripts)
  • "Bash, Skill, SlashCommand" - For directors/orchestrators
  • "Bash" - For simple agents without skill delegation
  • "Read, Write, Edit" - For file-focused agents

Enter tools (comma-separated) or press Enter for default [Bash, Skill]:
```

**Validation:**
- If empty, use default: "Bash, Skill"
- Valid tools: Bash, Skill, SlashCommand, Read, Write, Edit, WebFetch, Grep, Glob
- Comma-separated list
- Trim whitespace

### 5. Prompt for Optional Information

#### Skills to Invoke (optional)

```
What skills will this agent invoke? (Optional)

List the skills this agent will delegate work to.

Examples:
  • "data-fetcher, data-cleaner, data-analyzer"
  • "frame, architect, build, evaluate, release"
  • Leave empty if not yet determined

Enter skills (comma-separated) or press Enter to skip:
```

#### Agents to Invoke (optional)

```
What other agents will this agent invoke? (Optional)

List any other agents this agent coordinates with.

Examples:
  • "work-manager, repo-manager"
  • "terraform-handler, aws-handler"
  • Leave empty if not yet determined

Enter agents (comma-separated) or press Enter to skip:
```

#### Domain Context (optional)

```
Any domain-specific context for this agent? (Optional)

Examples:
  • "Works with data analysis domain"
  • "Handles cloud infrastructure provisioning"
  • "Manages content creation workflows"

Enter context or press Enter to skip:
```

### 6. Confirm Requirements

Display collected requirements and confirm:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Agent Requirements Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Name: {agent_name}
Type: {agent_type}
Description: {description}
Responsibility: {responsibility}
Tools: {tools}
Plugin: {plugin_name}
Location: plugins/{plugin_name}/agents/{agent_name}.md

Optional:
  Skills: {skills_list or "Not specified"}
  Agents: {agents_list or "Not specified"}
  Context: {context or "Not specified"}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Proceed with agent creation? (y/n):
```

**Validation:**
- Require explicit "y" or "yes" to proceed
- "n" or "no" cancels gracefully
- Any other input prompts again

## Return Structure

After confirmation, return:

```json
{
  "status": "success",
  "artifact_type": "agent",
  "requirements": {
    "name": "{agent_name}",
    "type": "{agent_type}",
    "description": "{description}",
    "responsibility": "{responsibility}",
    "tools": "{tools}",
    "plugin_name": "{plugin_name}",
    "output_path": "plugins/{plugin_name}/agents/{agent_name}.md",
    "skills_to_invoke": "{skills_list}",
    "agents_to_invoke": "{agents_list}",
    "domain_context": "{context}"
  }
}
```

## Error Handling

**User Cancels:**
Return `{"status": "cancelled", "message": "Agent creation cancelled by user"}`

**Invalid Input:**
- Re-prompt up to 3 times
- After 3 failures, return error with validation message

**Plugin Not Found:**
Return `{"status": "error", "error": "Plugin not found: {plugin_name}", "step": "plugin_validation"}`

## Validation Rules

### Agent Name
- Lowercase letters, numbers, hyphens only
- Must start with letter
- No consecutive hyphens
- 3-50 characters
- Examples: "data-analyzer", "workflow-manager", "api-client"

### Agent Type
- Exactly "manager" or "handler"
- Case-insensitive input, normalized to lowercase

### Description
- 10-200 characters
- Starts with capital letter
- No newlines
- Clear and specific

### Responsibility
- Non-empty
- Starts with lowercase
- Describes action (verb phrase)
- 20-300 characters

### Tools
- From valid tool list: Bash, Skill, SlashCommand, Read, Write, Edit, WebFetch, Grep, Glob
- Comma-separated
- At least one tool required

### Plugin Name
- Must match existing plugin directory in `plugins/`
- Lowercase with hyphens
- Examples: "faber", "faber-cloud", "work"

This workflow ensures all necessary information is collected before agent generation begins.
