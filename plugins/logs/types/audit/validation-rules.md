# Audit Log Validation Rules

## Frontmatter
✅ **MUST have** `log_type: audit`
✅ **MUST have** `audit_id`
✅ **MUST have** `audit_type` (security, compliance, performance, access, change)
✅ **MUST have** `severity` (info, warning, critical)
✅ **MUST have** `user` (who performed the action)
✅ **MUST have** `action` (what was done)
✅ **MUST have** `resource` (what was affected)
✅ **MUST have** valid status
⚠️  **SHOULD have** `date` in UTC ISO 8601 format

## Structure
✅ **MUST have** Action Summary section
✅ **MUST have** Details section
⚠️  **SHOULD have** Security Information section (IP, auth method)
⚠️  **SHOULD have** Changes Made section (for change audits)
⚠️  **SHOULD have** Audit Trail section

## Content
✅ **User field must not be empty or generic**: No "user", "admin", "system" without qualifier
✅ **Action must be specific**: Use precise verbs (created, modified, deleted, accessed, granted, revoked)
✅ **Resource must include type and identifier**: e.g., "user:john.doe", "file:/etc/config", "role:admin"
✅ **Critical severity requires**: Detailed context, security information, and related events
✅ **Change audits must include**: Before/after state for all modifications

## Security Requirements
✅ **MUST redact**: Passwords, API keys, secrets in details/context
✅ **MUST capture for security audits**: IP address, authentication method, session ID
✅ **MUST log failed attempts**: Include reason for denial (permission denied, invalid credentials, etc.)
⚠️  **SHOULD hash PII**: When identifiers must be captured but privacy required

## Compliance Requirements
✅ **MUST be immutable**: Once created, audit logs cannot be modified (create correction entries instead)
✅ **MUST have sequential audit trail**: Events must link to related previous events
✅ **MUST preserve for retention period**: 90 days minimum, permanent for critical events
⚠️  **SHOULD include compliance tags**: Regulatory framework references (SOC2, HIPAA, GDPR, etc.)

## Validation by Audit Type

### security
✅ **MUST include**: IP address, authentication method
✅ **MUST capture**: All access attempts (success/failure)

### compliance
✅ **MUST include**: Compliance framework reference
✅ **MUST capture**: Validation results, evidence of compliance

### performance
✅ **MUST include**: Metrics (response time, resource utilization)
✅ **MUST capture**: Threshold violations, degradation events

### access
✅ **MUST include**: Requestor identity, resource accessed, permission level
✅ **MUST capture**: Grant/deny decision with reasoning

### change
✅ **MUST include**: Before/after state for all changes
✅ **MUST capture**: Change approval reference, rollback procedure
