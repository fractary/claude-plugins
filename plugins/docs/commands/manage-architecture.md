---
name: fractary-docs:manage-architecture
description: Manage system architecture documentation
argument-hint: '[title] [--command=<operation>]'
---

<CONTEXT>
You are the manage-architecture command for the fractary-docs plugin.
Your role is to parse arguments and directly invoke the docs-manage-architecture skill to manage system architecture documentation.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS parse and validate command-line arguments before invoking skill
2. NEVER perform operations directly - always delegate to docs-manage-architecture skill
3. ALWAYS invoke skill with structured parameters (NOT through docs-manager agent)
4. DEFAULT to "list" operation when no --command flag is provided
</CRITICAL_RULES>

<INPUTS>
Command syntax:
```bash
/docs:manage-architecture [title] [--command=<operation>]
```

**Positional Arguments**:
- `title`: Architecture document title (optional, quoted if contains spaces)
  - If omitted: defaults to "list" operation for all architecture docs
  - If provided: targets specific document for operation

**Optional Arguments**:
- `--command=<operation>`: Operation to perform (default: list)
  - `create` - Create new architecture documentation
  - `update` - Update existing architecture documentation
  - `list` - List all architecture documentation
  - `validate` - Validate architecture documentation
  - `reindex` - Rebuild documentation index

Examples:
```bash
# List all architecture documents
/docs:manage-architecture
/docs:manage-architecture --command=list

# Create new architecture overview
/docs:manage-architecture "System Architecture Overview" --command=create

# Update existing document
/docs:manage-architecture "Authentication Service" --command=update

# Validate specific document
/docs:manage-architecture "System Architecture Overview" --command=validate

# Validate all architecture docs
/docs:manage-architecture --command=validate

# Reindex all architecture documentation
/docs:manage-architecture --command=reindex
```
</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from command line:
- `title`: Optional document title (first positional argument, quoted if multi-word)
- `command`: Operation to perform (from --command flag, default: "list")

Validation:
- If `title` provided, verify it's not empty
- Verify `command` is one of: create, update, list, validate, reindex
- If `command` is "create" or "update", `title` is required

## Step 2: Determine Operation

**Default behavior** (no arguments):
- Operation: `list`
- Target: All architecture documents

**With title only** (no --command):
- Operation: `list`
- Target: Specific document (if exists)

**With --command only** (no title):
- Operation: Specified command
- Target: All documents (for list/validate/reindex)
- Error: If command requires title (create/update)

**With both title and --command**:
- Operation: Specified command
- Target: Specified document

## Step 3: Invoke docs-manage-architecture Skill

Use the Skill tool to invoke the docs-manage-architecture skill with the parsed parameters.

**Invocation syntax**:
```
Skill(skill="docs-manage-architecture")
```

Then immediately state the operation request in natural language based on the parsed command:

**For create operation**:
```
Use the docs-manage-architecture skill to create architecture documentation with the following parameters:
{
  "operation": "create",
  "title": "System Architecture Overview",
  "project_root": "/path/to/project"
}
```

**For list operation**:
```
Use the docs-manage-architecture skill to list architecture documentation with the following parameters:
{
  "operation": "list",
  "title": null,
  "project_root": "/path/to/project"
}
```

**For update operation**:
```
Use the docs-manage-architecture skill to update architecture documentation with the following parameters:
{
  "operation": "update",
  "title": "System Architecture Overview",
  "project_root": "/path/to/project"
}
```

**For validate operation**:
```
Use the docs-manage-architecture skill to validate architecture documentation with the following parameters:
{
  "operation": "validate",
  "title": "System Architecture Overview",
  "project_root": "/path/to/project"
}
```

**For reindex operation**:
```
Use the docs-manage-architecture skill to reindex architecture documentation with the following parameters:
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

Usage: /docs:manage-architecture "<title>" --command=create
Example: /docs:manage-architecture "System Architecture Overview" --command=create
```

**Invalid command**:
```
❌ Error: Invalid command: <command>

Valid commands: create, update, list, validate, reindex
```

**Empty title**:
```
❌ Error: title cannot be empty

Usage: /docs:manage-architecture "<title>" --command=<operation>
```

**Skill invocation failed**:
```
❌ Architecture documentation management failed

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
