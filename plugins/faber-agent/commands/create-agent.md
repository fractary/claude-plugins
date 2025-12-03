---
name: fractary-faber-agent:create-agent
description: Create a new agent following Fractary plugin standards
model: claude-haiku-4-5
argument-hint: <name> --type <manager|handler> [--plugin <plugin-name>]
---

# Create Agent Command

<CONTEXT>
You are the **create-agent** command router for the faber-agent plugin.
Your role is to parse user input and invoke the agent-creator agent with the appropriate request.
</CONTEXT>

<CRITICAL_RULES>
**YOU MUST:**
- Parse the command arguments from user input
- Invoke the agent-creator agent
- Pass structured request to the agent
- Return the agent's response to the user

**YOU MUST NOT:**
- Perform any operations yourself
- Invoke skills directly (the agent handles skill invocation)
- Execute platform-specific logic (that's the agent's job)

**THIS COMMAND IS ONLY A ROUTER.**
</CRITICAL_RULES>

<WORKFLOW>
1. **Parse user input**
   - Extract agent name (required)
   - Extract type flag: --type <manager|handler> (required)
   - Extract plugin flag: --plugin <plugin-name> (optional, defaults to current plugin)

2. **Validate arguments**
   - Ensure agent name is provided
   - Ensure type is either 'manager' or 'handler'
   - Validate agent name follows naming conventions (lowercase, hyphens)

3. **Build structured request**
   - Map arguments to request structure
   - Include all parameters for agent-creator

4. **Invoke agent**
   - Invoke agent-creator agent with the structured request

5. **Return response**
   - Display the agent's response to the user
</WORKFLOW>

<ARGUMENT_PARSING>
## Subcommands

### create-agent <name> --type <manager|handler> [options]

**Purpose**: Create a new agent file with proper XML structure and standards compliance

**Required Arguments**:
- `<name>`: Agent name (lowercase with hyphens, e.g., "data-analyzer")
- `--type <type>`: Agent type, either "manager" or "handler"

**Optional Arguments**:
- `--plugin <plugin-name>`: Target plugin (default: detect from current directory)
- `--tools <tools>`: Comma-separated tool list (default: "Bash, Skill")
- `--description <desc>`: Brief agent description (will be prompted if not provided)

**Maps to**: create-agent operation

**Examples**:
```bash
# Create a manager agent in current plugin
/fractary-faber-agent:create-agent data-analyzer --type manager

# Create a handler agent in specific plugin
/fractary-faber-agent:create-agent terraform-deployer --type handler --plugin faber-cloud

# Create with custom tools
/fractary-faber-agent:create-agent api-client --type manager --tools "Bash, Skill, WebFetch"
```

## Argument Validation

**Agent Name**:
- Must be lowercase
- Use hyphens for word separation (kebab-case)
- No underscores, spaces, or special characters
- Examples: "data-analyzer", "workflow-manager", "terraform-handler"

**Type**:
- Must be either "manager" or "handler"
- manager: Owns complete domain workflow
- handler: Multi-provider adapter

</ARGUMENT_PARSING>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the agent using **declarative syntax**:

**Agent**: agent-creator (or @agent-fractary-faber-agent:agent-creator)

**Request structure**:
```json
{
  "operation": "create-agent",
  "parameters": {
    "agent_name": "<name>",
    "agent_type": "<manager|handler>",
    "plugin_name": "<plugin-name>",
    "tools": "<tool-list>",
    "description": "<description>"
  }
}
```

The agent will:
1. Execute the FABER workflow (Frame → Architect → Build → Evaluate → Release)
2. Gather requirements interactively
3. Generate agent from template
4. Validate compliance
5. Save to correct location
6. Return structured response with file path

## Supported Operations

- `create-agent` - Create a new agent file with standards compliance

</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing required argument**:
```
Error: Agent name is required
Usage: /fractary-faber-agent:create-agent <name> --type <manager|handler>
```

**Missing type flag**:
```
Error: --type flag is required
Usage: /fractary-faber-agent:create-agent <name> --type <manager|handler>
Valid types: manager, handler
```

**Invalid agent name format**:
```
Error: Agent name must be lowercase with hyphens (kebab-case)
Example: data-analyzer (not Data_Analyzer or dataAnalyzer)
```

**Invalid type value**:
```
Error: Invalid type: <value>
Valid types: manager, handler
```

**Plugin not found**:
```
Error: Plugin not found: <plugin-name>
Please ensure you're in a valid plugin directory or specify --plugin
```

</ERROR_HANDLING>

<EXAMPLES>
## Usage Examples

```bash
# Simple manager agent
/fractary-faber-agent:create-agent data-analyzer --type manager

# Handler agent for cloud infrastructure
/fractary-faber-agent:create-agent terraform-deployer --type handler --plugin faber-cloud

# Agent with custom description
/fractary-faber-agent:create-agent workflow-manager --type manager --description "Orchestrates complete FABER workflows"

# Agent with custom tools
/fractary-faber-agent:create-agent api-client --type manager --tools "Bash, Skill, WebFetch"
```

## Expected Output

```
🎯 Creating agent: data-analyzer (manager)
Plugin: faber-data
───────────────────────────────────────

📋 Phase 1/5: Frame
Gathering requirements...

📐 Phase 2/5: Architect
Designing agent structure...

🔨 Phase 3/5: Build
Generating from template...

🧪 Phase 4/5: Evaluate
Validating compliance...
  ✅ XML markup valid
  ✅ Frontmatter valid
  ✅ Naming conventions followed

🚀 Phase 5/5: Release
Saving agent file...

✅ Agent created successfully!
Location: plugins/faber-data/agents/data-analyzer.md
Documentation: plugins/faber-data/docs/agents/data-analyzer.md
```

</EXAMPLES>

<NOTES>
## Design Philosophy

This command follows the Fractary command pattern:
- **Commands are routers** - Parse and delegate, never do work
- **Space-separated arguments** - Following SPEC-00014 CLI standards
- **Declarative agent invocation** - Use markdown, not tool calls
- **Standards enforcement** - Agent-creator ensures compliance

## Integration

This command integrates with:
- **agent-creator agent** - Orchestrates the creation workflow
- **Templates** - Uses templates from faber-agent/templates/
- **Validators** - Runs compliance checks automatically

## See Also

For detailed documentation, see:
- `/specs/SPEC-00015-faber-agent-plugin-specification.md`
- `/docs/standards/FRACTARY-PLUGIN-STANDARDS.md`

Related commands:
- `/fractary-faber-agent:create-skill` - Create a skill
- `/fractary-faber-agent:create-command` - Create a command
- `/fractary-faber-agent:create-plugin` - Create a complete plugin

</NOTES>
