---
name: fractary-spec:archive
description: Archive specifications for completed work
---

Archive specifications to cloud storage when work is complete. Specs are uploaded, indexed, linked from GitHub, and removed from local storage to prevent stale context.

## Usage

```bash
/fractary-spec:archive <issue_number> [options]
```

## Arguments

- `<issue_number>`: GitHub issue number (required)

## Options

- `--force`: Skip all pre-archive checks
- `--skip-warnings`: Don't prompt for warnings, archive anyway

## Examples

### Basic Usage

```bash
/fractary-spec:archive 123
```

Performs all checks, prompts if warnings.

### Skip Warnings

```bash
/fractary-spec:archive 123 --skip-warnings
```

Archives even if docs not updated or validation partial.

### Force Archive

```bash
/fractary-spec:archive 123 --force
```

Skips all checks, archives immediately.

## Pre-Archive Checks

### Required (Must Pass)

1. **Issue Closed OR PR Merged**:
   - At least one must be true
   - Override with `--force`

2. **Specs Exist**:
   - At least one spec for the issue
   - Cannot override

### Warnings (Prompt Unless Skipped)

1. **Documentation Updated**:
   - Warns if no doc updates since spec creation
   - Suggests updating docs

2. **Validation Status**:
   - Warns if not fully validated
   - Suggests running validation

## Warning Prompt

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

## What It Does

1. **Find All Specs**: Collects all specs for issue (multi-spec support)
2. **Check Conditions**: Validates pre-archive requirements
3. **Upload to Cloud**: Uses fractary-file plugin to upload
4. **Update Index**: Adds entry to `.fractary/plugins/spec/archive-index.json`
5. **Comment on GitHub**: Adds archive URLs to issue and PR
6. **Remove Local**: Cleans up local /specs directory
7. **Git Commit**: Commits index update and removals

## Output

```
🎯 STARTING: Spec Archiver
Issue: #123
Specs found: 2
  - spec-123-phase1-auth.md
  - spec-123-phase2-oauth.md
───────────────────────────────────────

Checking pre-archive conditions...
✓ Issue closed
✓ PR merged
⚠ Documentation not updated (warning)
✓ Validation complete

Uploading to cloud...
✓ spec-123-phase1-auth.md → https://storage.example.com/specs/2025/123-phase1.md
✓ spec-123-phase2-oauth.md → https://storage.example.com/specs/2025/123-phase2.md

Updating archive index...
✓ Archive index updated

Commenting on GitHub...
✓ Issue #123 commented
✓ PR #456 commented

Cleaning local storage...
✓ Local specs removed
✓ Git commit created

✅ COMPLETED: Spec Archiver
Issue: #123
Specs archived: 2
───────────────────────────────────────
Next: Specs available via /fractary-spec:read 123
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

## Archive Index

Entry added to `.fractary/plugins/spec/archive-index.json`:

```json
{
  "issue_number": "123",
  "issue_url": "https://github.com/org/repo/issues/123",
  "archived_at": "2025-01-15T14:30:00Z",
  "specs": [
    {
      "filename": "spec-123-phase1-auth.md",
      "cloud_url": "https://storage.example.com/specs/2025/123-phase1.md",
      "size_bytes": 15420
    }
  ]
}
```

## Reading Archived Specs

After archival, read from cloud:

```bash
/fractary-spec:read 123
```

No local download, streams from cloud.

## FABER Integration

In FABER workflow, archival runs automatically during Release phase:

```toml
[workflow.release]
archive_spec = true
archive_before_branch_delete = true
```

## Multi-Spec Handling

When multiple specs exist:
- All uploaded together
- Single archive index entry
- One comment with all URLs
- All removed together
- Atomic operation

## Error Handling

### Upload Failure
- Archival aborted
- Local specs remain
- Can retry

### Index Update Failure
- Critical error
- Specs uploaded but not indexed
- Manual index update or retry

### Cleanup Failure
- Archival complete
- Local removal failed
- Manual cleanup or leave for next gc

### GitHub Comment Failure
- Non-critical
- Archival still complete
- Can manually comment

## Troubleshooting

**Error: No specs found**:
- Generate specs first
- Check issue number

**Error: Issue not closed**:
- Close issue first
- Or use `--force`

**Warning: Docs not updated**:
- Update documentation
- Or use `--skip-warnings`

**Error: Cloud upload failed**:
- Check cloud storage configuration
- Check fractary-file plugin
- Retry after fixing
