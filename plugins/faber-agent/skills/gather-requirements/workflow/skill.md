# Skill Requirements Gathering Workflow

This workflow defines how to gather requirements for creating a new skill.

## Required Information

1. **Skill Name** - Identifier (kebab-case)
2. **Description** - Brief purpose statement
3. **Responsibility** - Primary responsibility (1-2 sentences)
4. **Tools** - Claude Code tools to use
5. **Plugin Name** - Target plugin location
6. **Inputs** - What the skill receives
7. **Outputs** - What the skill returns

## Optional Information

8. **Handler Type** - If multi-provider (e.g., "iac", "hosting")
9. **Workflow Steps** - High-level steps skill will execute
10. **Scripts Needed** - List of scripts for deterministic operations
11. **Completion Criteria** - Success conditions
12. **Invokes** - Other skills or commands this skill calls

## Gathering Process

### 1. Check Provided Parameters

Check which parameters were already provided in `provided_params`:
- If `skill_name` is provided: Use it (already validated by command)
- If `description` is provided: Use it
- If `tools` is provided: Use it, otherwise default to "Bash"
- If `plugin_name` is provided: Validate plugin exists
- If `handler_type` is provided: Note multi-provider skill

### 2. Prompt for Missing Required Information

#### Description (if not provided)

```
Please provide a brief description of the skill:

This description will appear in the frontmatter and documentation.

Examples:
  • "Fetches data from external sources and validates format"
  • "Deploys infrastructure using Terraform"
  • "Validates code quality and runs linters"

Enter description:
```

**Validation:**
- Not empty
- Between 10-200 characters
- Starts with capital letter
- Clear and specific

#### Responsibility (always prompt)

```
What is the primary responsibility of this skill?

This is a 1-2 sentence statement of what the skill does.

Examples:
  • "fetching data from external APIs and validating response format"
  • "executing Terraform operations to provision infrastructure"
  • "running code quality checks and reporting violations"

Enter responsibility:
```

**Validation:**
- Not empty
- Starts with lowercase (will be inserted after "responsible for")
- Ends without period (formatting handled by template)

#### Inputs (always prompt)

```
What inputs does this skill receive?

Describe the parameters passed to the skill when invoked.

Examples:
  • "source URL, authentication credentials, timeout value"
  • "infrastructure specification, environment name, provider config"
  • "file paths to check, linter configuration"

Enter inputs (or "none" if skill takes no parameters):
```

**Validation:**
- Not empty
- Clear parameter list or "none"

#### Outputs (always prompt)

```
What does this skill return as output?

Describe the structure of the response returned by the skill.

Examples:
  • "JSON object with fetched data and validation status"
  • "Deployment status, resource IDs, and operation logs"
  • "Quality score, list of violations, and recommendations"

Enter outputs:
```

**Validation:**
- Not empty
- Clear output description

### 3. Prompt for Plugin Name (if not provided)

```
Which plugin should this skill be added to?

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
- Skill will be created in `plugins/{plugin_name}/skills/{skill_name}/`

### 4. Prompt for Tools (if not provided)

```
Which Claude Code tools should this skill use?

Common combinations:
  • "Bash" - Standard for most skills (run scripts)
  • "Bash, Read, Write" - For file manipulation skills
  • "Bash, WebFetch" - For API/web interaction skills
  • "Bash, Grep, Glob" - For file search skills

Enter tools (comma-separated) or press Enter for default [Bash]:
```

**Validation:**
- If empty, use default: "Bash"
- Valid tools: Bash, Read, Write, Edit, WebFetch, Grep, Glob, Skill
- Comma-separated list
- Trim whitespace

### 5. Prompt for Optional Information

#### Handler Type (if not already provided)

```
Is this a multi-provider handler skill? (Optional)

Handler skills provide abstraction across multiple providers.
Examples: iac (terraform/pulumi/cdk), hosting (aws/gcp/azure)

Enter handler type or press Enter to skip:
```

**Validation:**
- If provided, should be lowercase single word
- Common types: iac, hosting, storage, messaging, monitoring

#### Workflow Steps (optional)

```
What are the high-level steps this skill will execute? (Optional)

List the major steps in order.

Examples:
  • "1. Validate input, 2. Fetch data, 3. Transform, 4. Return result"
  • "1. Load config, 2. Plan changes, 3. Apply, 4. Verify"

Enter steps or press Enter to skip:
```

#### Scripts Needed (optional)

```
What scripts does this skill need? (Optional)

List script names for deterministic operations.

Examples:
  • "fetch-data.sh, validate-format.sh"
  • "terraform-plan.sh, terraform-apply.sh"

Enter script names (comma-separated) or press Enter to skip:
```

#### Completion Criteria (optional but recommended)

```
What are the success conditions for this skill? (Optional)

Define what "complete and successful" means.

Examples:
  • "Data fetched successfully and validated"
  • "Infrastructure deployed without errors"
  • "All quality checks passed"

Enter criteria or press Enter to skip:
```

### 6. Confirm Requirements

Display collected requirements and confirm:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Skill Requirements Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Name: {skill_name}
Description: {description}
Responsibility: {responsibility}
Tools: {tools}
Plugin: {plugin_name}
Location: plugins/{plugin_name}/skills/{skill_name}/

Inputs: {inputs}
Outputs: {outputs}

Optional:
  Handler Type: {handler_type or "Not a handler"}
  Workflow Steps: {steps or "Not specified"}
  Scripts: {scripts or "None specified"}
  Completion Criteria: {criteria or "Not specified"}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Proceed with skill creation? (y/n):
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
  "artifact_type": "skill",
  "requirements": {
    "name": "{skill_name}",
    "description": "{description}",
    "responsibility": "{responsibility}",
    "tools": "{tools}",
    "plugin_name": "{plugin_name}",
    "output_path": "plugins/{plugin_name}/skills/{skill_name}/",
    "handler_type": "{handler_type}",
    "inputs": "{inputs}",
    "outputs": "{outputs}",
    "workflow_steps": "{steps}",
    "scripts_needed": "{scripts}",
    "completion_criteria": "{criteria}"
  }
}
```

## Error Handling

**User Cancels:**
Return `{"status": "cancelled", "message": "Skill creation cancelled by user"}`

**Invalid Input:**
- Re-prompt up to 3 times
- After 3 failures, return error with validation message

**Plugin Not Found:**
Return `{"status": "error", "error": "Plugin not found: {plugin_name}", "step": "plugin_validation"}`

## Validation Rules

### Skill Name
- Lowercase letters, numbers, hyphens only
- Must start with letter
- No consecutive hyphens
- 3-50 characters
- Examples: "data-fetcher", "terraform-deployer", "api-client"

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
- From valid tool list: Bash, Read, Write, Edit, WebFetch, Grep, Glob, Skill
- Comma-separated
- At least one tool required

### Plugin Name
- Must match existing plugin directory in `plugins/`
- Lowercase with hyphens
- Examples: "faber", "faber-cloud", "work"

### Handler Type (if provided)
- Lowercase single word
- No spaces or special characters
- Examples: "iac", "hosting", "storage"

### Inputs/Outputs
- Clear description of parameters/results
- Can be "none" for inputs if skill has no parameters

This workflow ensures all necessary information is collected before skill generation begins.
