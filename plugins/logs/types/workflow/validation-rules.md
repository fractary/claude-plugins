# Workflow Log Validation Rules

This document defines validation rules for workflow logs. Rules are organized by validation type and severity.

---

## Frontmatter Validation

### ✅ MUST Rules (Critical)

1. **log_type field**
   - MUST be present
   - MUST equal "workflow"
   - **Error**: "Missing or invalid log_type field"
   - **Fix**: Add `log_type: workflow` to frontmatter

2. **workflow_id field**
   - MUST be present
   - MUST match pattern: `workflow-[a-z0-9-]+`
   - MUST be unique across all workflow logs for the same execution
   - **Error**: "Missing or invalid workflow_id"
   - **Fix**: Add unique ID like `workflow-123-20250117T100000Z`

3. **timestamp field**
   - MUST be present
   - MUST be valid ISO 8601 timestamp
   - **Error**: "Missing or invalid timestamp"
   - **Fix**: Use format `2025-01-17T10:00:00Z`

4. **status field**
   - MUST be present
   - MUST be one of: pending, running, success, failure, partial, cancelled, archived
   - **Error**: "Missing or invalid status value"
   - **Fix**: Set status to valid enum value

5. **title field**
   - MUST be present
   - MUST be non-empty string
   - **Error**: "Missing or empty title"
   - **Fix**: Add descriptive title like "FABER Workflow - Feature #123"

### ⚠️ SHOULD Rules (Warnings)

1. **work_item_id field**
   - SHOULD be present for FABER workflows
   - **Warning**: "No work item linked to workflow"
   - **Fix**: Add work_item_id if workflow relates to an issue/ticket

2. **phase field**
   - SHOULD be present for multi-phase workflows
   - **Warning**: "No phase specified"
   - **Fix**: Add current phase (Frame, Architect, Build, etc.)

3. **workflow_type field**
   - SHOULD specify workflow type (faber, etl, custom)
   - **Warning**: "Workflow type not specified"
   - **Fix**: Add workflow_type for better classification

4. **operations array**
   - SHOULD be non-empty for completed workflows
   - **Warning**: "No operations recorded"
   - **Fix**: Add operations array with executed steps

---

## Structure Validation

### ✅ MUST Rules

1. **Frontmatter delimiter**
   - MUST start with `---`
   - MUST end with `---`
   - **Error**: "Invalid or missing frontmatter delimiters"
   - **Fix**: Ensure frontmatter is enclosed in `---` markers

2. **Execution summary section**
   - MUST include workflow overview
   - MUST show current status
   - **Error**: "Missing execution summary"
   - **Fix**: Add summary section with key workflow details

3. **Timestamp consistency**
   - Operation timestamps MUST be after workflow start timestamp
   - **Error**: "Operation timestamp before workflow start"
   - **Fix**: Ensure operations are chronologically ordered

### ⚠️ SHOULD Rules

1. **Operations timeline**
   - SHOULD be in chronological order
   - **Warning**: "Operations not in time order"
   - **Fix**: Sort operations by timestamp

2. **Context section**
   - SHOULD include execution context (project, repo, environment)
   - **Warning**: "Missing execution context"
   - **Fix**: Add context object with project details

3. **Metrics section**
   - SHOULD include performance metrics for completed workflows
   - **Warning**: "No performance metrics recorded"
   - **Fix**: Add metrics (duration, operation count, success rate)

---

## Content Validation

### ✅ MUST Rules

1. **Operation structure**
   - Each operation MUST have: timestamp, operation, status
   - **Error**: "Invalid operation structure"
   - **Fix**: Ensure all operations have required fields

2. **Status consistency**
   - If status is "success", all operations SHOULD be completed or skipped
   - If status is "failure", at least one operation SHOULD be failed
   - **Error**: "Status inconsistent with operations"
   - **Fix**: Update status to match operation results

3. **No sensitive data**
   - MUST NOT contain credentials, API keys, tokens
   - MUST NOT contain PII or actual data values
   - **Error**: "Sensitive data detected in workflow log"
   - **Fix**: Redact credentials and PII

4. **Valid phase names**
   - For FABER workflows: Frame, Architect, Build, Evaluate, Release
   - For ETL workflows: Extract, Transform, Load, Validate
   - **Error**: "Invalid phase name for workflow type"
   - **Fix**: Use standard phase names

5. **Timestamp format**
   - All timestamps MUST be ISO 8601 format
   - **Error**: "Invalid timestamp format"
   - **Fix**: Use `YYYY-MM-DDTHH:MM:SSZ` format

### ⚠️ SHOULD Rules

1. **Operation targets**
   - Operations SHOULD specify what they acted upon
   - **Warning**: "Operation missing target specification"
   - **Fix**: Add target field to operations

2. **Duration tracking**
   - Operations SHOULD include duration_ms when completed
   - **Warning**: "Operation duration not recorded"
   - **Fix**: Add duration_ms to completed operations

3. **Error context**
   - Failed operations SHOULD include error details
   - **Warning**: "Failed operation without error context"
   - **Fix**: Add output or error message to failed operations

4. **Artifact documentation**
   - SHOULD list all artifacts created
   - **Warning**: "Artifacts created but not documented"
   - **Fix**: Add artifacts array with created files

5. **Decision logging**
   - SHOULD document key decisions made during execution
   - **Warning**: "No decisions logged"
   - **Fix**: Add decisions array for major choices

---

## Workflow-Specific Validation

### FABER Workflows

1. **Phase progression**
   - MUST follow order: Frame → Architect → Build → Evaluate → Release
   - **Error**: "Invalid FABER phase progression"
   - **Fix**: Ensure phases executed in correct order

2. **Required operations**
   - Frame MUST include: fetch_work_item
   - Architect MUST include: create_spec or design_solution
   - Build MUST include: implement or execute
   - **Error**: "Missing required FABER operation"
   - **Fix**: Add required operation for phase

3. **Work item linkage**
   - MUST have work_item_id
   - **Error**: "FABER workflow without work item"
   - **Fix**: Add work_item_id to frontmatter

### ETL Workflows

1. **Phase progression**
   - SHOULD follow: Extract → Transform → Load → Validate
   - **Warning**: "Non-standard ETL phase order"
   - **Fix**: Consider reordering phases

2. **Data lineage**
   - SHOULD include upstream_dependencies
   - SHOULD include downstream_impacts
   - **Warning**: "Missing data lineage information"
   - **Fix**: Add upstream/downstream tracking

3. **Data volumes**
   - SHOULD record counts of records processed
   - **Warning**: "No data volume metrics"
   - **Fix**: Add record counts to operations

---

## Schema Validation

### JSON Schema Compliance

All workflow logs MUST validate against `schema.json`:

```bash
# Validation command
jsonschema -i workflow.md --extract-frontmatter schema.json
```

**Common schema errors**:

1. **Type mismatch**
   - **Error**: "Field 'operations' must be array"
   - **Fix**: Ensure operations is array, not object

2. **Missing required field**
   - **Error**: "Required property 'workflow_id' missing"
   - **Fix**: Add all required fields to frontmatter

3. **Invalid enum value**
   - **Error**: "Status 'done' not in enum [pending, running, success, failure, partial, cancelled, archived]"
   - **Fix**: Use valid status value

4. **Pattern mismatch**
   - **Error**: "workflow_id doesn't match pattern ^workflow-[a-z0-9-]+$"
   - **Fix**: Use valid workflow_id format

5. **Invalid timestamp**
   - **Error**: "timestamp not valid ISO 8601 format"
   - **Fix**: Use `2025-01-17T10:00:00Z` format

6. **Invalid operation status**
   - **Error**: "Operation status 'complete' not in enum [started, completed, failed, skipped]"
   - **Fix**: Use "completed" not "complete"

---

## Validation Error Severity

### Critical (MUST fix before archiving)
- Invalid schema
- Missing required fields
- Invalid timestamps
- Sensitive data present
- Status-operation inconsistency

### Warning (SHOULD fix but not blocking)
- Missing optional fields
- No performance metrics
- Vague operation descriptions
- Missing lineage information

### Info (Nice to have)
- No decisions logged
- No artifacts listed
- Generic operation names

---

## Automated Validation

The log-validator skill runs these checks automatically:

```bash
# Validate workflow log
/fractary-logs:validate workflow-123-20250117T100000Z.md

# Expected output:
✅ Schema validation: PASS
✅ Frontmatter structure: PASS
✅ Timestamp consistency: PASS
⚠️ Missing performance metrics
⚠️ No decisions logged
✅ Status-operation consistency: PASS
✅ No sensitive data detected
```

---

## Manual Review Checklist

Before archiving a workflow log:

- [ ] All required frontmatter fields present
- [ ] Operations in chronological order
- [ ] Status consistent with operation results
- [ ] No sensitive data (credentials, PII, data values)
- [ ] Artifacts documented
- [ ] Performance metrics included
- [ ] Lineage tracked (upstream/downstream)
- [ ] Errors captured with context
- [ ] Decisions logged with rationale
- [ ] Next steps identified (if applicable)

---

## Real-Time Validation During Execution

For long-running workflows, validate incrementally:

1. **At start**: Validate frontmatter and initial structure
2. **During execution**: Validate each operation as it's added
3. **At completion**: Run full validation including status consistency

This catches issues early rather than at archive time.

---

## Common Validation Failures and Fixes

### "Operation timestamp before workflow start"

**Cause**: Operation logged with timestamp earlier than workflow start

**Fix**:
```yaml
# Incorrect
timestamp: 2025-01-17T10:00:00Z  # workflow start
operations:
  - timestamp: 2025-01-17T09:55:00Z  # before start!

# Correct
timestamp: 2025-01-17T10:00:00Z
operations:
  - timestamp: 2025-01-17T10:00:15Z  # after start
```

### "Status 'success' but operations show failures"

**Cause**: Overall status doesn't match operation results

**Fix**:
```yaml
# Incorrect
status: success
operations:
  - operation: validate
    status: failed  # contradiction!

# Correct
status: failure  # or partial if some succeeded
error_summary:
  total_errors: 1
  critical_errors:
    - "Validation failed"
```

### "Missing workflow_id"

**Cause**: Workflow ID not set in frontmatter

**Fix**:
```yaml
# Add to frontmatter
workflow_id: workflow-123-20250117T100000Z
```

### "Sensitive data detected"

**Cause**: Credentials or PII in log

**Fix**:
```yaml
# Incorrect
output: "Connected to postgres://user:password@host/db"

# Correct
output: "Connected to production database"
```
