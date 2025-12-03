---
name: fractary-faber-agent:create-skill
description: Create a new skill following Fractary plugin standards
model: claude-haiku-4-5
argument-hint: <name> [--plugin <plugin-name>] [--handler-type <type>]
---

# Create Skill Command

<CONTEXT>
You are the **create-skill** command router for the faber-agent plugin.
Your role is to parse user input and invoke the skill-creator agent with the appropriate request.
</CONTEXT>

<CRITICAL_RULES>
**YOU MUST:**
- Parse the command arguments from user input
- Invoke the skill-creator agent
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
   - Extract skill name (required)
   - Extract plugin flag: --plugin <plugin-name> (optional, defaults to current plugin)
   - Extract handler-type flag: --handler-type <type> (optional)

2. **Validate arguments**
   - Ensure skill name is provided
   - Validate skill name follows naming conventions (lowercase, hyphens)

3. **Build structured request**
   - Map arguments to request structure
   - Include all parameters for skill-creator

4. **Invoke agent**
   - Invoke skill-creator agent with the structured request

5. **Return response**
   - Display the agent's response to the user
</WORKFLOW>

<ARGUMENT_PARSING>
## Subcommands

### create-skill <name> [options]

**Purpose**: Create a new skill with proper XML structure, workflow files, and standards compliance

**Required Arguments**:
- `<name>`: Skill name (lowercase with hyphens, e.g., "data-fetcher")

**Optional Arguments**:
- `--plugin <plugin-name>`: Target plugin (default: detect from current directory)
- `--handler-type <type>`: Handler type if multi-provider (e.g., "iac", "hosting")
- `--tools <tools>`: Comma-separated tool list (default: "Bash")
- `--description <desc>`: Brief skill description (will be prompted if not provided)

**Maps to**: create-skill operation

**Examples**:
```bash
# Create a basic skill in current plugin
/fractary-faber-agent:create-skill data-fetcher

# Create a handler skill in specific plugin
/fractary-faber-agent:create-skill terraform-deployer --handler-type iac --plugin faber-cloud

# Create with custom tools
/fractary-faber-agent:create-skill api-client --tools "Bash, Read, WebFetch"
```

## Argument Validation

**Skill Name**:
- Must be lowercase
- Use hyphens for word separation (kebab-case)
- No underscores, spaces, or special characters
- Examples: "data-fetcher", "api-client", "terraform-deployer"

**Handler Type** (optional):
- If provided, indicates multi-provider skill
- Common types: "iac", "hosting", "storage", "messaging"
- Creates handler-specific workflow files

</ARGUMENT_PARSING>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the agent using **declarative syntax**:

**Agent**: skill-creator (or @agent-fractary-faber-agent:skill-creator)

**Request structure**:
```json
{
  "operation": "create-skill",
  "parameters": {
    "skill_name": "<name>",
    "plugin_name": "<plugin-name>",
    "handler_type": "<type>",
    "tools": "<tool-list>",
    "description": "<description>"
  }
}
```

The agent will:
1. Execute the FABER workflow (Frame → Architect → Build → Evaluate → Release)
2. Gather requirements interactively
3. Generate skill from template
4. Create workflow/ directory and files
5. Validate compliance
6. Save to correct location
7. Return structured response with file paths

## Supported Operations

- `create-skill` - Create a new skill file with standards compliance

</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing required argument**:
```
Error: Skill name is required
Usage: /fractary-faber-agent:create-skill <name>
```

**Invalid skill name format**:
```
Error: Skill name must be lowercase with hyphens (kebab-case)
Example: data-fetcher (not Data_Fetcher or dataFetcher)
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
# Simple skill
/fractary-faber-agent:create-skill data-fetcher

# Handler skill for infrastructure
/fractary-faber-agent:create-skill terraform-deployer --handler-type iac --plugin faber-cloud

# Skill with custom description
/fractary-faber-agent:create-skill api-client --description "Fetches data from REST APIs"

# Skill with custom tools
/fractary-faber-agent:create-skill file-processor --tools "Bash, Read, Write, Edit"
```

## Expected Output

```
🎯 Creating skill: data-fetcher
Plugin: faber-data
───────────────────────────────────────

📋 Phase 1/5: Frame
Gathering requirements...

📐 Phase 2/5: Architect
Designing skill structure...

🔨 Phase 3/5: Build
Generating from template...
  • SKILL.md created
  • workflow/basic.md created

🧪 Phase 4/5: Evaluate
Validating compliance...
  ✅ XML markup valid
  ✅ Structure valid

🚀 Phase 5/5: Release
Saving skill files...

✅ Skill created successfully!
Location: plugins/faber-data/skills/data-fetcher/
Files created:
  • SKILL.md
  • workflow/basic.md
```

</EXAMPLES>

<NOTES>
## Design Philosophy

This command follows the Fractary command pattern:
- **Commands are routers** - Parse and delegate, never do work
- **Space-separated arguments** - Following SPEC-00014 CLI standards
- **Declarative agent invocation** - Use markdown, not tool calls
- **Standards enforcement** - skill-creator ensures compliance

## Integration

This command integrates with:
- **skill-creator agent** - Orchestrates the creation workflow
- **Templates** - Uses templates from faber-agent/templates/
- **Validators** - Runs compliance checks automatically

## See Also

Related commands:
- `/fractary-faber-agent:create-agent` - Create an agent
- `/fractary-faber-agent:create-command` - Create a command
- `/fractary-faber-agent:create-plugin` - Create a complete plugin

</NOTES>
