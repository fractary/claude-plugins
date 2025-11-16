# Deployment Log Standards

## Purpose

Deployment logs capture complete deployment/release processes for:
- Audit trail and compliance
- Rollback decision-making
- Performance analysis
- Incident investigation
- Change tracking

## Required Sections

1. **Deployment Metadata** - ID, environment, version, commit
2. **Pre-Deployment Checks** - Validation results before deployment
3. **Deployment Steps** - Step-by-step execution log
4. **Changes Deployed** - List of changes included
5. **Services Updated** - Services and their version changes
6. **Health Checks** - Post-deployment health validation
7. **Deployment Summary** - Outcome and key metrics

## Capture Rules

**ALWAYS capture**:
- Complete deployment steps with timing
- Pre-deployment check results
- All services updated (old → new versions)
- Health check results
- Any rollback actions taken
- Environment being deployed to
- Version/commit being deployed

**NEVER capture in logs**:
- Production credentials or secrets
- Internal infrastructure URLs (production)
- Customer data or PII
- Unredacted connection strings

## Environment Handling

- **development**: Minimal validation, relaxed standards
- **staging**: Full validation, pre-production testing
- **production**: CRITICAL - full audit trail, all checks required
- **test**: Automated testing environment

## Status Values

- **pending**: Deployment queued
- **deploying**: Deployment in progress
- **success**: Deployment completed successfully
- **failure**: Deployment failed
- **rolled_back**: Deployment was rolled back
- **archived**: Deployment log archived

## Retention

- Local: 30 days
- Cloud: forever
- Priority: critical
- Auto-archive: Yes (after 30 days local)
