# Plugin Requirements Gathering Workflow

This workflow defines how to gather requirements for creating a new plugin.

## Required Information

1. **Plugin Name** - Identifier (must start with "fractary-")
2. **Plugin Type** - "workflow", "primitive", or "utility"
3. **Description** - Brief purpose statement
4. **Dependencies** - Required plugins (requires field)

## Optional Information

5. **Agent Count** - Number of placeholder agents to create
6. **Skill Count** - Number of placeholder skills to create
7. **Command Count** - Number of placeholder commands to create
8. **Domain** - Domain or artifact this plugin handles

## Gathering Process

### 1. Check Provided Parameters

Check which parameters were already provided in `provided_params`:
- If `plugin_name` is provided: Use it (validate fractary- prefix)
- If `plugin_type` is provided: Validate it's valid type
- If `description` is provided: Use it
- If `requires` is provided: Use it (array of dependencies)
- If placeholder counts provided: Use them

### 2. Validate Plugin Name

Ensure plugin name follows conventions:

```
Plugin name: {plugin_name}

Checking naming conventions...
```

**Validation:**
- Must start with "fractary-" prefix
- For workflow plugins: "fractary-faber-{artifact}"
  - Examples: fractary-faber-data, fractary-faber-mobile
- For primitive plugins: "fractary-{concern}"
  - Examples: fractary-work, fractary-repo, fractary-storage
- For utility plugins: "fractary-{tool}"
  - Examples: fractary-convert, fractary-validator

If invalid format:
```
❌ Invalid plugin name: {plugin_name}

Plugin names must start with "fractary-" prefix.

Examples:
  • Workflow: fractary-faber-data, fractary-faber-mobile
  • Primitive: fractary-storage, fractary-monitoring
  • Utility: fractary-convert, fractary-validator

Please enter a valid plugin name:
```

### 3. Validate Plugin Type

Ensure plugin type is valid:

```
Plugin type: {plugin_type}

Types:
  • workflow - Creates artifacts using FABER (apps, APIs, content, infra)
  • primitive - Manages concerns (work, repo, file, storage)
  • utility - Tools and utilities (convert, validate, sync)
```

**Validation:**
- Must be exactly "workflow", "primitive", or "utility"
- Case-insensitive input, normalized to lowercase

If invalid:
```
❌ Invalid plugin type: {plugin_type}

Valid types:
  • workflow
  • primitive
  • utility

Please enter a valid type:
```

### 4. Prompt for Description (if not provided)

```
Please provide a brief description of the plugin:

This description will appear in the plugin manifest and README.

Examples:
  • "Data analysis and transformation workflows" (workflow)
  • "Storage management across multiple providers" (primitive)
  • "Framework conversion tools" (utility)

Enter description:
```

**Validation:**
- Not empty
- Between 10-200 characters
- Starts with capital letter
- Clear and specific

### 5. Prompt for Dependencies (if not provided)

```
Does this plugin require other plugins? (Optional)

Enter required plugin names (comma-separated) or press Enter for none:

Common dependencies:
  • fractary-faber (for workflow plugins)
  • fractary-work, fractary-repo (for many plugins)

Example: fractary-faber,fractary-work

Enter dependencies:
```

**Validation:**
- Can be empty (no dependencies)
- Comma-separated list
- Each must be valid plugin name format
- Trim whitespace

### 6. Prompt for Placeholder Counts (optional)

```
How many placeholder artifacts should be created?

Placeholders provide structure and can be customized later.

Agents (orchestrators): [default: 1]
Skills (execution units): [default: 3]
Commands (entry points): [default: 2]

Press Enter to use defaults, or enter custom counts:
  Agents:
```

**Validation:**
- Must be positive integers
- Reasonable limits (1-10 for agents, 1-20 for skills/commands)
- Default values if empty

### 7. Prompt for Domain (optional)

```
What domain or artifact does this plugin handle? (Optional)

Examples:
  • "data analysis" (workflow)
  • "cloud storage" (primitive)
  • "framework conversion" (utility)

Enter domain or press Enter to skip:
```

### 8. Check for Existing Plugin

```
Checking if plugin already exists...
```

```bash
if [ -d "plugins/{plugin_name}" ]; then
    echo "⚠️  Warning: Plugin already exists at plugins/{plugin_name}/"
    echo ""
    echo "Options:"
    echo "  1. Choose a different name"
    echo "  2. Remove existing plugin first"
    echo "  3. Cancel creation"
    echo ""
    read -p "Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        exit 1
    fi
fi
```

### 9. Confirm Requirements

Display collected requirements and confirm:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plugin Requirements Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Name: {plugin_name}
Type: {plugin_type}
Description: {description}
Location: plugins/{plugin_name}/

Dependencies:
  {• requires_list or "None"}

Placeholders to create:
  • Agents: {agent_count}
  • Skills: {skill_count}
  • Commands: {command_count}

Structure:
  • .claude-plugin/plugin.json
  • agents/ ({agent_count} placeholders)
  • skills/ ({skill_count} placeholders)
  • commands/ ({command_count} placeholders)
  • docs/
  • config/
  • README.md

Optional:
  Domain: {domain or "Not specified"}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Proceed with plugin creation? (y/n):
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
  "artifact_type": "plugin",
  "requirements": {
    "name": "{plugin_name}",
    "type": "{plugin_type}",
    "description": "{description}",
    "output_path": "plugins/{plugin_name}/",
    "requires": [
      "plugin1",
      "plugin2"
    ],
    "placeholder_counts": {
      "agents": {agent_count},
      "skills": {skill_count},
      "commands": {command_count}
    },
    "domain": "{domain}"
  }
}
```

## Error Handling

**User Cancels:**
Return `{"status": "cancelled", "message": "Plugin creation cancelled by user"}`

**Invalid Input:**
- Re-prompt up to 3 times
- After 3 failures, return error with validation message

**Plugin Already Exists:**
- Warn user
- Offer to continue or cancel
- If user cancels, return cancelled status

**Invalid Plugin Name:**
Return `{"status": "error", "error": "Plugin name must start with 'fractary-'", "step": "name_validation"}`

**Invalid Plugin Type:**
Return `{"status": "error", "error": "Invalid plugin type: {type}. Must be workflow, primitive, or utility", "step": "type_validation"}`

## Validation Rules

### Plugin Name
- Must start with "fractary-" prefix
- Lowercase letters, numbers, hyphens only
- No consecutive hyphens
- 10-50 characters total
- Examples:
  - Workflow: "fractary-faber-data", "fractary-faber-mobile"
  - Primitive: "fractary-storage", "fractary-monitoring"
  - Utility: "fractary-convert", "fractary-validator"

### Plugin Type
- Exactly "workflow", "primitive", or "utility"
- Case-insensitive input, normalized to lowercase

### Description
- 10-200 characters
- Starts with capital letter
- No newlines
- Clear and specific

### Dependencies (if provided)
- Array of plugin names
- Each must be valid plugin name format
- Can be empty array (no dependencies)

### Placeholder Counts
- Positive integers
- Agents: 1-10
- Skills: 1-20
- Commands: 1-10
- Defaults: 1 agent, 3 skills, 2 commands

### Domain (if provided)
- Optional string
- Lowercase recommended
- Examples: "data analysis", "cloud storage", "content creation"

## Plugin Taxonomy

### Workflow Plugins (`fractary-faber-*`)
Create artifacts using FABER framework:
- **fractary-faber-app** - Application development
- **fractary-faber-api** - Backend services
- **fractary-faber-cloud** - Cloud infrastructure
- **fractary-faber-data** - Data analysis
- **fractary-faber-mobile** - Mobile apps
- **fractary-faber-video** - Video content
- **fractary-faber-blog** - Blog content

Typical structure:
- 1-2 manager agents (director, workflow-manager)
- 5-10 skills (phase-specific)
- 2-5 commands (create, deploy, status)

### Primitive Plugins (`fractary-*`)
Manage infrastructure concerns:
- **fractary-work** - Work item management
- **fractary-repo** - Source control
- **fractary-file** - File storage
- **fractary-codex** - Knowledge management
- **fractary-storage** - Cloud storage
- **fractary-messaging** - Message queues

Typical structure:
- 1 manager agent
- 3-8 skills (operation-specific)
- 5-10 commands (CRUD operations)

### Utility Plugins (`fractary-*`)
Tools and utilities:
- **fractary-convert** - Framework conversion
- **fractary-validator** - Validation tools
- **fractary-sync** - Synchronization tools

Typical structure:
- 1-2 agents
- 2-5 skills
- 3-5 commands

This workflow ensures all necessary information is collected before plugin generation begins.
