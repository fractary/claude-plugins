# Deployment Log Validation Rules

## Frontmatter Validation

✅ **MUST have** `log_type: deployment`
✅ **MUST have** `deployment_id`
✅ **MUST have** `environment` (development, staging, production, test)
✅ **MUST have** valid status
✅ **MUST have** valid ISO 8601 date
⚠️  **SHOULD have** `version` (semver format)
⚠️  **SHOULD have** `commit_sha`

## Production Deployment Rules

**For environment: production**:
✅ **MUST have** version field (semver)
✅ **MUST have** commit_sha
✅ **MUST have** Pre-Deployment Checks section
✅ **MUST have** Health Checks section
✅ **MUST have** Rollback Plan section
✅ **MUST have** all health checks passing (for success status)

## Structure Validation

✅ **MUST have** Deployment Metadata
✅ **MUST have** Deployment Steps
✅ **MUST have** Deployment Summary
⚠️  **SHOULD have** Changes Deployed (list of what changed)
⚠️  **SHOULD have** Services Updated (version changes)

## Content Validation

✅ **Environment** must be valid enum
- Valid: development, staging, production, test
- Invalid: prod, dev, stage

✅ **Version** must follow semver (if present)
- Pattern: `^\d+\.\d+\.\d+`
- Example: `1.2.3`, `2.0.0-beta`

✅ **Status consistency**
- success: All health checks should pass
- failure: At least one error/issue documented
- rolled_back: Rollback steps documented

## Security Validation

✅ **No production secrets** in deployment logs
- Check for: passwords, API keys, tokens
- Redact as `[REDACTED:PROD_SECRET]`

✅ **No production URLs** exposed
- Internal infrastructure URLs redacted
- Public-facing URLs OK

## Critical Warnings

⚠️  **WARN if production deployment without rollback plan**
⚠️  **WARN if production deployment without health checks**
⚠️  **WARN if deployment duration > 30 minutes** (investigate timeout)
