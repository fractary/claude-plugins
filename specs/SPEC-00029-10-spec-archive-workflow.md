# SPEC-00029-10: Spec Archive Workflow

**Issue**: #29
**Phase**: 3 (fractary-spec Plugin)
**Dependencies**: SPEC-00029-08, SPEC-00029-09
**Status**: Draft
**Created**: 2025-01-15

## Overview

Implement spec-archiver skill to handle the complete archival workflow: collecting all specs for an issue, uploading to cloud storage, updating indexes, commenting on GitHub, and removing from local storage.

## Archive Triggers

Lifecycle-based triggers (not time-based):
1. Issue closed
2. PR merged
3. FABER Release phase complete
4. Manual command: `/fractary-spec:archive <issue>`

## Archive Workflow

```
Archive Requested for Issue #123
    ↓
Collect all specs for issue
    ├─ spec-123-phase1-auth.md
    └─ spec-123-phase2-oauth.md
    ↓
Check pre-archive conditions
    ├─ Issue closed? ✓
    ├─ PR merged? ✓
    ├─ Docs updated? ⚠ (warn)
    └─ User confirmation? (if warnings)
    ↓
Upload to cloud (via fractary-file)
    ├─ Upload spec-123-phase1-auth.md
    ├─ Get URL: s3://bucket/archive/specs/2025/123-phase1.md
    ├─ Upload spec-123-phase2-oauth.md
    └─ Get URL: s3://bucket/archive/specs/2025/123-phase2.md
    ↓
Update archive index
    ├─ Load .archive-index.json
    ├─ Add entry for issue #123
    └─ Save index
    ↓
Comment on GitHub
    ├─ Comment on issue #123
    └─ Comment on PR #456 (if exists)
    ↓
Remove from local
    ├─ Delete spec-123-phase1-auth.md
    ├─ Delete spec-123-phase2-oauth.md
    └─ Git commit (index update + removals)
    ↓
Return confirmation
```

## Pre-Archive Checks

### Required Checks
1. **Issue Status**: Must be closed OR PR must be merged
2. **Spec Exists**: At least one spec found for issue

### Warning Checks (Prompt User)
1. **Documentation Updated**: Warn if docs haven't been updated recently
2. **Validation Status**: Warn if specs not validated

### Example Prompt

```
⚠️  Pre-Archive Warnings

The following items may need attention:

1. Documentation hasn't been updated since spec creation
   → Consider updating docs to reflect current state

2. Spec validation status: partial
   → Some acceptance criteria may not be met

Do you want to:
1. Update documentation first
2. Archive anyway
3. Cancel

Enter selection [1-3]:
```

## Multi-Spec Handling

```bash
# Find all specs for issue
find /specs -name "spec-123*.md"

# Results:
# spec-123-phase1-auth.md
# spec-123-phase2-oauth.md

# Archive all
for spec in spec-123*.md; do
    fractary-file upload "$spec" "archive/specs/2025/$(basename $spec)"
done
```

## Archive Index Update

Add entry to `/specs/.archive-index.json`:

```json
{
  "issue_number": "123",
  "issue_url": "https://github.com/org/repo/issues/123",
  "issue_title": "Implement user authentication",
  "pr_url": "https://github.com/org/repo/pull/456",
  "archived_at": "2025-01-15T14:30:00Z",
  "archived_by": "Claude Code",
  "specs": [
    {
      "filename": "spec-123-phase1-auth.md",
      "local_path": "/specs/spec-123-phase1-auth.md",
      "cloud_url": "s3://bucket/archive/specs/2025/123-phase1.md",
      "public_url": "https://storage.example.com/specs/2025/123-phase1.md",
      "size_bytes": 15420,
      "checksum": "sha256:abc123...",
      "validated": true,
      "created": "2025-01-10T09:00:00Z"
    },
    {
      "filename": "spec-123-phase2-oauth.md",
      "local_path": "/specs/spec-123-phase2-oauth.md",
      "cloud_url": "s3://bucket/archive/specs/2025/123-phase2.md",
      "public_url": "https://storage.example.com/specs/2025/123-phase2.md",
      "size_bytes": 18920,
      "checksum": "sha256:def456...",
      "validated": true,
      "created": "2025-01-12T11:00:00Z"
    }
  ],
  "documentation_updated": true,
  "archive_notes": "All phases complete, validated"
}
```

## GitHub Comments

### Issue Comment

```markdown
✅ Work Archived

This issue has been completed and archived!

**Specifications**:
- [Phase 1: Authentication](https://storage.example.com/specs/2025/123-phase1.md) (15.4 KB)
- [Phase 2: OAuth Integration](https://storage.example.com/specs/2025/123-phase2.md) (18.9 KB)

**Archived**: 2025-01-15 14:30 UTC
**Validation**: All specs validated ✓

These specifications are permanently stored in cloud archive for future reference.
```

### PR Comment

```markdown
📦 Specifications Archived

Specifications for this PR have been archived:
- [spec-123-phase1-auth.md](https://storage.example.com/specs/2025/123-phase1.md)
- [spec-123-phase2-oauth.md](https://storage.example.com/specs/2025/123-phase2.md)

See issue #123 for complete archive details.
```

## Git Operations

```bash
# After archival
git rm /specs/spec-123-phase1-auth.md
git rm /specs/spec-123-phase2-oauth.md
git add /specs/.archive-index.json
git commit -m "Archive specs for issue #123

- Archived 2 specifications to cloud storage
- Updated archive index
- Issue: #123
- PR: #456"
```

## Reading Archived Specs

```bash
# Read without downloading
/fractary-spec:read 123

# Uses fractary-file read operation
# Displays spec content from cloud
# No local file created
```

## Commands

### /fractary-spec:archive

```markdown
Archive specifications for completed issue

Usage:
  /fractary-spec:archive <issue_number> [--force] [--skip-warnings]

Options:
  --force: Skip pre-archive checks
  --skip-warnings: Don't prompt for warnings, archive anyway

Examples:
  /fractary-spec:archive 123
  /fractary-spec:archive 123 --skip-warnings
```

### /fractary-spec:read

```markdown
Read archived specification from cloud storage

Usage:
  /fractary-spec:read <issue_number> [--phase <n>]

Examples:
  /fractary-spec:read 123
  /fractary-spec:read 123 --phase 1
```

## Success Criteria

- [ ] Multi-spec archival per issue
- [ ] Pre-archive checks and warnings
- [ ] Upload to cloud via fractary-file
- [ ] Archive index maintained
- [ ] GitHub comments on issues and PRs
- [ ] Local cleanup (git rm)
- [ ] Read archived specs without download
- [ ] FABER integration ready

## Timeline

**Estimated**: 1 week

## Next Steps

- **SPEC-00029-11**: FABER integration for automatic archival
