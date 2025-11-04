# Fractary DevOps Plugin - Documentation Systems

**Version:** 1.0.0

---

## Documentation Principles

1. **Embedded**: Skills document their own work as final step
2. **Atomic**: Documentation happens with work, survives partial failures
3. **Current**: Always reflects actual state
4. **Accessible**: Human-readable + machine-readable formats

## Resource Registry

**Location:** `.fractary/plugins/faber-cloud/deployments/{env}/registry.json`

**Purpose:** Machine-readable record of all deployed resources

**Structure:**
```json
{
  "environment": "test",
  "last_deployed": "2025-10-28T14:30:00Z",
  "resources": [
    {
      "type": "aws_s3_bucket",
      "terraform_address": "aws_s3_bucket.uploads",
      "aws_id": "corthovore-core-test-uploads",
      "arn": "arn:aws:s3:::corthovore-core-test-uploads",
      "console_url": "https://s3.console.aws.amazon.com/...",
      "created": "2025-10-28T14:30:00Z",
      "metadata": {...}
    }
  ]
}
```

**Updated by:** Every deployment skill

## Deployment Documentation

**Location:** `.fractary/plugins/faber-cloud/deployments/{env}/DEPLOYED.md`

**Purpose:** Human-readable resource list with console links

**Example:**
```markdown
# Deployed Resources - Test Environment

Last Updated: 2025-10-28 14:31:00 UTC

## S3 Buckets

### corthovore-core-test-uploads
- **ARN:** arn:aws:s3:::corthovore-core-test-uploads
- **Console:** [View](https://s3.console...)
- **Purpose:** User file uploads
```

## Issue Log

**Location:** `.fractary/plugins/faber-cloud/deployments/issue-log.json`

**Purpose:** Historical record of errors and solutions

**Structure:**
```json
{
  "issues": [
    {
      "id": "issue-001",
      "error_message": "...",
      "category": "permission_error",
      "solution": {...},
      "success": true,
      "recurrence_count": 3
    }
  ]
}
```

**Updated by:** infra-debugger after successful resolution

## Design Documents

**Location:** `.fractary/plugins/faber-cloud/designs/{feature}.md`

**Purpose:** Architecture designs for features

**Created by:** infra-architect

## Log Storage

**Large logs stored in S3:**
- Deployment history logs
- Operation logs
- Test results

**Configuration:**
```json
{
  "logging": {
    "backend": "s3",
    "s3_bucket": "project-devops-logs",
    "local_cache_days": 7
  }
}
```

## What Gets Committed

**✅ Commit to Git:**
- Design documents
- Resource registry
- DEPLOYED.md
- IAM audit trail
- Config template

**❌ NOT Committed:**
- Config file (contains secrets)
- Terraform plans (temporary)
- Large log files (S3-backed)

## Documentation Scripts

**Shared utilities:** `skills/devops-common/scripts/`
- `update-registry.sh`: Update resource registry
- `update-docs.sh`: Update DEPLOYED.md
- `append-log.sh`: Append to deployment history
- `sync-to-s3.sh`: Sync logs to S3

**Every skill calls these as final step.**

---

See architecture document for documentation data flow.
