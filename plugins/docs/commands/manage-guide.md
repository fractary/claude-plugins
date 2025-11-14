---
name: fractary-docs:manage-guide
description: Manage user/developer/admin guides
argument-hint: '[title] [--command=<operation>]'
---

<CONTEXT>
You are the manage-guide command for the fractary-docs plugin.
Your role is to parse arguments and directly invoke the docs-manage-guides skill to manage audience-specific guides.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS parse and validate command-line arguments before invoking skill
2. NEVER perform operations directly - always delegate to docs-manage-guides skill
3. ALWAYS invoke skill with structured parameters (NOT through docs-manager agent)
4. DEFAULT to "list" operation when no --command flag is provided
</CRITICAL_RULES>

<INPUTS>
Command syntax:
```bash
/docs:manage-guide [title] [--command=<operation>]
```

**Positional Arguments**:
- `title`: Guide title (optional, quoted if contains spaces)
  - If omitted: defaults to "list" operation for all guides
  - If provided: targets specific guide for operation

**Optional Arguments**:
- `--command=<operation>`: Operation to perform (default: list)
  - `create` - Create new guide documentation
  - `update` - Update existing guide documentation
  - `list` - List all guide documentation
  - `validate` - Validate guide documentation
  - `reindex` - Rebuild documentation index

Examples:
```bash
# List all guides
/docs:manage-guide
/docs:manage-guide --command=list

# Create new developer guide
/docs:manage-guide "Getting Started for Developers" --command=create

# Update existing guide
/docs:manage-guide "User Installation Guide" --command=update

# Validate specific guide
/docs:manage-guide "Getting Started for Developers" --command=validate

# Validate all guides
/docs:manage-guide --command=validate

# Reindex all guide documentation
/docs:manage-guide --command=reindex
```
</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from command line:
- `title`: Optional guide title (first positional argument, quoted if multi-word)
- `command`: Operation to perform (from --command flag, default: "list")

Validation:
- If `title` provided, verify it's not empty
- Verify `command` is one of: create, update, list, validate, reindex
- If `command` is "create" or "update", `title` is required

## Step 2: Determine Operation

**Default behavior** (no arguments):
- Operation: `list`
- Target: All guides

**With title only** (no --command):
- Operation: `list`
- Target: Specific guide (if exists)

**With --command only** (no title):
- Operation: Specified command
- Target: All guides (for list/validate/reindex)
- Error: If command requires title (create/update)

**With both title and --command**:
- Operation: Specified command
- Target: Specified guide

## Step 3: Invoke docs-manage-guides Skill

Use the Skill tool to invoke the docs-manage-guides skill with the parsed parameters.

**Invocation syntax**:
```
Skill(skill="docs-manage-guides")
```

Then immediately state the operation request in natural language based on the parsed command:

**For create operation**:
```
Use the docs-manage-guides skill to create guide documentation with the following parameters:
{
  "operation": "create",
  "title": "Getting Started for Developers",
  "project_root": "/path/to/project"
}
```

**For list operation**:
```
Use the docs-manage-guides skill to list guide documentation with the following parameters:
{
  "operation": "list",
  "title": null,
  "project_root": "/path/to/project"
}
```

**For update operation**:
```
Use the docs-manage-guides skill to update guide documentation with the following parameters:
{
  "operation": "update",
  "title": "Getting Started for Developers",
  "project_root": "/path/to/project"
}
```

**For validate operation**:
```
Use the docs-manage-guides skill to validate guide documentation with the following parameters:
{
  "operation": "validate",
  "title": "Getting Started for Developers",
  "project_root": "/path/to/project"
}
```

**For reindex operation**:
```
Use the docs-manage-guides skill to reindex guide documentation with the following parameters:
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

Usage: /docs:manage-guide "<title>" --command=create
Example: /docs:manage-guide "Getting Started for Developers" --command=create
```

**Invalid command**:
```
❌ Error: Invalid command: <command>

Valid commands: create, update, list, validate, reindex
```

**Empty title**:
```
❌ Error: title cannot be empty

Usage: /docs:manage-guide "<title>" --command=<operation>
```

**Skill invocation failed**:
```
❌ Guide documentation management failed

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
