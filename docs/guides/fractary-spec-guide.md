# Fractary Spec Plugin - User Guide

Complete guide to ephemeral specification lifecycle management with the fractary-spec plugin.

## Overview

The fractary-spec plugin manages **ephemeral specifications** - point-in-time requirements documents tied to work items. Unlike documentation (which is living state), specs are temporary and should be archived when work completes to keep your workspace clean.

### Key Philosophy: Specs ≠ Docs

| Specs | Docs |
|-------|------|
| Ephemeral | Living |
| Point-in-time requirements | Current system state |
| Archived when complete | Continuously updated |
| Tied to issues | Project-wide |
| Temporary | Permanent |
| /specs directory → cloud | /docs directory → git |

**Problem**: Old specs confuse Claude by presenting outdated requirements as current.

**Solution**: Archive completed specs to cloud, keeping only active specs in workspace.

## Quick Start

### 1. Initialize

```bash
/fractary-spec:init
```

Creates:
- `.fractary/plugins/spec/config.json` - Configuration
- `/specs` directory - Active specs
- `.fractary/plugins/spec/archive-index.json` - Archive index

### 2. Generate Spec from Issue

```bash
/fractary-spec:generate 123
```

**What happens**:
1. Fetches issue #123 from GitHub
2. Classifies work type (feature, bug, infrastructure, etc.)
3. Selects appropriate template
4. Generates spec in `/specs/spec-123-title.md`
5. Comments on GitHub with spec link

### 3. Implement Following Spec

Use the generated spec as your implementation guide. The spec includes:
- Requirements breakdown
- Acceptance criteria (checkboxes)
- Technical approach
- Testing strategy

### 4. Validate Implementation

```bash
/fractary-spec:validate 123
```

**What it checks**:
- ✓ All requirements implemented
- ✓ Acceptance criteria met (checkboxes checked)
- ✓ Expected files modified
- ✓ Tests added
- ✓ Documentation updated

**Validation status**:
- **Complete** ✓: All checks pass, ready to archive
- **Partial** ⚠: Mostly complete, minor issues
- **Incomplete** ✗: Critical missing pieces

### 5. Archive When Complete

```bash
/fractary-spec:archive 123
```

**What happens**:
1. Pre-archive checks (issue closed? PR merged?)
2. Collects all specs for issue
3. Uploads to cloud (via fractary-file)
4. Updates archive index (local + cloud backup)
5. Comments on GitHub with archive links
6. Removes specs from local /specs
7. Commits removal to git

**Result**: Clean workspace, searchable archive, permanent cloud backup.

### 6. Read Archived Spec Later

```bash
/fractary-spec:read 123
```

Streams spec from cloud without downloading. Perfect for reference when:
- Reviewing historical decisions
- Similar work in new issue
- Understanding why something was built a certain way

## Spec Templates

### Auto-Classification

Plugin automatically selects template based on issue labels:

| Work Type | Detected By | Template |
|-----------|-------------|----------|
| Bug | Labels: bug, defect, hotfix | `bug.md.template` |
| Feature | Labels: feature, enhancement | `feature.md.template` |
| Infrastructure | Labels: infrastructure, devops, cloud | `infrastructure.md.template` |
| API | Labels: api, endpoint, rest, graphql | `api.md.template` |
| Other | No matching labels | `basic.md.template` |

Override with `--template` flag:
```bash
/fractary-spec:generate 123 --template infrastructure
```

### Template: Basic

**Use for**: General work, misc tasks, documentation updates

**Sections**:
- Overview
- Requirements
- Acceptance Criteria
- Implementation Notes
- Testing

**Example**:
```markdown
# Specification: Improve Error Messages

## Overview
Make error messages more user-friendly.

## Requirements
- [ ] Survey existing error messages
- [ ] Identify confusing messages
- [ ] Rewrite with user context
- [ ] Add help links

## Acceptance Criteria
- [ ] All user-facing errors have helpful messages
- [ ] Messages include next steps
- [ ] Help documentation linked
```

---

### Template: Feature

**Use for**: New features, enhancements, user stories

**Sections**:
- User Story (As a... I want... So that...)
- Requirements
- User Flow
- UI/UX Considerations
- Acceptance Criteria
- Rollout Plan

**Example**:
```markdown
# Feature Spec: Two-Factor Authentication

## User Story
As a **security-conscious user**
I want **two-factor authentication**
So that **my account is protected from unauthorized access**

## Requirements
- [ ] Support TOTP (Google Authenticator, Authy)
- [ ] Backup codes generation
- [ ] Remember device for 30 days
- [ ] Enforce for admin users

## User Flow
1. User enables 2FA in settings
2. System generates QR code
3. User scans with authenticator app
4. User enters verification code
5. System generates backup codes
6. 2FA enabled ✓

## UI/UX
- Clear onboarding wizard
- QR code prominent
- Backup codes downloadable
- Recovery process documented

## Rollout
- Phase 1: Optional for all users
- Phase 2: Required for admins
- Phase 3: Required for all users
```

---

### Template: Infrastructure

**Use for**: Infrastructure changes, cloud resources, deployment

**Sections**:
- Infrastructure Overview
- Resources Required
- Configuration
- Deployment Plan
- Monitoring & Alerts
- Rollback Procedure

**Example**:
```markdown
# Infrastructure Spec: Redis Cache Layer

## Infrastructure Overview
Add Redis cluster for application caching.

## Resources Required
- AWS ElastiCache Redis cluster (3 nodes)
- VPC subnet (existing)
- Security group (new)
- CloudWatch alarms

## Configuration
```yaml
cluster:
  node_type: cache.r6g.large
  nodes: 3
  version: 7.0
  encryption: true
```

## Deployment Plan
1. Provision ElastiCache cluster (15 min)
2. Update security groups
3. Configure app environment variables
4. Deploy app with Redis integration
5. Gradual traffic shift (20% → 100%)

## Monitoring
- Cache hit rate > 80%
- Latency < 5ms p99
- Memory usage < 70%
- Alarms on all metrics
```

---

### Template: API

**Use for**: REST APIs, GraphQL schemas, service endpoints

**Sections**:
- API Overview
- Endpoints
- Request/Response Schemas
- Authentication
- Error Handling
- Rate Limiting

**Example**:
```markdown
# API Spec: User Service v2

## Endpoints

### POST /api/v2/users
Create new user.

**Request**:
```json
{
  "email": "user@example.com",
  "password": "secure123",
  "name": "John Doe"
}
```

**Response** (201 Created):
```json
{
  "id": "usr_abc123",
  "email": "user@example.com",
  "name": "John Doe",
  "created_at": "2025-01-15T10:30:00Z"
}
```

**Authentication**: None (public endpoint)
**Rate Limit**: 10 requests/hour per IP
```

---

### Template: Bug

**Use for**: Bug fixes, defects, regressions

**Sections**:
- Bug Description
- Reproduction Steps
- Root Cause Analysis
- Fix Approach
- Testing Plan
- Prevention Measures

**Example**:
```markdown
# Bug Spec: Memory Leak in Worker Process

## Bug Description
Worker process memory grows indefinitely, causing OOM after 24h.

## Reproduction
1. Start worker process
2. Process 10,000 jobs
3. Observe memory: grows from 50MB → 2GB
4. Never released

## Root Cause
Event listeners not cleaned up after job completion.

## Fix Approach
- Add `removeAllListeners()` after job processing
- Implement max listener warning
- Add memory monitoring

## Testing
- Run 100,000 jobs
- Memory should stay < 200MB
- No listener leak warnings

## Prevention
- Add listener leak detection to CI
- Memory profiling in staging
- Automated alerts
```

## Multi-Spec Support

For large issues, create multiple specs:

```bash
# Phase 1: Authentication
/fractary-spec:generate 123 --phase 1 --title "Authentication"

# Phase 2: Authorization
/fractary-spec:generate 123 --phase 2 --title "Authorization"

# Phase 3: Audit Logging
/fractary-spec:generate 123 --phase 3 --title "Audit Logging"
```

**Creates**:
- `/specs/spec-123-phase1-authentication.md`
- `/specs/spec-123-phase2-authorization.md`
- `/specs/spec-123-phase3-audit-logging.md`

**Benefits**:
- Manageable spec size
- Clear phase boundaries
- Independent review
- Flexible implementation

**All archived together** when issue #123 closes.

## Validation

### Running Validation

```bash
/fractary-spec:validate 123
```

### Validation Checks

**1. Requirements Coverage**
```
✓ All requirements implemented
⚠ 1 of 5 requirements not addressed
✗ 3 of 5 requirements missing
```

**2. Acceptance Criteria**
```
✓ All acceptance criteria met (8/8 checkboxes)
⚠ 6/8 criteria met, 2 pending
✗ Only 3/8 criteria met
```

**3. Files Modified**
```
✓ Expected files modified:
  - src/auth/oauth.ts ✓
  - tests/auth/oauth.test.ts ✓
  - docs/api/auth.md ✓

⚠ Unexpected file: src/unrelated.ts
```

**4. Tests Added**
```
✓ Test files found
⚠ No test file for src/auth/oauth.ts
✗ No tests added
```

**5. Documentation Updated**
```
✓ docs/api/auth.md updated
⚠ No docs found for new feature
✗ Docs unchanged
```

### Validation Report

```
=== Spec Validation Report ===

Spec: spec-123-oauth-integration.md
Issue: #123

Requirements: ✓ Complete (5/5)
Acceptance Criteria: ✓ Complete (8/8)
Files Modified: ✓ Expected files present
Tests: ✓ Test coverage added
Documentation: ✓ Docs updated

Overall: ✓ COMPLETE - Ready to archive

=== End Report ===
```

## Archival

### Pre-Archive Checks

**Required** (blocking):
- ✓ Issue closed OR PR merged
- ✓ Specs exist for issue

**Warnings** (prompt user):
- ⚠ Validation not complete
- ⚠ Documentation not updated
- ⚠ PR not merged

### Archival Process

```bash
/fractary-spec:archive 123
```

**Steps**:
1. **Pre-checks**: Verify issue status
2. **Collect**: Find all specs for issue (including multi-phase)
3. **Upload**: Upload to cloud via fractary-file
4. **Index**: Update archive index (local + cloud backup)
5. **GitHub**: Comment on issue and PR with archive links
6. **Remove**: Delete local specs from /specs
7. **Commit**: Git commit the removal

### Archive Location

**Cloud storage**:
```
archive/specs/{year}/{issue_number}.md
archive/specs/{year}/{issue_number}-phase{N}.md
```

**Example**:
```
archive/specs/2025/123.md
archive/specs/2025/123-phase1.md
archive/specs/2025/123-phase2.md
```

**Index** (two-tier for disaster recovery):
- Local: `.fractary/plugins/spec/archive-index.json`
- Cloud: `archive/specs/.archive-index.json`

### GitHub Comments

**On Issue**:
```markdown
✅ Work Archived

Specifications archived for this issue:
- [Spec: OAuth Integration](https://storage.example.com/specs/2025/123.md) (24.5 KB)

Archived: 2025-01-15 14:30 UTC
Validation: Complete ✓

This spec is permanently stored in cloud archive.
```

**On Pull Request**:
```markdown
✅ Implementation Archived

This PR's specifications have been archived:
- [Spec: OAuth Integration](https://storage.example.com/specs/2025/123.md)

Archived from: /specs/spec-123-oauth-integration.md
```

## Reading Archived Specs

### Basic Read

```bash
/fractary-spec:read 123
```

Streams spec from cloud without downloading.

**Output**:
```markdown
# Specification: OAuth Integration

## Overview
Implement OAuth 2.0 authentication...

[... full spec content ...]
```

### Search Archives

```bash
/fractary-spec:search "authentication"
```

Searches archive index, returns matching specs with links.

### Archive Index

View all archived specs:
```bash
cat .fractary/plugins/spec/archive-index.json | jq '.archives[]'
```

**Index entry**:
```json
{
  "issue_number": "123",
  "specs": [
    {
      "local_path": "spec-123-oauth.md",
      "cloud_path": "archive/specs/2025/123.md",
      "url": "https://storage.example.com/...",
      "size_bytes": 24576,
      "archived_at": "2025-01-15T14:30:00Z"
    }
  ],
  "validation_status": "complete",
  "pr_url": "https://github.com/org/repo/pull/456"
}
```

## FABER Integration

### Automatic Workflow

In `.faber.config.toml`:

```toml
[workflow.architect]
generate_spec = true
spec_plugin = "fractary-spec"

[workflow.evaluate]
validate_spec = true

[workflow.release]
archive_spec = true
```

**During FABER workflow**:
- **Architect phase**: Spec generated automatically
- **Build phase**: You implement following spec
- **Evaluate phase**: Spec validation runs
- **Release phase**: Spec archived automatically

**No manual commands needed!** FABER orchestrates everything.

### Manual Override

Disable auto-archival:
```toml
[workflow.release]
archive_spec = false
```

Then manually archive:
```bash
/fractary-spec:archive 123
```

## Configuration

Edit `.fractary/plugins/spec/config.json`:

```json
{
  "schema_version": "1.0",
  "storage": {
    "local_path": "/specs",
    "cloud_archive_path": "archive/specs/{year}/{issue_number}.md"
  },
  "archive": {
    "auto_archive_on": {
      "issue_close": true,
      "pr_merge": true,
      "faber_release": true
    },
    "pre_archive": {
      "require_validation": false,
      "check_docs_updated": "warn",
      "check_pr_merged": "warn",
      "prompt_user": true
    }
  },
  "validation": {
    "check_requirements": true,
    "check_acceptance_criteria": true,
    "check_files_modified": true,
    "check_tests_added": true,
    "check_docs_updated": true
  },
  "github_integration": {
    "comment_on_generate": true,
    "comment_on_archive": true,
    "include_validation_status": true
  }
}
```

### Configuration Options

**Auto-archival triggers**: When to archive automatically
**Pre-archive checks**: What to check before archiving
**Validation settings**: Which checks to perform
**GitHub integration**: Comment behavior

## Best Practices

### 1. Generate Early

Generate specs in Architect phase, before implementation. Specs guide development.

### 2. Use Multi-Spec for Large Issues

Break large issues into phases with separate specs. Easier to review and implement.

### 3. Check Acceptance Criteria

Update checkboxes as you implement. Visual progress tracking.

### 4. Validate Before Release

Run validation before creating PR. Catch missing pieces early.

### 5. Let FABER Handle Archival

Configure auto-archival in FABER. Consistent and reliable.

### 6. Link Archived Specs in Docs

Reference archived specs in living documentation:
```markdown
See [archived spec](https://storage.example.com/specs/2025/123.md) for implementation details.
```

### 7. Don't Edit Archived Specs

Archived specs are historical record. Create new spec for changes.

### 8. Regular Archive Cleanup

If not using auto-archival, clean up regularly:
```bash
# Archive all closed issues
for issue in $(gh issue list --state closed --json number --jq '.[].number'); do
  /fractary-spec:archive $issue
done
```

## Troubleshooting

### Spec generation fails - issue not found

**Cause**: Invalid issue number or GitHub access issue

**Solution**:
- Verify issue exists: `gh issue view 123`
- Check GitHub token: `gh auth status`
- Ensure fractary-work plugin configured

### Template not found

**Cause**: Invalid template name or plugin issue

**Solution**: Use available templates (basic, feature, infrastructure, api, bug) or omit `--template` for auto-classification

### Validation fails - spec not found

**Cause**: Spec doesn't exist for issue

**Solution**: Generate spec first: `/fractary-spec:generate 123`

### Archive fails - pre-checks failed

**Cause**: Issue not closed or PR not merged

**Solution**:
- Close issue first: `gh issue close 123`
- Or merge PR first
- Or use `--force` flag (not recommended)

### Archive fails - upload error

**Cause**: fractary-file plugin misconfigured

**Solution**:
- Check file plugin config: `cat .fractary/plugins/file/config.json`
- Test upload: Use @agent-fractary-file:file-manager for test upload
- Verify cloud credentials

### Archive index corrupted

**Cause**: Manual editing or plugin crash

**Solution**: Sync from cloud backup:
```bash
# Plugin automatically syncs on init
/fractary-spec:init
```

### Can't read archived spec

**Cause**: Archive index out of sync or cloud access issue

**Solution**:
- Rebuild index from cloud
- Check file plugin configuration
- Verify cloud credentials

## Recovery from Data Loss

### Disaster Recovery

If you lose local environment:

```bash
# 1. Clone repo
git clone https://github.com/org/repo

# 2. Initialize spec plugin
/fractary-spec:init

# Output:
# Syncing archive index from cloud...
# ✓ Recovered 50 archived specs from cloud!

# 3. All archived specs accessible
/fractary-spec:read 123
```

**How it works**:
- Archive index backed up to cloud during each archival
- Init syncs index from cloud if local missing
- No data loss even if .fractary directory deleted

## Further Reading

- Plugin README: `plugins/spec/README.md`
- Configuration example: `plugins/spec/config/config.example.json`
- Templates: `plugins/spec/skills/spec-generator/templates/`
- Specs: `specs/SPEC-00029-08.md` through `SPEC-00029-11.md`

---

**Version**: 1.0 (2025-01-15)
