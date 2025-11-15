---
name: fractary-docs:manage-testing
description: Manage testing/QA documentation (test plans, results, validation, benchmarks)
argument-hint: '[test-suite-name] [--command=<operation>]'
---

<CONTEXT>
You are the manage-testing command for the fractary-docs plugin.
Your role is to parse arguments and directly invoke the docs-manage-testing skill to manage testing and QA documentation.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS parse and validate command-line arguments before invoking skill
2. NEVER perform operations directly - always delegate to docs-manage-testing skill
3. ALWAYS invoke skill with structured parameters (NOT through docs-manager agent)
4. DEFAULT to "list" operation when no --command flag is provided
</CRITICAL_RULES>

<INPUTS>
Command syntax:
```bash
/docs:manage-testing [test-suite-name] [--command=<operation>]
```

**Positional Arguments**:
- `test-suite-name`: Test suite name or path (optional, e.g., "api-integration-tests", "ui/e2e-tests")
  - If omitted: defaults to "list" operation for all test suites
  - If provided: targets specific test suite for operation
  - Format: lowercase alphanumeric with hyphens and slashes

**Optional Flags**:
- `--command=<operation>`: Operation to perform (default: list)
  - `create` - Create new testing documentation
  - `update` - Update existing testing documentation
  - `list` - List all testing documentation
  - `validate` - Validate testing documentation
  - `reindex` - Rebuild documentation index

Examples:
```bash
# List all test suites
/docs:manage-testing

# Create new test suite docs
/docs:manage-testing api-integration-tests --command=create

# Create nested test suite
/docs:manage-testing ui/e2e-tests --command=create

# Update existing test suite (add new results)
/docs:manage-testing api-integration-tests --command=update

# Validate specific test suite
/docs:manage-testing api-integration-tests --command=validate

# Validate all test suites
/docs:manage-testing --command=validate

# Reindex all documentation
/docs:manage-testing --command=reindex
```
</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from command line:
- `test_suite_name`: Optional test suite identifier (first positional argument)
- `command`: Operation to perform (from --command flag, default: "list")

Validation:
- If `test_suite_name` provided, verify it matches pattern: `^[a-z0-9-/]+$`
- Verify `command` is one of: create, update, list, validate, reindex

## Step 2: Determine Operation

**Default behavior** (no arguments):
- Operation: `list`
- Target: All test suites

**With test-suite-name only** (no --command):
- Operation: `list`
- Target: Specific test suite (if exists)

**With --command only** (no test-suite-name):
- Operation: Specified command
- Target: All test suites (for list/validate/reindex)
- Error: If command requires test-suite-name (create/update)

**With both test-suite-name and --command**:
- Operation: Specified command
- Target: Specified test suite

## Step 3: Invoke docs-manage-testing Skill

Use the Skill tool to invoke the docs-manage-testing skill with the parsed parameters.

**Invocation syntax**:
```
Skill(skill="docs-manage-testing")
```

Then immediately state the operation request in natural language based on the parsed command:

**For create operation**:
```
Use the docs-manage-testing skill to create testing documentation with the following parameters:
{
  "operation": "create",
  "test_suite_name": "api-integration-tests",
  "project_root": "/path/to/project"
}
```

**For list operation (all)**:
```
Use the docs-manage-testing skill to list test suites with the following parameters:
{
  "operation": "list",
  "project_root": "/path/to/project"
}
```

**For list operation (specific)**:
```
Use the docs-manage-testing skill to list test suite with the following parameters:
{
  "operation": "list",
  "test_suite_name": "api-integration-tests",
  "project_root": "/path/to/project"
}
```

**For update operation**:
```
Use the docs-manage-testing skill to update testing documentation with the following parameters:
{
  "operation": "update",
  "test_suite_name": "api-integration-tests",
  "project_root": "/path/to/project"
}
```

**For validate operation (specific)**:
```
Use the docs-manage-testing skill to validate testing documentation with the following parameters:
{
  "operation": "validate",
  "test_suite_name": "api-integration-tests",
  "project_root": "/path/to/project"
}
```

**For validate operation (all)**:
```
Use the docs-manage-testing skill to validate all testing documentation with the following parameters:
{
  "operation": "validate",
  "project_root": "/path/to/project"
}
```

**For reindex operation**:
```
Use the docs-manage-testing skill to reindex testing documentation with the following parameters:
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
- Test results summary (if applicable)
- Validation results (if applicable)
- Next steps

</WORKFLOW>

<ERROR_HANDLING>

**Missing required test-suite-name**:
```
❌ Error: test-suite-name is required for create/update operations

Usage: /docs:manage-testing <test-suite-name> --command=create
Example: /docs:manage-testing api-integration-tests --command=create
```

**Invalid command**:
```
❌ Error: Invalid command: <command>

Valid commands: create, update, list, validate, reindex
```

**Invalid test-suite-name format**:
```
❌ Error: Invalid test-suite-name format: <test-suite-name>

Test suite name must contain only lowercase letters, numbers, hyphens, and slashes
Examples: api-integration-tests, ui/e2e-tests, performance/load-tests
```

**Skill invocation failed**:
```
❌ Testing documentation management failed

Error: <error_message>
Operation: <operation>
Test Suite: <test-suite-name>

Please check the error message above and try again.
```

</ERROR_HANDLING>

<OUTPUTS>
Success: Skill output with operation results and next steps
Failure: Error message with troubleshooting guidance
</OUTPUTS>
