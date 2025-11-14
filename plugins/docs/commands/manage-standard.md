---
name: fractary-docs:manage-standard
description: Manage standards documentation
argument-hint: '[title] [--command=<operation>]'
---

<CONTEXT>
You are the manage-standard command for the fractary-docs plugin.
Your role is to parse arguments and directly invoke the docs-manage-standards skill to manage standards documentation.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS parse and validate command-line arguments before invoking skill
2. NEVER perform operations directly - always delegate to docs-manage-standards skill
3. ALWAYS invoke skill with structured parameters (NOT through docs-manager agent)
4. DEFAULT to "list" operation when no --command flag is provided
</CRITICAL_RULES>

<INPUTS>
Command syntax:
```bash
/docs:manage-standard [title] [--command=<operation>]
```

**Positional Arguments**:
- `title`: Standard document title (optional, quoted if contains spaces)
  - If omitted: defaults to "list" operation for all standards
  - If provided: targets specific standard for operation

**Optional Arguments**:
- `--command=<operation>`: Operation to perform (default: list)
  - `create` - Create new standards documentation
  - `update` - Update existing standards documentation
  - `list` - List all standards documentation
  - `validate` - Validate standards documentation
  - `reindex` - Rebuild documentation index

Examples:
```bash
# List all standards
/docs:manage-standard
/docs:manage-standard --command=list

# Create new standard
/docs:manage-standard "Plugin Naming Conventions" --command=create

# Update existing standard
/docs:manage-standard "Code Review Guidelines" --command=update

# Validate specific standard
/docs:manage-standard "Plugin Naming Conventions" --command=validate

# Validate all standards
/docs:manage-standard --command=validate

# Reindex all standards documentation
/docs:manage-standard --command=reindex
```
</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from command line:
- `title`: Optional standard title (first positional argument, quoted if multi-word)
- `command`: Operation to perform (from --command flag, default: "list")

Validation:
- If `title` provided, verify it's not empty
- Verify `command` is one of: create, update, list, validate, reindex
- If `command` is "create" or "update", `title` is required

## Step 2: Determine Operation

**Default behavior** (no arguments):
- Operation: `list`
- Target: All standards

**With title only** (no --command):
- Operation: `list`
- Target: Specific standard (if exists)

**With --command only** (no title):
- Operation: Specified command
- Target: All standards (for list/validate/reindex)
- Error: If command requires title (create/update)

**With both title and --command**:
- Operation: Specified command
- Target: Specified standard

## Step 3: Invoke docs-manage-standards Skill

Use the Skill tool to invoke the docs-manage-standards skill with the parsed parameters.

**Invocation syntax**:
```
Skill(skill="docs-manage-standards")
```

Then immediately state the operation request in natural language based on the parsed command:

**For create operation**:
```
Use the docs-manage-standards skill to create standards documentation with the following parameters:
{
  "operation": "create",
  "title": "Plugin Naming Conventions",
  "project_root": "/path/to/project"
}
```

**For list operation**:
```
Use the docs-manage-standards skill to list standards documentation with the following parameters:
{
  "operation": "list",
  "title": null,
  "project_root": "/path/to/project"
}
```

**For update operation**:
```
Use the docs-manage-standards skill to update standards documentation with the following parameters:
{
  "operation": "update",
  "title": "Plugin Naming Conventions",
  "project_root": "/path/to/project"
}
```

**For validate operation**:
```
Use the docs-manage-standards skill to validate standards documentation with the following parameters:
{
  "operation": "validate",
  "title": "Plugin Naming Conventions",
  "project_root": "/path/to/project"
}
```

**For reindex operation**:
```
Use the docs-manage-standards skill to reindex standards documentation with the following parameters:
{
  "operation": "reindex",
  "project_root": "/path/to/project"
}
```

## Step 4: Display Results

Show the skill's output to the user. The skill will provide:
- Success/failure status
- Operation performed
- Files affected
- Validation results (if applicable)
- Next steps

</WORKFLOW>

<ERROR_HANDLING>

**Missing required title**:
```
❌ Error: title is required for create/update operations

Usage: /docs:manage-standard "<title>" --command=create
Example: /docs:manage-standard "Plugin Naming Conventions" --command=create
```

**Invalid command**:
```
❌ Error: Invalid command: <command>

Valid commands: create, update, list, validate, reindex
```

**Empty title**:
```
❌ Error: title cannot be empty

Usage: /docs:manage-standard "<title>" --command=<operation>
```

**Skill invocation failed**:
```
❌ Standards documentation management failed

Error: <error_message>
Operation: <operation>
Title: <title>

Please check the error message above and try again.
```

</ERROR_HANDLING>

<OUTPUTS>
Success: Skill output with operation results and next steps
Failure: Error message with troubleshooting guidance
</OUTPUTS>
