---
name: fractary-docs:manage-etl
description: Manage ETL/data pipeline documentation
argument-hint: '[pipeline-name] [--command=<operation>]'
---

<CONTEXT>
You are the manage-etl command for the fractary-docs plugin.
Your role is to parse arguments and directly invoke the docs-manage-etl skill to manage ETL/data pipeline documentation.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS parse and validate command-line arguments before invoking skill
2. NEVER perform operations directly - always delegate to docs-manage-etl skill
3. ALWAYS invoke skill with structured parameters (NOT through docs-manager agent)
4. DEFAULT to "list" operation when no --command flag is provided
</CRITICAL_RULES>

<INPUTS>
Command syntax:
```bash
/docs:manage-etl [pipeline-name] [--command=<operation>]
```

**Positional Arguments**:
- `pipeline-name`: ETL pipeline name or path (optional, e.g., "daily-user-aggregation", "analytics/events-processor")
  - If omitted: defaults to "list" operation for all ETL pipelines
  - If provided: targets specific pipeline for operation
  - Format: lowercase alphanumeric with hyphens and slashes

**Optional Flags**:
- `--command=<operation>`: Operation to perform (default: list)
  - `create` - Create new ETL documentation
  - `update` - Update existing ETL documentation
  - `list` - List all ETL documentation
  - `validate` - Validate ETL documentation
  - `reindex` - Rebuild documentation index

Examples:
```bash
# List all ETL pipelines
/docs:manage-etl

# Create new pipeline docs
/docs:manage-etl daily-user-aggregation --command=create

# Create nested pipeline docs
/docs:manage-etl analytics/events-processor --command=create

# Update existing pipeline
/docs:manage-etl daily-user-aggregation --command=update

# Validate specific pipeline
/docs:manage-etl daily-user-aggregation --command=validate

# Validate all pipelines
/docs:manage-etl --command=validate

# Reindex all documentation
/docs:manage-etl --command=reindex
```
</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from command line:
- `pipeline_name`: Optional pipeline identifier (first positional argument)
- `command`: Operation to perform (from --command flag, default: "list")

Validation:
- If `pipeline_name` provided, verify it matches pattern: `^[a-z0-9-/]+$`
- Verify `command` is one of: create, update, list, validate, reindex

## Step 2: Determine Operation

**Default behavior** (no arguments):
- Operation: `list`
- Target: All ETL pipelines

**With pipeline-name only** (no --command):
- Operation: `list`
- Target: Specific pipeline (if exists)

**With --command only** (no pipeline-name):
- Operation: Specified command
- Target: All pipelines (for list/validate/reindex)
- Error: If command requires pipeline-name (create/update)

**With both pipeline-name and --command**:
- Operation: Specified command
- Target: Specified pipeline

## Step 3: Invoke docs-manage-etl Skill

Use the Skill tool to invoke the docs-manage-etl skill with the parsed parameters.

**Invocation syntax**:
```
Skill(skill="docs-manage-etl")
```

Then immediately state the operation request in natural language based on the parsed command:

**For create operation**:
```
Use the docs-manage-etl skill to create ETL documentation with the following parameters:
{
  "operation": "create",
  "pipeline_name": "daily-user-aggregation",
  "project_root": "/path/to/project"
}
```

**For list operation (all)**:
```
Use the docs-manage-etl skill to list ETL pipelines with the following parameters:
{
  "operation": "list",
  "project_root": "/path/to/project"
}
```

**For list operation (specific)**:
```
Use the docs-manage-etl skill to list ETL pipeline with the following parameters:
{
  "operation": "list",
  "pipeline_name": "daily-user-aggregation",
  "project_root": "/path/to/project"
}
```

**For update operation**:
```
Use the docs-manage-etl skill to update ETL documentation with the following parameters:
{
  "operation": "update",
  "pipeline_name": "daily-user-aggregation",
  "project_root": "/path/to/project"
}
```

**For validate operation (specific)**:
```
Use the docs-manage-etl skill to validate ETL documentation with the following parameters:
{
  "operation": "validate",
  "pipeline_name": "daily-user-aggregation",
  "project_root": "/path/to/project"
}
```

**For validate operation (all)**:
```
Use the docs-manage-etl skill to validate all ETL documentation with the following parameters:
{
  "operation": "validate",
  "project_root": "/path/to/project"
}
```

**For reindex operation**:
```
Use the docs-manage-etl skill to reindex ETL documentation with the following parameters:
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

**Missing required pipeline-name**:
```
❌ Error: pipeline-name is required for create/update operations

Usage: /docs:manage-etl <pipeline-name> --command=create
Example: /docs:manage-etl daily-user-aggregation --command=create
```

**Invalid command**:
```
❌ Error: Invalid command: <command>

Valid commands: create, update, list, validate, reindex
```

**Invalid pipeline-name format**:
```
❌ Error: Invalid pipeline-name format: <pipeline-name>

Pipeline name must contain only lowercase letters, numbers, hyphens, and slashes
Examples: daily-user-aggregation, analytics/events-processor
```

**Skill invocation failed**:
```
❌ ETL documentation management failed

Error: <error_message>
Operation: <operation>
Pipeline: <pipeline-name>

Please check the error message above and try again.
```

</ERROR_HANDLING>

<OUTPUTS>
Success: Skill output with operation results and next steps
Failure: Error message with troubleshooting guidance
</OUTPUTS>
