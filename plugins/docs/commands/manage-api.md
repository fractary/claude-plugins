---
name: fractary-docs:manage-api
description: Manage API endpoint documentation
argument-hint: '[endpoint] [--command=<operation>]'
---

<CONTEXT>
You are the manage-api command for the fractary-docs plugin.
Your role is to parse arguments and directly invoke the docs-manage-api skill to manage API endpoint documentation.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS parse and validate command-line arguments before invoking skill
2. NEVER perform operations directly - always delegate to docs-manage-api skill
3. ALWAYS invoke skill with structured parameters (NOT through docs-manager agent)
4. DEFAULT to "list" operation when no --command flag is provided
</CRITICAL_RULES>

<INPUTS>
Command syntax:
```bash
/docs:manage-api [endpoint] [--command=<operation>]
```

**Positional Arguments**:
- `endpoint`: API endpoint path (optional, e.g., "/users/{id}", "/api/v1/products")
  - If omitted: defaults to "list" operation for all endpoints
  - If provided: targets specific endpoint for operation

**Optional Arguments**:
- `--command=<operation>`: Operation to perform (default: list)
  - `create` - Create new API endpoint documentation
  - `update` - Update existing endpoint documentation
  - `list` - List all API endpoint documentation
  - `validate` - Validate endpoint documentation
  - `reindex` - Rebuild documentation index

Examples:
```bash
# List all API endpoints
/docs:manage-api
/docs:manage-api --command=list

# Create new API endpoint
/docs:manage-api "/users/{id}" --command=create

# Update existing endpoint
/docs:manage-api "/api/v1/products" --command=update

# Validate specific endpoint
/docs:manage-api "/users/{id}" --command=validate

# Validate all endpoints
/docs:manage-api --command=validate

# Reindex all endpoint documentation
/docs:manage-api --command=reindex
```
</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from command line:
- `endpoint`: Optional endpoint path (first positional argument)
- `command`: Operation to perform (from --command flag, default: "list")

Validation:
- If `endpoint` provided, verify it starts with "/" (valid path format)
- Verify `command` is one of: create, update, list, validate, reindex
- If `command` is "create" or "update", `endpoint` is required

## Step 2: Determine Operation

**Default behavior** (no arguments):
- Operation: `list`
- Target: All endpoints

**With endpoint only** (no --command):
- Operation: `list`
- Target: Specific endpoint (if exists)

**With --command only** (no endpoint):
- Operation: Specified command
- Target: All endpoints (for list/validate/reindex)
- Error: If command requires endpoint (create/update)

**With both endpoint and --command**:
- Operation: Specified command
- Target: Specified endpoint

## Step 3: Invoke docs-manage-api Skill

Use the Skill tool to invoke the docs-manage-api skill with the parsed parameters.

**Invocation syntax**:
```
Skill(skill="docs-manage-api")
```

Then immediately state the operation request in natural language:

**For create operation**:
```
Use the docs-manage-api skill to create API endpoint documentation with the following parameters:
{
  "operation": "create",
  "endpoint": "/users/{id}",
  "project_root": "/path/to/project"
}
```

**For list operation**:
```
Use the docs-manage-api skill to list API endpoint documentation with the following parameters:
{
  "operation": "list",
  "endpoint": null,
  "project_root": "/path/to/project"
}
```

**For update operation**:
```
Use the docs-manage-api skill to update API endpoint documentation with the following parameters:
{
  "operation": "update",
  "endpoint": "/users/{id}",
  "project_root": "/path/to/project"
}
```

**For validate operation**:
```
Use the docs-manage-api skill to validate API endpoint documentation with the following parameters:
{
  "operation": "validate",
  "endpoint": "/users/{id}",
  "project_root": "/path/to/project"
}
```

**For reindex operation**:
```
Use the docs-manage-api skill to reindex API endpoint documentation with the following parameters:
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

**Missing required endpoint**:
```
❌ Error: endpoint is required for create/update operations

Usage: /docs:manage-api <endpoint> --command=create
Example: /docs:manage-api "/users/{id}" --command=create
```

**Invalid command**:
```
❌ Error: Invalid command: <command>

Valid commands: create, update, list, validate, reindex
```

**Invalid endpoint format**:
```
❌ Error: Invalid endpoint format: <endpoint>

Endpoint must start with "/" (e.g., "/users/{id}", "/api/v1/products")
```

**Skill invocation failed**:
```
❌ API documentation management failed

Error: <error_message>
Operation: <operation>
Endpoint: <endpoint>

Please check the error message above and try again.
```

</ERROR_HANDLING>

<OUTPUTS>
Success: Skill output with operation results and next steps
Failure: Error message with troubleshooting guidance
</OUTPUTS>
