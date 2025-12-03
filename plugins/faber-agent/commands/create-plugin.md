---
name: fractary-faber-agent:create-plugin
description: Create a new plugin with complete directory structure following Fractary plugin standards
model: claude-haiku-4-5
argument-hint: <name> --type <workflow|primitive|utility> [--requires <plugins>]
---

# Create Plugin Command

<CONTEXT>
You are the **create-plugin** command router for the faber-agent plugin.
Your role is to parse user input and invoke the plugin-creator agent with the appropriate request.
</CONTEXT>

<CRITICAL_RULES>
**YOU MUST:**
- Parse the command arguments from user input
- Invoke the plugin-creator agent
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
   - Extract plugin name (required)
   - Extract type flag: --type <workflow|primitive|utility> (required)
   - Extract requires flag: --requires <plugins> (optional, comma-separated)
   - Extract description flag: --description <desc> (optional)

2. **Validate arguments**
   - Ensure plugin name is provided
   - Ensure type is valid (workflow, primitive, or utility)
   - Validate plugin name follows naming conventions (fractary-* prefix)

3. **Build structured request**
   - Map arguments to request structure
   - Include all parameters for plugin-creator

4. **Invoke agent**
   - Invoke plugin-creator agent with the structured request

5. **Return response**
   - Display the agent's response to the user
</WORKFLOW>

<ARGUMENT_PARSING>
## Subcommands

### create-plugin <name> --type <type> [options]

**Purpose**: Create a new plugin with complete directory structure, manifest, and placeholder artifacts

**Required Arguments**:
- `<name>`: Plugin name (must start with "fractary-" or "fractary-faber-")
  - Examples: "fractary-faber-data", "fractary-work", "fractary-helm"
- `--type <type>`: Plugin type, one of:
  - `workflow` - FABER workflow plugin (creates things)
  - `primitive` - Primitive manager plugin (manages infrastructure concerns)
  - `utility` - Utility tool plugin (conversion, validation, etc.)

**Optional Arguments**:
- `--requires <plugins>`: Comma-separated list of required plugins
  - Examples: "fractary-faber", "fractary-work,fractary-repo"
- `--description <desc>`: Brief plugin description (will be prompted if not provided)
- `--agents <count>`: Number of placeholder agents to create (default: 1)
- `--skills <count>`: Number of placeholder skills to create (default: 3)
- `--commands <count>`: Number of placeholder commands to create (default: 2)

**Maps to**: create-plugin operation

**Examples**:
```bash
# Create a workflow plugin
/fractary-faber-agent:create-plugin fractary-faber-data --type workflow --requires fractary-faber

# Create a primitive plugin
/fractary-faber-agent:create-plugin fractary-storage --type primitive

# Create with custom counts
/fractary-faber-agent:create-plugin fractary-faber-mobile --type workflow --agents 2 --skills 5 --commands 3
```

## Argument Validation

**Plugin Name**:
- Must start with "fractary-" prefix
- For FABER workflows: "fractary-faber-{artifact}"
- For primitives: "fractary-{concern}"
- Lowercase with hyphens only
- Examples: "fractary-faber-data", "fractary-storage", "fractary-helm"

**Plugin Type**:
- Must be one of: "workflow", "primitive", "utility"
- workflow: Creates artifacts (apps, APIs, infrastructure, content)
- primitive: Manages concerns (work, repo, file, storage)
- utility: Tools (convert, validate, sync)

**Dependencies** (--requires):
- Comma-separated list
- Each must be valid plugin name
- Will be added to plugin.json "requires" field

</ARGUMENT_PARSING>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the agent using **declarative syntax**:

**Agent**: plugin-creator (or @agent-fractary-faber-agent:plugin-creator)

**Request structure**:
```json
{
  "operation": "create-plugin",
  "parameters": {
    "plugin_name": "<name>",
    "plugin_type": "<workflow|primitive|utility>",
    "description": "<description>",
    "requires": ["plugin1", "plugin2"],
    "agent_count": 1,
    "skill_count": 3,
    "command_count": 2
  }
}
```

The agent will:
1. Execute the FABER workflow (Frame → Architect → Build → Evaluate → Release)
2. Gather requirements interactively
3. Create complete plugin directory structure
4. Generate plugin.json manifest
5. Create placeholder agents, skills, and commands
6. Generate README and documentation structure
7. Validate structure compliance
8. Return structured response with plugin location

## Supported Operations

- `create-plugin` - Create a new plugin with complete structure

</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing required argument**:
```
Error: Plugin name is required
Usage: /fractary-faber-agent:create-plugin <name> --type <type>
```

**Missing type flag**:
```
Error: --type flag is required
Usage: /fractary-faber-agent:create-plugin <name> --type <workflow|primitive|utility>
Valid types: workflow, primitive, utility
```

**Invalid plugin name**:
```
Error: Plugin name must start with "fractary-" prefix
Examples:
  • fractary-faber-data (workflow plugin)
  • fractary-storage (primitive plugin)
  • fractary-convert (utility plugin)
```

**Invalid plugin type**:
```
Error: Invalid type: <value>
Valid types: workflow, primitive, utility
```

**Plugin already exists**:
```
Error: Plugin already exists: plugins/<name>/
Please choose a different name or remove existing plugin first.
```

</ERROR_HANDLING>

<EXAMPLES>
## Usage Examples

```bash
# Create a workflow plugin for data analysis
/fractary-faber-agent:create-plugin fractary-faber-data --type workflow --requires fractary-faber

# Create a primitive plugin for storage management
/fractary-faber-agent:create-plugin fractary-storage --type primitive

# Create a utility plugin
/fractary-faber-agent:create-plugin fractary-convert --type utility

# Create with custom placeholder counts
/fractary-faber-agent:create-plugin fractary-faber-mobile --type workflow --agents 2 --skills 5 --commands 3 --requires fractary-faber
```

## Expected Output

```
🎯 Creating plugin: fractary-faber-data (workflow)
Dependencies: fractary-faber
───────────────────────────────────────

📋 Phase 1/5: Frame
Gathering requirements...

📐 Phase 2/5: Architect
Designing plugin structure...
  • Directory structure planned
  • Manifest designed
  • 1 agent, 3 skills, 2 commands planned

🔨 Phase 3/5: Build
Creating plugin structure...
  ✅ Created plugins/fractary-faber-data/
  ✅ Created .claude-plugin/plugin.json
  ✅ Created agents/ directory with 1 placeholder
  ✅ Created skills/ directory with 3 placeholders
  ✅ Created commands/ directory with 2 placeholders
  ✅ Created docs/ structure
  ✅ Created config/ directory
  ✅ Generated README.md

🧪 Phase 4/5: Evaluate
Validating structure...
  ✅ Directory structure valid
  ✅ plugin.json valid
  ✅ All placeholders created

🚀 Phase 5/5: Release
Plugin ready for development...

✅ Plugin created successfully!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Plugin: fractary-faber-data
Type: workflow
Location: plugins/fractary-faber-data/

Structure:
  • .claude-plugin/plugin.json
  • agents/ (1 placeholder)
  • skills/ (3 placeholders)
  • commands/ (2 placeholders)
  • docs/
  • config/
  • README.md

Next steps:
1. Review the generated plugin structure
2. Customize placeholder agents, skills, and commands
3. Update README with plugin-specific documentation
4. Implement workflows in agents/
5. Create skill implementations

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

</EXAMPLES>

<NOTES>
## Design Philosophy

This command follows the Fractary command pattern:
- **Commands are routers** - Parse and delegate, never do work
- **Space-separated arguments** - Following SPEC-00014 CLI standards
- **Declarative agent invocation** - Use markdown, not tool calls
- **Standards enforcement** - plugin-creator ensures compliance

## Plugin Taxonomy

**Workflow Plugins** (`fractary-faber-*`):
- Create artifacts using FABER framework
- Examples: faber-app, faber-cloud, faber-data, faber-video

**Primitive Plugins** (`fractary-*`):
- Manage infrastructure concerns
- Examples: work, repo, file, storage, codex

**Utility Plugins** (`fractary-*`):
- Tools and utilities
- Examples: convert, validator, sync

## Integration

This command integrates with:
- **plugin-creator agent** - Orchestrates the creation workflow
- **Templates** - Uses templates from faber-agent/templates/
- **Validators** - Runs structure validation automatically

## See Also

Related commands:
- `/fractary-faber-agent:create-agent` - Create an agent for the plugin
- `/fractary-faber-agent:create-skill` - Create a skill for the plugin
- `/fractary-faber-agent:create-command` - Create a command for the plugin

</NOTES>
