---
name: fractary-docs:manage-schema
description: Manage data schema documentation
argument-hint: '[dataset] [--command=<operation>]'
---

<CONTEXT>
You are the manage-schema command for the fractary-docs plugin.
Your role is to parse arguments and directly invoke the docs-manage-schema skill to manage data schema documentation.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS parse and validate command-line arguments before invoking skill
2. NEVER perform operations directly - always delegate to docs-manage-schema skill
3. ALWAYS invoke skill with structured parameters (NOT through docs-manager agent)
4. DEFAULT to "list" operation when no --command flag is provided
</CRITICAL_RULES>

<INPUTS>
Command syntax:
```bash
/docs:manage-schema [dataset] [--command=<operation>]
```

**Positional Arguments**:
- `dataset`: Dataset name or path (optional, e.g., "user", "user/profile", "api/request")
  - If omitted: defaults to "list" operation for all schemas
  - If provided: targets specific schema for operation

**Optional Arguments**:
- `--command=<operation>`: Operation to perform (default: list)
  - `create` - Create new schema documentation
  - `update` - Update existing schema documentation
  - `list` - List all schema documentation
  - `validate` - Validate schema documentation
  - `reindex` - Rebuild documentation index

Examples:
```bash
# List all schemas
/docs:manage-schema
/docs:manage-schema --command=list

# Create new schema
/docs:manage-schema user --command=create

# Update existing schema
/docs:manage-schema user/profile --command=update

# Validate specific schema
/docs:manage-schema user --command=validate

# Validate all schemas
/docs:manage-schema --command=validate

# Reindex all schema documentation
/docs:manage-schema --command=reindex
```
</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from command line:
- `dataset`: Optional dataset name/path (first positional argument)
- `command`: Operation to perform (from --command flag, default: "list")

Validation:
- If `dataset` provided, verify it's not empty and follows valid naming (alphanumeric, hyphens, underscores, slashes)
- Verify `command` is one of: create, update, list, validate, reindex
- If `command` is "create" or "update", `dataset` is required

## Step 2: Determine Operation

**Default behavior** (no arguments):
- Operation: `list`
- Target: All schemas

**With dataset only** (no --command):
- Operation: `list`
- Target: Specific schema (if exists)

**With --command only** (no dataset):
- Operation: Specified command
- Target: All schemas (for list/validate/reindex)
- Error: If command requires dataset (create/update)

**With both dataset and --command**:
- Operation: Specified command
- Target: Specified schema

## Step 3: Invoke docs-manage-schema Skill

Invoke the docs-manage-schema skill directly with structured request:

```json
{
  "operation": "<create|update|list|validate|reindex>",
  "dataset": "<dataset name or null for all>",
  "project_root": "<current directory>"
}
```

**Example for create**:
```
Use the docs-manage-schema skill to create schema documentation:
{
  "operation": "create",
  "dataset": "user/profile",
  "project_root": "/path/to/project"
}
```

**Example for list all**:
```
Use the docs-manage-schema skill to list all schema documentation:
{
  "operation": "list",
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

**Missing required dataset**:
```
❌ Error: dataset is required for create/update operations

Usage: /docs:manage-schema <dataset> --command=create
Example: /docs:manage-schema user/profile --command=create
```

**Invalid command**:
```
❌ Error: Invalid command: <command>

Valid commands: create, update, list, validate, reindex
```

**Invalid dataset format**:
```
❌ Error: Invalid dataset format: <dataset>

Dataset should contain only alphanumeric characters, hyphens, underscores, and slashes
Examples: user, user/profile, api/request
```

**Skill invocation failed**:
```
❌ Schema documentation management failed

Error: <error_message>
Operation: <operation>
Dataset: <dataset>

Please check the error message above and try again.
```

</ERROR_HANDLING>

<OUTPUTS>
Success: Skill output with operation results and next steps
Failure: Error message with troubleshooting guidance
</OUTPUTS>
