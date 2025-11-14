---
name: fractary-docs:manage-audit
description: Manage audit reports and health dashboards
argument-hint: '[audit-id] [--command=<operation>] [--type=<audit-type>] [--status=<status>]'
---

<CONTEXT>
You are the manage-audit command for the fractary-docs plugin.
Your role is to parse arguments and directly invoke the docs-manage-audit skill to manage audit reports and health dashboards.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS parse and validate command-line arguments before invoking skill
2. NEVER perform operations directly - always delegate to docs-manage-audit skill
3. ALWAYS invoke skill with structured parameters (NOT through docs-manager agent)
4. DEFAULT to "list" operation when no --command flag is provided
5. SUPPORT filtering by type, status, environment, and date range
</CRITICAL_RULES>

<INPUTS>
Command syntax:
```bash
/docs:manage-audit [audit-id] [--command=<operation>] [--type=<audit-type>] [--status=<status>] [--environment=<env>] [--since=<date>]
```

**Positional Arguments**:
- `audit-id`: Audit identifier (optional, e.g., "2025-01-15-config-valid", "infra-audit-20250115")
  - If omitted: defaults to "list" operation for all audits
  - If provided: targets specific audit for operation
  - Format: typically `{timestamp}-{check-type}` or `{type}-{timestamp}`

**Optional Flags**:
- `--command=<operation>`: Operation to perform (default: list)
  - `create` - Create new audit report
  - `update` - Update existing audit report
  - `list` - List all audit reports
  - `validate` - Validate audit report
  - `reindex` - Rebuild audit index

- `--type=<audit-type>`: Filter by audit type
  - Values: infrastructure, documentation, logs, system, architecture, security, cost, compliance, performance, quality
  - Used for filtering in list operation
  - Required for create operation

- `--status=<status>`: Filter by overall status
  - Values: pass, warning, error, critical, healthy, degraded, unhealthy
  - Used for filtering in list operation

- `--environment=<env>`: Filter by environment
  - Values: dev, staging, prod, test, demo
  - Used for filtering and context

- `--since=<date>`: Filter audits since date
  - Format: YYYY-MM-DD or relative (e.g., "7d", "30d", "1h")
  - Used for filtering in list operation

Examples:
```bash
# List all audit reports
/docs:manage-audit

# List infrastructure audits
/docs:manage-audit --type=infrastructure

# List failed audits
/docs:manage-audit --status=error

# List production audits from last 7 days
/docs:manage-audit --environment=prod --since=7d

# List critical findings
/docs:manage-audit --status=critical

# Create new infrastructure audit
/docs:manage-audit --command=create --type=infrastructure

# Create documentation audit
/docs:manage-audit --command=create --type=documentation

# Update specific audit
/docs:manage-audit 2025-01-15-config-valid --command=update

# Validate specific audit
/docs:manage-audit infra-audit-20250115 --command=validate

# Validate all audits
/docs:manage-audit --command=validate

# Reindex all audit reports
/docs:manage-audit --command=reindex
```
</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from command line:
- `audit_id`: Optional audit identifier (first positional argument)
- `command`: Operation to perform (from --command flag, default: "list")
- `type`: Audit type (from --type flag)
- `status`: Filter by status (from --status flag)
- `environment`: Filter by environment (from --environment flag)
- `since`: Filter by date (from --since flag)

Validation:
- Verify `command` is one of: create, update, list, validate, reindex
- If `command` is "create", `type` is REQUIRED
- Verify `type` is valid audit type (if provided)
- Verify `status` is valid status value (if provided)
- Verify `environment` is valid environment (if provided)

## Step 2: Determine Operation

**Default behavior** (no arguments):
- Operation: `list`
- Target: All audit reports

**With audit-id only** (no --command):
- Operation: `list`
- Target: Specific audit (if exists)

**With --command only** (no audit-id):
- Operation: Specified command
- Target: All audits (for list/validate/reindex)
- Target: New audit (for create)
- Error: If update requires audit-id

**With filters** (--type, --status, --environment, --since):
- Operation: `list` (default)
- Target: Filtered subset of audits

**With both audit-id and --command**:
- Operation: Specified command
- Target: Specified audit

## Step 3: Invoke docs-manage-audit Skill

Use the Skill tool to invoke the docs-manage-audit skill with the parsed parameters.

**Invocation syntax**:
```
Skill(skill="docs-manage-audit")
```

Then immediately state the operation request in natural language based on the parsed command:

**For create operation**:
```
Use the docs-manage-audit skill to create an audit report with the following parameters:
{
  "operation": "create",
  "audit_type": "infrastructure",
  "check_type": "config-valid",
  "environment": "prod",
  "project_root": "/path/to/project"
}
```

**For list operation (all)**:
```
Use the docs-manage-audit skill to list all audit reports with the following parameters:
{
  "operation": "list",
  "project_root": "/path/to/project"
}
```

**For list operation (filtered)**:
```
Use the docs-manage-audit skill to list audit reports with the following parameters:
{
  "operation": "list",
  "filters": {
    "type": "infrastructure",
    "status": "error",
    "environment": "prod",
    "since": "7d"
  },
  "project_root": "/path/to/project"
}
```

**For update operation**:
```
Use the docs-manage-audit skill to update an audit report with the following parameters:
{
  "operation": "update",
  "audit_id": "2025-01-15-config-valid",
  "project_root": "/path/to/project"
}
```

**For validate operation (specific)**:
```
Use the docs-manage-audit skill to validate an audit report with the following parameters:
{
  "operation": "validate",
  "audit_id": "infra-audit-20250115",
  "project_root": "/path/to/project"
}
```

**For validate operation (all)**:
```
Use the docs-manage-audit skill to validate all audit reports with the following parameters:
{
  "operation": "validate",
  "project_root": "/path/to/project"
}
```

**For reindex operation**:
```
Use the docs-manage-audit skill to reindex audit reports with the following parameters:
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
- Audit summary (status, counts, findings)
- Validation results (if applicable)
- Next steps

</WORKFLOW>

<ERROR_HANDLING>

**Missing required audit-id**:
```
❌ Error: audit-id is required for update operation

Usage: /docs:manage-audit <audit-id> --command=update
Example: /docs:manage-audit 2025-01-15-config-valid --command=update
```

**Missing required type**:
```
❌ Error: --type flag is required for create operation

Usage: /docs:manage-audit --command=create --type=<audit-type>
Valid types: infrastructure, documentation, logs, system, architecture, security, cost, compliance, performance, quality
Example: /docs:manage-audit --command=create --type=infrastructure
```

**Invalid command**:
```
❌ Error: Invalid command: <command>

Valid commands: create, update, list, validate, reindex
```

**Invalid audit type**:
```
❌ Error: Invalid audit type: <type>

Valid types: infrastructure, documentation, logs, system, architecture, security, cost, compliance, performance, quality
```

**Invalid status**:
```
❌ Error: Invalid status: <status>

Valid statuses: pass, warning, error, critical, healthy, degraded, unhealthy
```

**Invalid environment**:
```
❌ Error: Invalid environment: <environment>

Valid environments: dev, staging, prod, test, demo
```

**Skill invocation failed**:
```
❌ Audit management failed

Error: <error_message>
Operation: <operation>
Audit: <audit-id>
Type: <type>

Please check the error message above and try again.
```

</ERROR_HANDLING>

<INTEGRATION_NOTES>

## Plugin Integrations

This command standardizes audit reporting across multiple plugins:

**faber-cloud/infra-auditor**:
```bash
# After infrastructure audit
/docs:manage-audit --command=create --type=infrastructure --environment=prod
```

**helm-cloud/ops-auditor**:
```bash
# After operational health check
/docs:manage-audit --command=create --type=system
```

**docs/doc-auditor**:
```bash
# After documentation audit
/docs:manage-audit --command=create --type=documentation
```

**logs/log-auditor**:
```bash
# After log audit
/docs:manage-audit --command=create --type=logs
```

**codex/cache-health**:
```bash
# After cache health check
/docs:manage-audit --command=create --type=system
```

**faber-agent/project-auditor**:
```bash
# After architecture audit
/docs:manage-audit --command=create --type=architecture
```

**Typical Workflow**:
1. Plugin performs audit/health check
2. Plugin generates findings, metrics, recommendations
3. Plugin calls `/docs:manage-audit --command=create --type={audit-type}`
4. docs-manage-audit skill creates dual-format report (README.md + audit.json)
5. Report stored in `docs/audits/{type}/{audit-id}/`

**Retention and Archival** (via logs plugin):
- Ephemeral audits: Subject to retention policies (default: 90 days)
- Persistent audits: Manually promoted, retained indefinitely
- Integration: logs-manager handles archival and cleanup

**Remediation Tracking** (via work/spec plugins):
- Critical findings → GitHub issues (via work-manager)
- Complex remediation → Specification documents (via spec-manager)
- Tracking via `metadata.tracking_issue_url` in audit.json

</INTEGRATION_NOTES>

<OUTPUTS>
Success: Skill output with operation results and next steps
Failure: Error message with troubleshooting guidance
</OUTPUTS>
