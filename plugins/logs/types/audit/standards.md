# Audit Log Standards

## Purpose
Capture security, compliance, performance, access control, and change management events for accountability and regulatory compliance.

## Required Sections
- Action Summary (user, action, resource, timestamp)
- Details (comprehensive event description)
- Context (request metadata, environment info)
- Security Information (IP, auth method, session tracking)
- Changes Made (before/after state for change audits)
- Audit Trail (sequential event chain)

## Capture Rules
**ALWAYS capture**: User identity, action performed, resource affected, timestamp, IP address, outcome
**REDACT**: Passwords, API keys, PII beyond user ID, session tokens (capture session ID only)
**NEVER log**: Raw authentication credentials, encryption keys, personal data not required for audit

## Security Standards
- Use UTC timestamps (ISO 8601 format)
- Hash sensitive identifiers when possible
- Capture failed access attempts (failed logins, unauthorized actions)
- Log privilege escalation events
- Record all configuration changes to production systems

## Compliance Categories

### Security Audits
- Authentication/authorization events
- Access control changes
- Security policy modifications
- Intrusion detection events
- Vulnerability assessments

### Compliance Audits
- Regulatory requirement validations
- Data retention compliance checks
- Privacy policy adherence
- Certification audit trails

### Performance Audits
- Resource utilization tracking
- Performance degradation events
- Capacity planning metrics
- SLA compliance measurements

### Access Audits
- User access grants/revocations
- Permission changes
- Resource access attempts (successful/failed)
- Data export events

### Change Audits
- Configuration changes
- Code deployments
- Infrastructure modifications
- Policy updates

## Retention
- Local: 90 days (compliance requirement)
- Cloud: Forever (permanent audit trail)
- Priority: critical (never auto-delete)
- Special handling: Regulatory audits must be immutable

## Redaction Patterns
- `[REDACTED:PASSWORD]` - Password fields
- `[REDACTED:API_KEY]` - API keys and tokens
- `[REDACTED:PII:EMAIL]` - Email addresses (if not audit subject)
- `[REDACTED:PII:SSN]` - Social security numbers
- `[REDACTED:SECRET]` - Generic secrets
- `[HASHED:SHA256:abc123...]` - Hashed sensitive identifiers
