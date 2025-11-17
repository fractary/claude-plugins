# Command Requirements Gathering Workflow

This workflow defines how to gather requirements for creating a new command.

## Required Information

1. **Command Name** - Identifier (kebab-case)
2. **Agent to Invoke** - Which agent this command will route to
3. **Description** - Brief purpose statement
4. **Plugin Name** - Target plugin location
5. **Argument Hint** - Usage pattern for arguments

## Optional Information

6. **Example Arguments** - Sample command invocations
7. **Error Messages** - Common errors and how to handle them

## Gathering Process

### 1. Check Provided Parameters

Check which parameters were already provided in `provided_params`:
- If `command_name` is provided: Use it (already validated by command)
- If `agent_name` is provided: Use it (required parameter)
- If `description` is provided: Use it
- If `plugin_name` is provided: Validate plugin exists
- If `argument_hint` is provided: Use it

### 2. Verify Agent Name (Required)

Agent name must be provided (commands must invoke an agent):

```
Agent to invoke: {agent_name}

This command will route requests to the {agent_name} agent.
Verify this agent exists or will be created.

Continue? (y/n):
```

**Validation:**
- Agent name is not empty
- Agent name follows kebab-case convention

### 3. Prompt for Missing Required Information

#### Description (if not provided)

```
Please provide a brief description of the command:

This description will appear in the frontmatter and help users understand
what the command does.

Examples:
  • "Create a new application feature"
  • "Deploy infrastructure to cloud environment"
  • "Analyze datasets and generate insights"

Enter description:
```

**Validation:**
- Not empty
- Between 10-200 characters
- Starts with capital letter
- Clear and specific

#### Argument Hint (if not provided)

```
What is the argument pattern for this command?

Use angle brackets for required args, square brackets for optional args.

Examples:
  • "<name>" - Single required argument
  • "<name> [--type <type>]" - Required + optional flag
  • "<input-file> --output <path> [--format <type>]" - Multiple args
  • "" - No arguments (press Enter for none)

Enter argument hint:
```

**Validation:**
- Can be empty if command takes no arguments
- Should use angle brackets < > for required
- Should use square brackets [ ] for optional
- Should use space-separated syntax (SPEC-00014)
- Examples: `<name>`, `<file> [--format <type>]`

### 4. Prompt for Plugin Name (if not provided)

```
Which plugin should this command be added to?

Detected plugins in this repository:
  • faber
  • faber-app
  • faber-cloud
  • work
  • repo
  [list all plugins found in plugins/ directory]

Enter plugin name (or press Enter to detect from current directory):
```

**Validation:**
- Plugin directory must exist in `plugins/`
- If empty, detect from current working directory
- Command will be created in `plugins/{plugin_name}/commands/{command_name}.md`

### 5. Compute Full Command Name

Compute the full command name that will be used:

```
Full command name: {plugin_name}:{command_name}

This command will be invoked as:
  /{plugin_name}:{command_name} {argument_hint}

Note: The frontmatter will have NO leading slash:
  name: {plugin_name}:{command_name}

This follows SPEC-00014 CLI argument standards.
```

### 6. Prompt for Optional Information

#### Example Arguments (optional)

```
Provide example command invocations? (Optional)

List 2-3 example ways to call this command.

Examples:
  • "/fractary-faber-app:create-feature user-auth"
  • "/fractary-faber-app:create-feature payment --type stripe"

Enter examples (one per line, or press Enter to skip):
```

**Validation:**
- Can be empty
- Each example should start with / and full command name
- Should demonstrate different argument patterns

### 7. Confirm Requirements

Display collected requirements and confirm:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Command Requirements Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Command Name: {command_name}
Full Name: {plugin_name}:{command_name}
Description: {description}
Argument Hint: {argument_hint or "No arguments"}

Invokes: {agent_name} agent
Plugin: {plugin_name}
Location: plugins/{plugin_name}/commands/{command_name}.md

Usage:
  /{plugin_name}:{command_name} {argument_hint}

Routes to:
  @agent-{plugin_name}:{agent_name}

Optional:
  Examples: {examples_count or "None specified"}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Proceed with command creation? (y/n):
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
  "artifact_type": "command",
  "requirements": {
    "name": "{command_name}",
    "full_name": "{plugin_name}:{command_name}",
    "description": "{description}",
    "plugin_name": "{plugin_name}",
    "agent_name": "{agent_name}",
    "agent_reference": "@agent-{plugin_name}:{agent_name}",
    "argument_hint": "{argument_hint}",
    "output_path": "plugins/{plugin_name}/commands/{command_name}.md",
    "examples": [
      "{example1}",
      "{example2}"
    ]
  }
}
```

## Error Handling

**User Cancels:**
Return `{"status": "cancelled", "message": "Command creation cancelled by user"}`

**Invalid Input:**
- Re-prompt up to 3 times
- After 3 failures, return error with validation message

**Plugin Not Found:**
Return `{"status": "error", "error": "Plugin not found: {plugin_name}", "step": "plugin_validation"}`

**Agent Name Missing:**
Return `{"status": "error", "error": "Agent name is required for command creation", "step": "agent_validation"}`

## Validation Rules

### Command Name
- Lowercase letters, numbers, hyphens only
- Must start with letter
- No consecutive hyphens
- 3-50 characters
- Examples: "create-feature", "deploy", "analyze"

### Full Command Name
- Format: `{plugin_name}:{command_name}`
- NO leading slash in frontmatter
- Examples: "fractary-faber-app:create-feature", "fractary-repo:branch"

### Agent Name
- Lowercase letters, numbers, hyphens only
- Must be valid agent identifier
- Examples: "feature-creator", "workflow-manager", "deployment-manager"

### Description
- 10-200 characters
- Starts with capital letter
- No newlines
- Clear and specific

### Argument Hint
- Can be empty (no arguments)
- Use angle brackets for required: `<name>`
- Use square brackets for optional: `[--flag <value>]`
- Space-separated syntax (not equals)
- Examples: `<file>`, `<name> [--type <type>]`, `<input> --output <path>`

### Plugin Name
- Must match existing plugin directory in `plugins/`
- Lowercase with hyphens
- Examples: "faber", "faber-cloud", "work"

### Examples (if provided)
- Should start with `/`
- Should use full command name
- Should demonstrate different argument patterns
- Should follow space-separated syntax

## Key Standards

### SPEC-00014: CLI Argument Standards

Commands MUST follow these patterns:

✅ **Correct:**
- `<name>` - Required positional argument
- `[--flag <value>]` - Optional named argument with value
- `[--flag]` - Optional boolean flag
- Space-separated: `--flag value` (not `--flag=value`)

❌ **Incorrect:**
- `--flag=value` - No equals signs
- `<name>` with default in usage - Use `[<name>]` if optional

### Frontmatter Standards

- `name:` field has NO leading slash
- Format: `plugin:command`
- `argument-hint:` uses space-separated syntax
- `description:` is clear and concise

### Agent Invocation Standards

- Commands invoke agents using declarative markdown
- NOT tool calls
- Format: `Use the @agent-{plugin}:{agent} agent with...`

This workflow ensures all necessary information is collected before command generation begins.
