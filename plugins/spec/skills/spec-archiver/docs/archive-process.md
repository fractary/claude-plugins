# Archive Process Documentation

This document describes the archival process for specifications.

## Overview

Archival is the final step in the spec lifecycle. When work completes (issue closed, PR merged), specs are:
1. Uploaded to cloud storage
2. Indexed for future reference
3. Linked from GitHub
4. Removed from local storage (to prevent stale context)

## When to Archive

### Automatic Triggers

Based on configuration in `archive.auto_archive_on`:

**Issue Close**:
```json
{
  "auto_archive_on": {
    "issue_close": true
  }
}
```

When an issue is closed, archival can be triggered automatically (in FABER workflow) or manually.

**PR Merge**:
```json
{
  "auto_archive_on": {
    "pr_merge": true
  }
}
```

When a PR is merged, archival can be triggered.

**FABER Release**:
```json
{
  "auto_archive_on": {
    "faber_release": true
  }
}
```

In FABER workflow, Release phase automatically triggers archival.

### Manual Trigger

```bash
/fractary-spec:archive 123
```

Archive specs for issue #123 immediately.

## Pre-Archive Checks

Before archiving, several checks are performed:

### Required Checks (Must Pass)

1. **Issue Closed OR PR Merged**:
   - At least one must be true
   - Ensures work is complete
   - Can override with `--force`

2. **Specs Exist**:
   - At least one spec must exist for issue
   - Otherwise, nothing to archive

### Warning Checks (Prompt if Fail)

1. **Documentation Updated**:
   - Checks if any .md files (except specs) updated since spec creation
   - Warns if not updated
   - Suggests updating docs to reflect current state

2. **Validation Status**:
   - Checks `validated` field in spec frontmatter
   - Warns if not fully validated
   - Suggests running validation first

### Handling Warnings

If warnings detected and `--skip-warnings` not set:

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

User can:
1. Exit and update docs first
2. Proceed with archival despite warnings
3. Cancel operation

### Skipping Checks

```bash
# Skip all checks
/fractary-spec:archive 123 --force

# Skip warnings only (still check issue/PR status)
/fractary-spec:archive 123 --skip-warnings
```

## Archive Location

### Cloud Storage Path

Configured via `storage.cloud_archive_path`:
```json
{
  "storage": {
    "cloud_archive_path": "archive/specs/{year}/{issue_number}.md"
  }
}
```

Variables:
- `{year}`: Current year (e.g., "2025")
- `{issue_number}`: Issue number (e.g., "123")
- `{phase}`: Phase number for multi-spec (e.g., "phase1")

### Examples

**Single spec**:
```
Issue: 123
Local: /specs/WORK-00123-feature.md
Cloud: archive/specs/2025/123.md
URL: https://storage.example.com/specs/2025/123.md
```

**Multi-spec**:
```
Issue: 123
Local: /specs/WORK-00123-01-auth.md
Cloud: archive/specs/2025/123-phase1.md
URL: https://storage.example.com/specs/2025/123-phase1.md

Local: /specs/WORK-00123-02-oauth.md
Cloud: archive/specs/2025/123-phase2.md
URL: https://storage.example.com/specs/2025/123-phase2.md
```

## Archive Index

### Location

```
.fractary/plugins/spec/archive-index.json
```

### Format

```json
{
  "schema_version": "1.0",
  "last_updated": "2025-01-15T14:30:00Z",
  "archives": [
    {
      "issue_number": "123",
      "issue_url": "https://github.com/org/repo/issues/123",
      "issue_title": "Implement user authentication",
      "pr_url": "https://github.com/org/repo/pull/456",
      "archived_at": "2025-01-15T14:30:00Z",
      "archived_by": "Claude Code",
      "specs": [
        {
          "filename": "WORK-00123-01-auth.md",
          "local_path": "/specs/WORK-00123-01-auth.md",
          "cloud_url": "s3://bucket/archive/specs/2025/123-phase1.md",
          "public_url": "https://storage.example.com/specs/2025/123-phase1.md",
          "size_bytes": 15420,
          "checksum": "sha256:abc123...",
          "validated": true,
          "created": "2025-01-10T09:00:00Z"
        }
      ],
      "documentation_updated": true,
      "archive_notes": "All phases complete, validated"
    }
  ]
}
```

### Purpose

- Track all archived specs
- Provide lookup for reading archived specs
- Maintain metadata (URLs, checksums, validation status)
- Enable audit trail

## GitHub Integration

### Issue Comment

After archival, comment is added to issue:

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

If PR linked to issue, comment added there too:

```markdown
📦 Specifications Archived

Specifications for this PR have been archived:
- [WORK-00123-01-auth.md](https://storage.example.com/specs/2025/123-phase1.md)
- [WORK-00123-02-oauth.md](https://storage.example.com/specs/2025/123-phase2.md)

See issue #123 for complete archive details.
```

## Local Cleanup

After successful upload and index update:

1. **Remove spec files**:
   ```bash
   rm /specs/WORK-00123-01-auth.md
   rm /specs/WORK-00123-02-oauth.md
   ```

2. **Git remove**:
   ```bash
   git rm /specs/WORK-00123-01-auth.md
   git rm /specs/WORK-00123-02-oauth.md
   ```

3. **Git add index**:
   ```bash
   git add .fractary/plugins/spec/archive-index.json
   ```

4. **Git commit**:
   ```bash
   git commit -m "Archive specs for issue #123

   - Archived 2 specifications to cloud storage
   - Updated archive index
   - Issue: #123
   - PR: #456"
   ```

## Reading Archived Specs

After archival, specs can be read from cloud:

```bash
/fractary-spec:read 123
```

Process:
1. Look up issue #123 in archive index
2. Get cloud URL
3. Read from cloud via fractary-file plugin
4. Display content
5. No local download

## Multi-Spec Handling

When multiple specs exist for one issue:

1. **Collect All**: Find all `spec-{issue}*.md` files
2. **Upload Together**: Upload all before any cleanup
3. **Index Together**: Add single archive entry with all specs
4. **Comment Together**: Single comment with all URLs
5. **Remove Together**: Remove all local specs atomically
6. **Commit Together**: Single commit for all changes

This ensures atomicity: either all specs archived or none.

## Error Handling

### Upload Failure

**Symptoms**: Cloud upload fails for one or more specs

**Result**:
- Archival aborted
- No local cleanup
- Specs remain in /specs
- No index update
- No GitHub comments

**Recovery**: Retry archival, fix cloud storage issues

### Index Update Failure

**Symptoms**: Archive index update fails

**Result**:
- Specs uploaded to cloud
- But not tracked in index
- No local cleanup
- No GitHub comments

**Recovery**: Manually update index or retry archival

### Cleanup Failure

**Symptoms**: Local removal or git commit fails

**Result**:
- Specs uploaded and indexed (success!)
- But local copies remain
- Or commit not created

**Recovery**: Manually remove specs and commit, archival already complete

### GitHub Comment Failure

**Symptoms**: Comment API fails

**Result**:
- Archival complete
- Comment not added
- Non-critical error

**Recovery**: Manually add comment if desired, archival successful

## Best Practices

1. **Validate Before Archiving**: Run `/fractary-spec:validate` first
2. **Update Docs**: Ensure documentation reflects current state
3. **Review Warnings**: Don't blindly skip warnings
4. **Check Cloud Storage**: Ensure cloud storage configured correctly
5. **Backup Index**: Archive index should be in git
6. **Test Read**: After archival, test reading spec back

## Configuration Options

### Pre-Archive Settings

```json
{
  "archive": {
    "pre_archive": {
      "check_docs_updated": "warn",      // "warn", "error", "skip"
      "prompt_user": true,                // Prompt on warnings
      "require_validation": false         // Require validated=true
    }
  }
}
```

### Post-Archive Settings

```json
{
  "archive": {
    "post_archive": {
      "update_archive_index": true,      // Always true
      "comment_on_issue": true,          // Add GitHub comment
      "comment_on_pr": true,             // Comment on PR too
      "remove_from_local": true          // Clean local storage
    }
  }
}
```

## Security Considerations

- **Cloud Access**: Ensure proper cloud storage credentials
- **Public URLs**: Archived specs may be publicly accessible
- **Sensitive Data**: Don't include secrets in specs
- **Audit Trail**: Archive index provides complete audit trail
- **Immutability**: Archived specs shouldn't be modified

## Performance

- **Parallel Upload**: Multiple specs uploaded concurrently
- **Streaming**: Large specs streamed to cloud
- **Compression**: Consider compressing specs before upload
- **Batch Operations**: Multiple specs processed efficiently

## Archive Index: Two-Tier Storage System

### Problem: Index Loss Risk

The archive index stored in `.fractary/plugins/spec/archive-index.json` is git-ignored. If you lose your local environment, you lose the index - and without the index, you can't look up where your archived specs are stored in the cloud.

### Solution: Two-Tier Storage

The plugin uses a dual-storage approach for the archive index:

**Tier 1: Local Cache** (`.fractary/plugins/spec/archive-index.json`)
- Purpose: Fast lookups during normal operations
- Performance: Instant access, no network calls
- Risk: Lost if local environment lost
- Git: Ignored, not in version control

**Tier 2: Cloud Backup** (`archive/specs/.archive-index.json`)
- Purpose: Durable storage, disaster recovery
- Performance: Network access, synced automatically
- Risk: Protected, recoverable from cloud
- Git: Not applicable (stored in cloud)

### How It Works

#### During Archival

```
Archive Workflow
    ↓
Upload specs to cloud
    ↓
Update local index (Tier 1)
    ├─ Add archive entry
    ├─ Update last_updated timestamp
    └─ Update last_synced timestamp
    ↓
Backup index to cloud (Tier 2)
    ├─ Upload local index to cloud
    ├─ Store at: archive/specs/.archive-index.json
    └─ ✓ Index now recoverable!
    ↓
Remove local specs
    ↓
Complete
```

#### During Init (Recovery)

```
Init Plugin
    ↓
Check for local index
    ├─ If exists: Use it
    └─ If missing: Sync from cloud
    ↓
Sync from Cloud (Tier 2)
    ├─ Download: archive/specs/.archive-index.json
    ├─ Save to: .fractary/plugins/spec/archive-index.json
    └─ ✓ Index recovered!
    ↓
Plugin ready
```

#### During Read

```
Read Archived Spec
    ↓
Check local index (Tier 1)
    ├─ If exists: Use it
    └─ If missing: Sync from cloud (Tier 2)
    ↓
Look up spec URL in index
    ↓
Read spec from cloud
    ↓
Display content
```

### Index Schema (Enhanced)

```json
{
  "schema_version": "1.0",
  "last_updated": "2025-01-15T14:30:00Z",
  "last_synced": "2025-01-15T14:30:05Z",
  "archives": [
    {
      "issue_number": "123",
      "issue_url": "https://github.com/org/repo/issues/123",
      "archived_at": "2025-01-15T14:30:00Z",
      "specs": [...]
    }
  ]
}
```

**New Fields**:
- `last_synced`: When index was last backed up to cloud
- Helps detect stale local caches

### Sync Operations

#### Upload Sync (After Archival)

```bash
# Update local index first
update-index.sh "$LOCAL_INDEX" "$ENTRY_JSON" "$CLOUD_INDEX"

# Inside update-index.sh:
# 1. Update local cache
# 2. Call sync-index.sh upload
# 3. Backup to cloud
```

#### Download Sync (Init/Recovery)

```bash
# On init or when local missing
sync-index.sh download "$LOCAL_INDEX" "$CLOUD_INDEX"

# Process:
# 1. Check if cloud index exists
# 2. Download to local cache
# 3. Ready for use
```

### Fallback Behavior

If fractary-file plugin not available:

```
Archive Process (No Cloud Sync)
    ↓
Upload specs to cloud: ⚠️ Simulated (mock mode)
    ↓
Update local index: ✓ Success
    ↓
Backup index to cloud: ⚠️ Skipped (no plugin)
    ↓
Warning displayed:
    "⚠ Cloud backup unavailable, index only in local cache"
    "⚠ Recommendation: Backup .fractary directory"
    ↓
Continue (non-critical)
```

### Recovery Scenarios

#### Scenario 1: New Machine

```bash
# Clone repo on new machine
git clone repo

# .fractary directory not present (git-ignored)
ls .fractary/
# → directory doesn't exist

# Initialize plugin
/fractary-spec:init

# Output:
# Syncing archive index from cloud...
# ✓ Archive index synced from cloud
# ✓ Local cache updated
# ✅ Recovered 15 archived specs!

# Index now available
cat .fractary/plugins/spec/archive-index.json
# → Contains all archives
```

#### Scenario 2: Corrupted Local Index

```bash
# Local index corrupted
cat .fractary/plugins/spec/archive-index.json
# → Invalid JSON

# Re-sync from cloud
sync-index.sh download \
  .fractary/plugins/spec/archive-index.json \
  archive/specs/.archive-index.json

# ✓ Index recovered from cloud backup
```

#### Scenario 3: Lost Cloud Sync

```bash
# Cloud sync was disabled, no backup
# Local index exists but .fractary deleted

# Initialize plugin
/fractary-spec:init

# Output:
# ⚠ No cloud index found
# ℹ Creating new local index
# ⚠ Previous archives may be lost

# Manual recovery needed:
# - Restore .fractary from backup
# - Or manually rebuild index from cloud file listing
```

### Best Practices

1. **Always Enable Cloud Sync**:
   - Install fractary-file plugin
   - Ensures index backed up automatically

2. **Regular Backups**:
   - Even with cloud sync, backup `.fractary` directory
   - Provides extra safety net

3. **Test Recovery**:
   - Periodically test recovery process
   - Delete `.fractary` and run init
   - Verify specs accessible

4. **Monitor Sync Status**:
   - Check `last_synced` timestamp in index
   - Ensure it's recent after archival

5. **Handle Sync Failures Gracefully**:
   - If sync fails, warn but continue
   - Index still in local cache
   - Retry sync on next archival

### Configuration

Enable two-tier storage in `config.json`:

```json
{
  "storage": {
    "archive_index": {
      "local_cache": ".fractary/plugins/spec/archive-index.json",
      "cloud_backup": "archive/specs/.archive-index.json"
    }
  }
}
```

### Troubleshooting

**Q: Cloud sync fails during archival?**
A: Archival continues, but index only in local cache. Backup `.fractary` manually.

**Q: Local index missing on read?**
A: Plugin attempts cloud sync automatically. If cloud unavailable, operation fails.

**Q: How to force re-sync from cloud?**
A: Delete local index, then run `/fractary-spec:init` or `/fractary-spec:read`

**Q: Can I see sync status?**
A: Check `last_synced` field in local index:
```bash
jq '.last_synced' .fractary/plugins/spec/archive-index.json
```

**Q: What if both local and cloud lost?**
A: Manual recovery needed. List cloud files, rebuild index from metadata.
