# Log Standards

Standards for logging and log management across the Fractary plugin ecosystem.

**Version**: 1.0 (2025-11-12)

## Overview

This document defines standards for:
- Log types and categories
- Log file organization and naming
- Retention policies and lifecycle management
- Cloud archival strategy
- Audit report standards
- Integration with fractary-logs plugin
- Version control considerations

## Philosophy

**Logs are ephemeral documentation of system behavior.**

Good logging practices:
- **Capture** relevant events without noise
- **Organize** logs by type and purpose
- **Retain** logs appropriately (local vs cloud)
- **Exclude** logs from version control
- **Archive** historical logs for compliance
- **Search** logs efficiently when needed

**Logs ≠ Version Control:**
- Logs are ephemeral, time-bound records
- Source code and configs are persistent artifacts
- Logs belong in storage systems, not Git
- Exception: Sample logs for testing/documentation

## Log Type Categories

### 1. Session Logs

**Purpose**: Track AI assistant interactions and decisions

**Location**: `/logs/sessions/`

**Naming**: `session-{session-id}-{timestamp}.md`

**Content**:
- Session metadata (ID, start time, end time)
- User requests and agent responses
- Tool invocations and results
- Errors and warnings
- Session outcome

**Retention**:
- Local: 30 days
- Cloud: Permanent (compressed)

**Example**:
```markdown
# Session Log

**Session ID**: sess-abc123
**Started**: 2025-01-15 14:30:22
**Ended**: 2025-01-15 15:45:10
**Duration**: 1h 14m 48s
**Work Item**: #123
**Status**: Success

## Summary
Implemented user authentication feature with JWT tokens.

## Timeline

### 14:30:22 - Frame Phase Started
- Fetched work item #123
- Classified as feature (authentication)
- Set up workspace

### 14:35:10 - Architect Phase Started
- Designed authentication flow
- Created specification
...
```

### 2. Build Logs

**Purpose**: Record compilation, bundling, and build processes

**Location**: `/logs/builds/`

**Naming**: `build-{timestamp}.log`

**Content**:
- Build command and arguments
- Compiler/bundler output
- Warnings and errors
- Build artifacts produced
- Build duration and status

**Retention**:
- Local: 7 days
- Cloud: 90 days (compressed)

**Example**:
```
[2025-01-15 14:30:22] Build started
[2025-01-15 14:30:22] Command: npm run build
[2025-01-15 14:30:23] > Building production bundle...
[2025-01-15 14:30:25] ✓ src/index.ts (45ms)
[2025-01-15 14:30:26] ✓ src/auth.ts (32ms)
[2025-01-15 14:30:27] Build completed in 5.2s
[2025-01-15 14:30:27] Output: dist/ (2.3 MB)
```

### 3. Test Logs

**Purpose**: Record test execution and results

**Location**: `/logs/tests/`

**Naming**: `test-{test-suite}-{timestamp}.log`

**Content**:
- Test suite name and configuration
- Individual test results
- Failures with stack traces
- Coverage metrics
- Test duration

**Retention**:
- Local: 7 days
- Cloud: 90 days (compressed)

**Example**:
```
[2025-01-15 14:35:00] Test suite: Authentication
[2025-01-15 14:35:01] ✓ should generate JWT token (15ms)
[2025-01-15 14:35:01] ✓ should validate token (8ms)
[2025-01-15 14:35:02] ✗ should reject expired token (25ms)
  Expected: false
  Received: true
  at src/auth.test.ts:42
[2025-01-15 14:35:02] Tests: 2 passed, 1 failed, 3 total
[2025-01-15 14:35:02] Coverage: 87.5%
```

### 4. Deployment Logs

**Purpose**: Record deployment processes and infrastructure changes

**Location**: `/logs/deployments/`

**Naming**: `deploy-{environment}-{timestamp}.log`

**Content**:
- Deployment target (environment, region)
- Infrastructure changes (Terraform/CloudFormation)
- Service updates and rollouts
- Health checks and validations
- Deployment status and duration

**Retention**:
- Local: 30 days
- Cloud: 1 year (compliance)

**Example**:
```
[2025-01-15 15:00:00] Deployment started
[2025-01-15 15:00:00] Environment: production
[2025-01-15 15:00:00] Region: us-east-1
[2025-01-15 15:00:02] Terraform: Planning changes...
[2025-01-15 15:00:05] Terraform: 3 to add, 1 to change, 0 to destroy
[2025-01-15 15:00:10] Applying changes...
[2025-01-15 15:02:30] Service updated: api-server v1.2.0
[2025-01-15 15:03:00] Health check: OK
[2025-01-15 15:03:00] Deployment completed successfully
```

### 5. Debug Logs

**Purpose**: Detailed diagnostic information for troubleshooting

**Location**: `/logs/debug/`

**Naming**: `debug-{component}-{timestamp}.log`

**Content**:
- Verbose execution traces
- Variable states and values
- Function call stacks
- Timing information
- Debug assertions

**Retention**:
- Local: 3 days (large volume)
- Cloud: 30 days (compressed)

**Format**:
```
[2025-01-15 14:30:22.123] [DEBUG] auth.validateToken: Entry
[2025-01-15 14:30:22.125] [DEBUG]   token: eyJhbGc... (truncated)
[2025-01-15 14:30:22.127] [DEBUG]   Decoding token payload
[2025-01-15 14:30:22.130] [DEBUG]   payload: {userId: 123, exp: 1642262422}
[2025-01-15 14:30:22.132] [DEBUG]   Checking expiration: now=1642262422, exp=1642262422
[2025-01-15 14:30:22.133] [DEBUG]   Token expired (delta: 0s)
[2025-01-15 14:30:22.134] [DEBUG] auth.validateToken: Exit (false)
```

### 6. Audit Logs

**Purpose**: Record compliance events and system audits

**Location**: `/logs/audits/`

**Naming**: `audit-{audit-type}-{timestamp}.md`

**Content**:
- Audit scope and timestamp
- Current state assessment
- Standards and requirements
- Gap analysis
- Recommendations
- Remediation plan references

**Retention**:
- Local: 90 days
- Cloud: Permanent (compliance)

**Example**: See [Audit Report Standards](#audit-report-standards) below

### 7. Error Logs

**Purpose**: Record errors, exceptions, and failures

**Location**: `/logs/errors/`

**Naming**: `errors-{timestamp}.log`

**Content**:
- Error message and code
- Stack trace
- Context (request ID, user, operation)
- Timestamp and severity
- Recovery actions taken

**Retention**:
- Local: 30 days
- Cloud: 1 year

**Format**:
```
[2025-01-15 14:30:22.500] [ERROR] Unhandled exception in auth.validateToken
  Error: Token signature verification failed
    at jwt.verify (node_modules/jsonwebtoken/verify.js:42)
    at validateToken (src/auth.ts:87)
    at authenticateRequest (src/middleware/auth.ts:15)
  Context:
    requestId: req-abc123
    userId: 456
    path: /api/users/profile
  Recovery: Returned 401 Unauthorized
```

### 8. Performance Logs

**Purpose**: Track performance metrics and optimization

**Location**: `/logs/performance/`

**Naming**: `perf-{component}-{timestamp}.log`

**Content**:
- Operation timings
- Resource usage (CPU, memory, disk)
- Query performance
- Cache hit rates
- Bottleneck analysis

**Retention**:
- Local: 7 days
- Cloud: 90 days

**Format**:
```
[2025-01-15 14:30:22] [PERF] Database Query
  Operation: SELECT * FROM users WHERE id = ?
  Duration: 245ms (SLOW - threshold: 100ms)
  Rows: 1
  Cache: MISS
  CPU: 15ms
  I/O: 230ms
  Recommendation: Add index on users.id
```

## Log Organization

### Directory Structure

```
project/
├── logs/                    # All logs (ephemeral, excluded from VCS)
│   ├── sessions/           # Session logs
│   │   ├── session-abc-20250115-143022.md
│   │   └── session-def-20250115-150000.md
│   ├── builds/             # Build logs
│   │   ├── build-20250115-143000.log
│   │   └── build-20250115-150000.log
│   ├── tests/              # Test logs
│   │   ├── test-unit-20250115-143500.log
│   │   └── test-integration-20250115-144000.log
│   ├── deployments/        # Deployment logs
│   │   ├── deploy-staging-20250115-145000.log
│   │   └── deploy-production-20250115-150000.log
│   ├── debug/              # Debug logs
│   │   └── debug-auth-20250115-143022.log
│   ├── audits/             # Audit reports
│   │   ├── audit-docs-20250115-100000.md
│   │   ├── audit-logs-20250115-110000.md
│   │   └── tmp/            # Temporary audit discovery data
│   ├── errors/             # Error logs
│   │   └── errors-20250115-143000.log
│   └── performance/        # Performance logs
│       └── perf-api-20250115-143000.log
├── specs/                  # Persistent specifications (in VCS)
│   ├── logs-remediation-20250115-110000.md
│   └── docs-remediation-20250115-100000.md
└── .fractary/              # Plugin configurations (in VCS)
    └── plugins/
        └── logs/
            └── config.json
```

### Naming Conventions

**Format**: `{type}-{identifier}-{timestamp}.{ext}`

**Components**:
- `type`: Log category (session, build, test, deploy, etc.)
- `identifier`: Optional specific identifier (environment, component, suite)
- `timestamp`: ISO 8601 compact format `YYYYMMDD-HHMMSS`
- `ext`: File extension (`.log` for plain text, `.md` for markdown)

**Examples**:
```
session-abc123-20250115-143022.md
build-20250115-143000.log
test-unit-20250115-143500.log
deploy-production-20250115-150000.log
debug-auth-20250115-143022.log
audit-docs-20250115-100000.md
errors-20250115-143000.log
perf-api-20250115-143000.log
```

**Guidelines**:
- Use lowercase for types
- Use hyphens as separators
- Include timezone in timestamp (UTC preferred)
- Use descriptive identifiers
- Keep names under 100 characters

## Retention Policies

### Hybrid Retention Strategy

**Principle**: Keep recent logs local for fast access, archive historical logs to cloud storage.

**Default Retention**:

| Log Type | Local Retention | Cloud Retention | Rationale |
|----------|----------------|-----------------|-----------|
| Session | 30 days | Permanent | Compliance, analysis |
| Build | 7 days | 90 days | Recent builds relevant |
| Test | 7 days | 90 days | Recent tests relevant |
| Deployment | 30 days | 1 year | Compliance, audits |
| Debug | 3 days | 30 days | High volume, diagnostics |
| Audit | 90 days | Permanent | Compliance, regulations |
| Error | 30 days | 1 year | Troubleshooting, trends |
| Performance | 7 days | 90 days | Optimization, benchmarks |

**Retention Rules**:
1. **Local retention**: Logs deleted after retention period
2. **Cloud archival**: Logs moved to cloud before deletion
3. **Compression**: Cloud logs compressed (gzip) to reduce storage costs
4. **Indexing**: Metadata indexed for searchability
5. **Access**: Cloud logs accessible via `/fractary-logs:read` command

### Cleanup Process

**Automatic cleanup** (via fractary-logs):
```bash
# Daily cron job
/fractary-logs:cleanup --dry-run
/fractary-logs:cleanup --execute
```

**Manual cleanup**:
```bash
# Remove logs older than retention period
find /logs/builds -name "*.log" -mtime +7 -delete
find /logs/debug -name "*.log" -mtime +3 -delete
```

**Before cleanup**:
1. Archive to cloud storage
2. Verify upload successful
3. Update search index
4. Delete local file

## Version Control Considerations

### What to Exclude

**ALWAYS exclude from version control:**
- ✅ `/logs/` - All logs (ephemeral)
- ✅ Build artifacts in logs
- ✅ Debug output files
- ✅ Temporary audit discovery data (`/logs/audits/tmp/`)

**ALWAYS include in version control:**
- ✅ `.fractary/plugins/*/config.json` - Plugin configurations
- ✅ `/specs/` - Persistent specifications and remediation plans
- ✅ Sample logs for testing/documentation (clearly marked)

### .gitignore Configuration

**Required entries**:
```gitignore
# Logs (managed by fractary-logs plugin)
logs/
*.log
*.log.*

# Temporary files
*.tmp
*.temp
tmp/
temp/

# Debug output
debug/
*.debug

# Build logs
build.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Test logs
test-results/
coverage/
.nyc_output/

# Deployment logs
deploy.log
terraform.log

# Audit discovery data (temporary)
logs/audits/tmp/
```

**Optional entries** (project-specific):
```gitignore
# IDE logs
.vscode/*.log
.idea/*.log

# OS logs
.DS_Store
Thumbs.db
```

### When to Commit Logs

**Acceptable scenarios:**
1. **Sample logs** for testing
   - Clearly marked as samples
   - Sanitized (no secrets)
   - Small size (< 100 KB)
   - In `tests/fixtures/` or `docs/examples/`

2. **Reference logs** for documentation
   - Demonstrating log formats
   - Troubleshooting examples
   - In documentation directories

**Example structure**:
```
tests/
└── fixtures/
    └── logs/
        ├── sample-session.md      # Sample session log
        ├── sample-build.log       # Sample build output
        └── README.md              # Explains these are samples
```

**Never commit**:
- Real production logs
- Logs with secrets or credentials
- Logs with PII (personally identifiable information)
- Large log files (> 100 KB)

## Cloud Archival Strategy

### Storage Backends

Fractary-logs supports multiple storage backends via fractary-file:

- **Cloudflare R2**: Recommended (S3-compatible, no egress fees)
- **AWS S3**: Widely supported
- **Local filesystem**: Development and testing

### Archival Process

**Workflow**:
1. Log reaches retention age (e.g., session log > 30 days)
2. Compress log file (gzip)
3. Upload to cloud storage (via fractary-file)
4. Update search index with cloud location
5. Verify upload successful
6. Delete local file

**Example**:
```bash
# Manual archival
/fractary-logs:archive --file logs/sessions/session-abc-20250115-143022.md

# Automatic archival (on schedule)
/fractary-logs:cleanup --execute
```

### Storage Structure

**Cloud storage organization**:
```
bucket/
├── project-name/
│   ├── sessions/
│   │   ├── 2025/
│   │   │   ├── 01/
│   │   │   │   └── session-abc-20250115-143022.md.gz
│   ├── builds/
│   ├── tests/
│   ├── deployments/
│   ├── audits/
│   ├── errors/
│   └── performance/
└── .index/
    └── logs-index.json
```

**Benefits**:
- Organized by project and log type
- Easy to navigate and query
- Supports multi-project storage
- Indexed for fast search

### Compression

**All archived logs MUST be compressed:**
- Format: gzip (`.gz`)
- Compression level: 6 (balance speed/size)
- Typical reduction: 80-90% for text logs

**Example**:
```bash
# Compress before upload
gzip logs/sessions/session-abc-20250115-143022.md
# Result: session-abc-20250115-143022.md.gz (90% smaller)
```

### Search Integration

**Search across local + cloud**:
```bash
# Search all logs (local + cloud)
/fractary-logs:search "authentication error"

# Search results include:
# - Local logs (fast, full text)
# - Cloud logs (indexed metadata, download on demand)
```

**Index structure**:
```json
{
  "logs": [
    {
      "id": "log-abc123",
      "type": "session",
      "timestamp": "2025-01-15T14:30:22Z",
      "location": "cloud",
      "path": "s3://bucket/project/sessions/2025/01/session-abc-20250115-143022.md.gz",
      "size": 1024,
      "metadata": {
        "session_id": "abc123",
        "work_item": "123",
        "status": "success"
      }
    }
  ]
}
```

## Audit Report Standards

### Purpose

Audit reports assess compliance with standards and identify gaps.

**Types of audits**:
1. **Documentation audits** (via fractary-docs plugin)
2. **Log management audits** (via fractary-logs plugin)
3. **Infrastructure audits** (via faber-cloud plugin)
4. **Code quality audits** (future)

### Audit Workflow

**Standard two-phase audit workflow** (aligned with fractary-docs and fractary-logs patterns):

```
Phase 1: Analysis & Presentation (Automatic)
  ├─ Load configuration and context
  ├─ Scan project structure
  ├─ Identify current state
  ├─ Compare against standards
  ├─ Generate discovery data (JSON)
  ├─ Create detailed audit report
  ├─ Present summary of findings
  ├─ Display recommendations by priority
  └─ ⏸️  PAUSE for user approval

Phase 2: Specification & Tracking (After Approval)
  ├─ Invoke spec-manager agent
  ├─ Generate remediation specification
  ├─ Create actionable implementation plan
  ├─ Include copy/paste commands
  ├─ Save to /specs/{type}-remediation-{timestamp}.md
  └─ Optionally create GitHub issues for tracking
```

**Approval Gate**: Phase 1 completes with findings presentation and pauses for user approval. User reviews the audit report and decides whether to proceed with Phase 2 (specification generation and tracking) or stop. This ensures users maintain control over when remediation plans are created.

### Audit Report Structure

**Location**: `/logs/audits/audit-{type}-{timestamp}.md`

**Format**: Markdown (for readability)

**Sections**:
```markdown
# {Type} Audit Report

**Audit Date**: {timestamp}
**Project**: {project-name}
**Auditor**: fractary-{plugin}:{audit-command}

## Executive Summary

Quick overview with key metrics:
- Total items audited: X
- Compliant: Y
- Non-compliant: Z
- Gaps: N (high: H, medium: M, low: L)

## Current State

Detailed assessment of what exists:
- Configuration status
- Directory structure
- Files and organization
- Current practices

## Standard Definition

What compliance looks like:
- Configuration requirements
- Directory structure requirements
- File naming conventions
- Best practices

## Gap Analysis

Comparison of current vs standard:

### High Priority Gaps
- Gap 1: Description
  - Current: What is
  - Expected: What should be
  - Impact: Why it matters

### Medium Priority Gaps
...

### Low Priority Gaps
...

## Recommendations

Prioritized actions to achieve compliance:

### Immediate Actions (High Priority)
1. Action 1
2. Action 2

### Short-term Actions (Medium Priority)
1. Action 1
2. Action 2

### Long-term Actions (Low Priority)
1. Action 1
2. Action 2

## Benefits

Expected benefits of remediation:
- Storage savings
- Improved compliance
- Better searchability
- Cost reduction

## Next Steps

1. Review audit report
2. Review remediation specification
3. Implement changes
4. Verify compliance
5. Re-audit

---

**Remediation Spec**: /specs/{type}-remediation-{timestamp}.md
```

### Remediation Specification Structure

**Location**: `/specs/{type}-remediation-{timestamp}.md`

**Generated by**: Spec Manager agent

**Format**: Markdown with executable commands

**Sections**:
```markdown
# {Type} Remediation Specification

**Created**: {timestamp}
**Audit**: /logs/audits/audit-{type}-{timestamp}.md
**Status**: Pending / In Progress / Completed

## Overview

### Current State
Brief description of current state.

### Target State
Brief description of desired state.

### Scope
What this spec covers.

## Requirements

Detailed requirements with rationale:

### REQ-1: Requirement Title
**Priority**: High / Medium / Low
**Category**: Configuration / Structure / Integration
**Description**: What needs to be done.
**Rationale**: Why this is important.
**Acceptance Criteria**:
- [ ] Criterion 1
- [ ] Criterion 2

## Implementation Plan

### Phase 1: {Phase Name}
**Goal**: What this phase achieves.
**Estimated Time**: X hours

#### Task 1.1: {Task Title}
**Commands**:
```bash
# Copy-paste ready commands
command1
command2
```

**Verification**:
```bash
# Commands to verify success
verify-command
```

**Expected Result**: What should happen.

### Phase 2: {Phase Name}
...

## Verification

Final verification steps:
```bash
# Commands to verify complete remediation
verification-commands
```

**Success Criteria**:
- [ ] All requirements met
- [ ] All tests pass
- [ ] Configuration valid
- [ ] Documentation updated

## Acceptance Criteria

- [ ] Phase 1 complete
- [ ] Phase 2 complete
- [ ] All verification steps pass
- [ ] Re-audit shows compliance

---

**Related Audit**: /logs/audits/audit-{type}-{timestamp}.md
```

### Audit Report vs Remediation Spec

**Key Distinctions:**

| Aspect | Audit Report | Remediation Spec |
|--------|-------------|------------------|
| **Purpose** | Assessment (what's wrong) | Action plan (how to fix) |
| **Location** | `/logs/audits/` | `/specs/` |
| **Retention** | Ephemeral (with logs) | Persistent (in VCS) |
| **Content** | Analysis, gaps, recommendations | Requirements, tasks, commands |
| **Format** | Descriptive | Prescriptive |
| **Audience** | Stakeholders | Implementers |
| **Generator** | Audit agent | Spec Manager agent |

**Workflow**:
```
Audit → Audit Report (assessment)
     → Remediation Spec (action plan)
     → Implementation (execute plan)
     → Re-audit (verify compliance)
```

## Integration with fractary-logs Plugin

### Plugin Configuration

**Location**: `.fractary/plugins/logs/config.json`

**Example**:
```json
{
  "schema_version": "1.0",
  "retention": {
    "local": {
      "sessions": 30,
      "builds": 7,
      "tests": 7,
      "deployments": 30,
      "debug": 3,
      "audits": 90,
      "errors": 30,
      "performance": 7
    },
    "cloud": {
      "sessions": -1,
      "builds": 90,
      "tests": 90,
      "deployments": 365,
      "debug": 30,
      "audits": -1,
      "errors": 365,
      "performance": 90
    }
  },
  "storage": {
    "backend": "file-manager",
    "compression": true,
    "index": true
  },
  "auto_capture": {
    "session": true,
    "build": true,
    "test": true,
    "deployment": true
  }
}
```

**Notes**:
- `-1` = Permanent retention
- `compression`: Always `true` for cloud storage
- `index`: Enable search across local + cloud

### Commands

**Initialize log management**:
```bash
/fractary-logs:init
```

**Capture logs**:
```bash
/fractary-logs:capture --type session --file session-abc.md
/fractary-logs:capture --type build --file build.log
```

**Search logs**:
```bash
/fractary-logs:search "authentication error"
/fractary-logs:search "authentication error" --type session
/fractary-logs:search "authentication error" --after 2025-01-01
```

**Read logs**:
```bash
/fractary-logs:read logs/sessions/session-abc-20250115-143022.md
/fractary-logs:read s3://bucket/project/sessions/2025/01/session-abc.md.gz
```

**Archive logs**:
```bash
/fractary-logs:archive --file logs/sessions/session-abc-20250115-143022.md
/fractary-logs:archive --type sessions --older-than 30d
```

**Cleanup logs**:
```bash
/fractary-logs:cleanup --dry-run
/fractary-logs:cleanup --execute
```

**Audit log management**:
```bash
/fractary-logs:audit
/fractary-logs:audit --project-root ./my-project
/fractary-logs:audit --execute
```

## Log Format Standards

### Plain Text Logs

**Format**: Line-based with timestamps

```
[YYYY-MM-DD HH:MM:SS.mmm] [LEVEL] Message
```

**Levels**: DEBUG, INFO, WARN, ERROR, FATAL

**Example**:
```
[2025-01-15 14:30:22.123] [INFO] Server started on port 3000
[2025-01-15 14:30:25.456] [WARN] High memory usage: 85%
[2025-01-15 14:30:30.789] [ERROR] Database connection failed
```

### Structured Logs (JSON)

**Format**: One JSON object per line

```json
{"timestamp":"2025-01-15T14:30:22.123Z","level":"info","message":"Server started","port":3000}
{"timestamp":"2025-01-15T14:30:25.456Z","level":"warn","message":"High memory usage","usage":85}
{"timestamp":"2025-01-15T14:30:30.789Z","level":"error","message":"Database connection failed","error":"ECONNREFUSED"}
```

**Benefits**:
- Machine-parseable
- Supports structured metadata
- Easy to filter and aggregate

### Markdown Logs

**Format**: Markdown document with structure

**Use for**:
- Session logs
- Audit reports
- Remediation specifications
- Post-mortems

**Benefits**:
- Human-readable
- Supports rich formatting
- Easy to navigate
- Can include code blocks

## Security Considerations

### Sensitive Information

**NEVER log**:
- Passwords, API keys, tokens
- Credit card numbers, SSNs
- Personally identifiable information (PII)
- Session cookies
- Private encryption keys

**Redaction patterns**:
```javascript
// Redact sensitive data
const redacted = log.replace(/password=\S+/g, 'password=***');
const redacted = log.replace(/token=\S+/g, 'token=***');
const redacted = log.replace(/\b\d{16}\b/g, '****-****-****-****');
```

### Log Access Control

**Considerations**:
- Limit access to production logs
- Audit log access (who viewed what)
- Encrypt logs at rest (cloud storage)
- Use secure transfer (HTTPS/TLS)

### Compliance

**Regulations**:
- **GDPR**: Right to erasure, data retention limits
- **HIPAA**: Audit trails, encryption
- **SOC 2**: Log retention, access controls
- **PCI DSS**: Log security, retention

**Recommendations**:
1. Define retention policies based on regulations
2. Implement log redaction for sensitive data
3. Encrypt logs in transit and at rest
4. Maintain audit trail of log access
5. Regular log audits for compliance

## Best Practices

### Do This

✅ **Organize logs by type**
```
logs/
├── sessions/
├── builds/
└── tests/
```

✅ **Use consistent naming**
```
session-abc123-20250115-143022.md
build-20250115-143000.log
```

✅ **Archive to cloud regularly**
```bash
/fractary-logs:cleanup --execute
```

✅ **Exclude logs from version control**
```gitignore
logs/
*.log
```

✅ **Configure retention policies**
```json
{
  "retention": {
    "local": {"sessions": 30},
    "cloud": {"sessions": -1}
  }
}
```

✅ **Redact sensitive information**
```javascript
log = log.replace(/password=\S+/g, 'password=***');
```

### Don't Do This

❌ **Commit logs to version control**
```bash
git add logs/  # NO!
```

❌ **Mix log types in one directory**
```
logs/
├── session-abc.md
├── build.log
└── test-results.log
```

❌ **Use inconsistent naming**
```
session1.md
Session-2.md
SESSION_THREE.md
```

❌ **Log sensitive information**
```javascript
log(`User password: ${password}`);  // NO!
log(`API key: ${apiKey}`);         // NO!
```

❌ **Keep logs forever without archival**
```
logs/  # 50 GB of logs, never archived
```

❌ **Use ambiguous retention policies**
```json
{
  "retention": "keep for a while"  // NO!
}
```

## Quality Checklist

Before committing log management configuration:

- [ ] All log types have defined locations
- [ ] Retention policies configured for each type
- [ ] Cloud storage configured (if using archival)
- [ ] `.gitignore` excludes all logs
- [ ] Sensitive data redaction implemented
- [ ] Log naming follows conventions
- [ ] Auto-capture configured (if applicable)
- [ ] Search index enabled
- [ ] Compression enabled for cloud storage
- [ ] Compliance requirements met

## Troubleshooting

### Logs in Version Control

**Symptom**: Logs appear in `git status`

**Solutions**:
1. Add to `.gitignore`:
   ```gitignore
   logs/
   *.log
   ```
2. Remove from Git history:
   ```bash
   git rm --cached logs/*.log
   git commit -m "chore: remove logs from version control"
   ```
3. Archive to cloud:
   ```bash
   /fractary-logs:archive --type all
   ```

### Large Log Files

**Symptom**: Log files consuming too much disk space

**Solutions**:
1. Check retention policy:
   ```bash
   cat .fractary/plugins/logs/config.json
   ```
2. Archive old logs:
   ```bash
   /fractary-logs:archive --older-than 30d
   ```
3. Cleanup local logs:
   ```bash
   /fractary-logs:cleanup --execute
   ```
4. Enable compression:
   ```json
   {"storage": {"compression": true}}
   ```

### Cannot Find Logs

**Symptom**: Logs missing or not searchable

**Solutions**:
1. Check if archived to cloud:
   ```bash
   /fractary-logs:search "keyword"
   ```
2. Verify cloud storage configured:
   ```bash
   cat .fractary/plugins/logs/config.json
   ```
3. Rebuild search index:
   ```bash
   /fractary-logs:reindex
   ```

## Further Reading

- [CHANGELOG-STANDARDS.md](./CHANGELOG-STANDARDS.md) - Changelog maintenance standards
- [DOCUMENTATION-STANDARDS.md](./DOCUMENTATION-STANDARDS.md) - General documentation standards
- [fractary-logs Plugin README](../../plugins/logs/README.md) - Log management plugin
- [fractary-file Plugin README](../../plugins/file/README.md) - File storage plugin

---

**Standards Version**: 1.0 (2025-11-12)
**Last Updated**: 2025-11-12
**Next Review**: 2026-02-12
