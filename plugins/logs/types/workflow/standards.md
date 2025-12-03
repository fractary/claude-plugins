# Workflow Log Standards

## Purpose

Workflow logs track the execution of FABER workflows, ETL pipelines, and other project-specific workflow processes. They provide an audit trail of operations, enable downstream systems to understand upstream changes, and support debugging and lineage tracking.

**Use for**:
- FABER workflow execution (Frame → Architect → Build → Evaluate → Release)
- ETL pipeline operations (Extract → Transform → Load)
- Data transformation workflows
- CI/CD pipeline execution
- Multi-step automation processes
- Workflow lineage tracking

**Do NOT use for**:
- Build compilation logs (use `build` type)
- Deployment logs (use `deployment` type)
- Test execution (use `test` type)
- Version release notes (use `changelog` type)

---

## Required Sections

Every workflow log MUST include:

1. **Frontmatter** - Structured metadata
   - `log_type: workflow`
   - `workflow_id` - Unique identifier
   - `timestamp` - ISO 8601 start time
   - `status` - Current execution status

2. **Execution Summary** - High-level overview
   - Context (project, repo, branch, environment)
   - Current phase and step
   - Performance metrics

3. **Operations Timeline** - Chronological record
   - All operations performed
   - Timestamps for each operation
   - Status of each operation
   - Targets acted upon

4. **Status Tracking** - Current state
   - Overall workflow status
   - Phase/step progress
   - Error summary (if any)

---

## Capture Rules

### ✅ ALWAYS Capture

- **All workflow operations** - Every step executed
- **Operation timestamps** - Start/end times for each operation
- **Targets/inputs** - What datasets, files, or resources were acted upon
- **Status changes** - When workflow moves between states
- **Decisions made** - Key decision points and rationale
- **Artifacts created** - Output files, datasets, reports
- **Errors encountered** - All failures with context
- **Performance metrics** - Duration, resource usage

### ❌ NEVER Capture

- **Secrets or credentials** - API keys, passwords, tokens
- **Personally identifiable information (PII)** - User data, emails, phone numbers
- **Sensitive data values** - Actual data content (capture metadata only)
- **Internal system paths** - Use relative paths when possible
- **Proprietary algorithms** - Trade secret implementation details

### 🔍 Operation Categorization

Record operations with these attributes:

- **timestamp** - When operation started (ISO 8601)
- **phase** - FABER phase or workflow stage (Frame, Extract, Transform, etc.)
- **step** - Specific step within phase
- **operation** - Action performed (e.g., "validate_schema", "transform_data")
- **target** - What was acted upon (e.g., "customer_dataset", "config.json")
- **status** - Result (started, completed, failed, skipped)
- **duration_ms** - How long it took (optional but recommended)
- **output** - Brief result summary (not full data)

---

## Redaction Rules

Before creating workflow logs, redact:

1. **Credentials**
   - API keys, access tokens, passwords
   - Database connection strings with passwords
   - OAuth tokens, JWT secrets

2. **PII and Customer Data**
   - Email addresses, phone numbers, social security numbers
   - Customer names, addresses (use placeholders)
   - Actual data values (log counts/types instead)

3. **Internal Infrastructure**
   - Internal IP addresses (use environment names)
   - Production database hosts (use generic identifiers)
   - Proprietary service endpoints

4. **Sensitive Metadata**
   - Customer account IDs
   - Proprietary dataset names
   - Trade secret configurations

**Example Redaction**:
```
❌ "Loaded 1000 rows from customer_emails table at db-prod-01.internal:5432"
✅ "Loaded 1000 rows from customer_emails table in production environment"

❌ "API key sk-abc123 used for authentication"
✅ "Authentication completed using configured API key"

❌ "Processed records: [{'email': 'user@example.com', 'ssn': '123-45-6789'}]"
✅ "Processed 1 record with fields: email, ssn"
```

---

## Naming Conventions

Workflow log files MUST follow this pattern:

```
workflow-{work_item_id}-{timestamp}.md
```

**Examples**:
- `workflow-123-20250117T100000Z.md`
- `workflow-feature-456-20250117T143022Z.md`
- `workflow-etl-daily-20250117T060000Z.md`

**workflow_id pattern**:
```
workflow-{identifier}-{timestamp}
```

Where identifier can be:
- Work item ID (e.g., `workflow-123-20250117T100000Z`)
- Workflow name (e.g., `workflow-daily-sync-20250117T060000Z`)
- Feature slug (e.g., `workflow-user-auth-20250117T100000Z`)

---

## Status Values

Workflow logs progress through these states:

- **pending** - Workflow queued but not started
- **running** - Currently executing
- **success** - Completed successfully
- **failure** - Failed with errors
- **partial** - Partially completed (some operations succeeded)
- **cancelled** - Manually stopped or timeout
- **archived** - Historical record, execution complete

---

## FABER Workflow Phases

For FABER workflows, use these standard phase names:

1. **Frame** - Fetch work item, classify, setup environment
2. **Architect** - Design solution, create specification
3. **Build** - Implement from spec
4. **Evaluate** - Test and review (with retry loop)
5. **Release** - Create PR, deploy, document

**Example operations by phase**:

**Frame**:
- `fetch_work_item`, `classify_work_type`, `setup_environment`, `validate_config`

**Architect**:
- `analyze_requirements`, `design_solution`, `create_spec`, `review_approach`

**Build**:
- `implement_feature`, `write_tests`, `refactor_code`, `update_docs`

**Evaluate**:
- `run_tests`, `lint_code`, `review_changes`, `benchmark_performance`

**Release**:
- `create_branch`, `commit_changes`, `create_pr`, `deploy`, `update_changelog`

---

## ETL Workflow Phases

For ETL workflows, use these standard phase names:

1. **Extract** - Pull data from sources
2. **Transform** - Process and clean data
3. **Load** - Write to destinations
4. **Validate** - Verify data quality

**Example operations by phase**:

**Extract**:
- `connect_source`, `query_data`, `download_file`, `stream_records`

**Transform**:
- `clean_data`, `apply_business_rules`, `aggregate`, `join_datasets`, `calculate_metrics`

**Load**:
- `connect_destination`, `create_table`, `insert_records`, `update_indexes`

**Validate**:
- `check_row_counts`, `validate_schema`, `verify_constraints`, `run_quality_checks`

---

## Lineage Tracking

Workflow logs enable data lineage tracking. Always include:

1. **Upstream Dependencies**
   - Source workflows that triggered this execution
   - Input datasets and their versions
   - Configuration changes that prompted re-execution

2. **Downstream Impacts**
   - Systems that consume this workflow's outputs
   - Actions required by downstream systems
   - Impact type (data refresh, schema change, etc.)

**Example**:
```yaml
upstream_dependencies:
  - workflow_id: workflow-raw-ingest-20250117T050000Z
    type: data-pipeline
    status: success
    timestamp: 2025-01-17T05:00:00Z

downstream_impacts:
  - system: analytics-dashboard
    impact_type: data_refresh
    action_required: Refresh customer metrics view
  - system: ml-training-pipeline
    impact_type: schema_change
    action_required: Update feature extraction to handle new fields
```

---

## Decision Logging

Capture key decisions made during workflow execution:

- **What decision was made** - Clear description
- **When** - Timestamp
- **Rationale** - Why this choice was made
- **Alternatives considered** - Other options evaluated

**Example**:
```yaml
decisions:
  - timestamp: 2025-01-17T10:15:22Z
    decision: Skip data validation step
    rationale: Source already validated by upstream pipeline
    alternatives_considered:
      - Re-validate anyway (rejected: unnecessary duplicate work)
      - Add lightweight sanity checks (rejected: time constraints)
```

---

## Artifact Documentation

Record all artifacts created:

- **Type** - File type or artifact category
- **Path** - Where it was created (relative paths preferred)
- **Size** - File size in bytes (optional)
- **Checksum** - For integrity verification (optional)
- **Created timestamp** - When artifact was generated

**Example**:
```yaml
artifacts:
  - type: specification
    path: .faber/specs/feature-123-spec.md
    size_bytes: 4521
    created_at: 2025-01-17T10:30:00Z
    checksum: sha256:abc123...
  - type: implementation
    path: src/features/auth.ts
    created_at: 2025-01-17T11:00:00Z
```

---

## Performance Metrics

Include execution metrics when available:

- **Total duration** - End-to-end execution time
- **Operations count** - Total operations performed
- **Success rate** - Percentage of successful operations
- **Resource usage** - CPU, memory, disk I/O (optional)

**Example**:
```yaml
metrics:
  total_duration_ms: 145230
  operations_count: 47
  success_rate: 95.74
  resource_usage:
    peak_memory_mb: 512
    cpu_percent: 45
```

---

## Error Handling

When errors occur, capture:

- **Total error count**
- **Error types** - Categories of errors
- **Critical errors** - Failures that blocked execution
- **Error context** - What operation failed, what was the target

Include enough context to debug, but redact sensitive details.

**Example**:
```yaml
error_summary:
  total_errors: 3
  error_types:
    - ValidationError
    - NetworkTimeout
  critical_errors:
    - "Failed to validate schema: Required field 'customer_id' missing in 15 records"
    - "Network timeout connecting to data warehouse (retry attempted 3 times)"
```

---

## Best Practices

1. **Log continuously** - Update status as workflow progresses
2. **Be specific** - Record exact operations and targets
3. **Think downstream** - Log information that downstream systems need
4. **Preserve context** - Include environment, config versions
5. **Handle failures gracefully** - Capture errors but continue logging
6. **Use structured data** - Make logs machine-parseable
7. **Optimize for queries** - Use consistent field names and formats
8. **Balance detail** - Enough for debugging, not so much it's overwhelming

---

## S3 Storage Configuration

Workflow logs can be pushed to S3 for cross-project access and downstream consumption.

### Configuration

Configure S3 push in your project's `.fractary/plugins/logs/config.json`:

```json
{
  "types": {
    "workflow": {
      "local_retention_days": 7,
      "cloud_storage": {
        "enabled": true,
        "provider": "s3",
        "bucket": "${ORG}.logs.${PROJECT}",
        "prefix": "workflow/{year}/{month}/",
        "format": "json"
      }
    }
  }
}
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `local_retention_days` | Days to keep local copies (0 = S3 only) | 7 |
| `cloud_storage.enabled` | Enable S3 push | false |
| `cloud_storage.provider` | Storage provider (s3, r2, gcs) | s3 |
| `cloud_storage.bucket` | Bucket name (supports ${ORG}, ${PROJECT} variables) | - |
| `cloud_storage.prefix` | Path prefix (supports {year}, {month} variables) | workflow/ |
| `cloud_storage.format` | Output format (json, ndjson) | json |

### S3 Path Pattern

```
s3://{bucket}/workflow/{year}/{month}/workflow-{work_id}-{timestamp}.json
```

**Example**:
```
s3://fractary.logs.claude-plugins/workflow/2025/12/workflow-199-20251202T150000Z.json
```

### Cross-Project Access

For downstream systems to consume workflow events from other projects, configure IAM policies to allow read access to the source buckets.

**Example: Allow lake.corthonomy.ai to read from etl.corthion.ai**:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:ListBucket"],
    "Resource": [
      "arn:aws:s3:::corthos.logs.etl.corthion.ai",
      "arn:aws:s3:::corthos.logs.etl.corthion.ai/workflow/*"
    ]
  }]
}
```

### Consumer Polling Pattern

Downstream systems can poll S3 for workflow events:

```python
import boto3
import json
from datetime import datetime

def poll_for_workflow_events(bucket, event_type=None, since=None):
    """Poll S3 for workflow events."""
    s3 = boto3.client('s3')
    prefix = f'workflow/{datetime.now().year}/{datetime.now().month}/'

    response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)

    events = []
    for obj in response.get('Contents', []):
        # Filter by modification time if 'since' provided
        if since and obj['LastModified'] < since:
            continue

        data = s3.get_object(Bucket=bucket, Key=obj['Key'])['Body'].read()
        event = json.loads(data)

        # Filter by event_type if provided
        if event_type and event.get('event_type') != event_type:
            continue

        events.append(event)

    return events

# Example: Get all artifact_create events from upstream ETL project
artifacts = poll_for_workflow_events(
    bucket='corthos.logs.etl.corthion.ai',
    event_type='artifact_create'
)

for artifact in artifacts:
    print(f"New artifact: {artifact['payload']['artifact']['type']}")
```

### S3-Only Mode

For projects that primarily serve downstream consumers (e.g., ETL pipelines), you can skip local storage entirely:

```json
{
  "types": {
    "workflow": {
      "local_retention_days": 0,
      "cloud_storage": {
        "enabled": true,
        "bucket": "${ORG}.logs.${PROJECT}",
        "prefix": "workflow/{year}/{month}/"
      }
    }
  }
}
```

Setting `local_retention_days: 0` means events go directly to S3 without local storage.

---

## Example Workflow Log

```markdown
---
log_type: workflow
title: "FABER Workflow - Implement User Authentication"
workflow_id: workflow-123-20250117T100000Z
work_item_id: "123"
timestamp: 2025-01-17T10:00:00Z
status: success
phase: Release
workflow_type: faber
---

# Workflow Execution: FABER Workflow - Implement User Authentication

**Workflow ID**: `workflow-123-20250117T100000Z`
**Work Item**: #123
**Started**: 2025-01-17T10:00:00Z
**Status**: success
**Current Phase**: Release

## Operations Timeline

### 2025-01-17T10:00:15Z - fetch_work_item

**Phase**: Frame
**Target**: issue #123
**Status**: completed
**Duration**: 450ms

### 2025-01-17T10:01:00Z - create_spec

**Phase**: Architect
**Target**: .faber/specs/feature-123-spec.md
**Status**: completed
**Duration**: 8200ms

### 2025-01-17T10:15:00Z - implement_feature

**Phase**: Build
**Target**: src/auth/login.ts
**Status**: completed
**Duration**: 25000ms

## Artifacts Created

- **specification**: `.faber/specs/feature-123-spec.md`
- **implementation**: `src/auth/login.ts`
- **tests**: `tests/auth/login.test.ts`

## Next Steps

- Monitor PR review progress
- Deploy to staging after approval
```
