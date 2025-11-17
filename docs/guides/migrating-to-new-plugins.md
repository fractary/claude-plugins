# Migrating Your Project to New Plugins

Quick guide for projects using FABER to adopt the new fractary-file, fractary-docs, fractary-spec, and fractary-logs plugins.

## Overview

The new utility plugins provide better organization and cloud storage for your FABER projects:

- **fractary-file**: Cloud storage for artifacts (S3, R2, GCS, Google Drive, local)
- **fractary-docs**: Living documentation with templates and validation
- **fractary-spec**: Ephemeral specifications that archive when complete
- **fractary-logs**: Session logs with hybrid retention (local + cloud)

## Benefits

### Before
```
my-project/
├── docs/           # Living documentation
├── SPEC-*.md       # Old specs mixed with active ones ⚠️
├── logs/           # Growing indefinitely ⚠️
└── .fractary/      # Local only ⚠️
```

### After
```
my-project/
├── /docs           # Living documentation (synced with codex)
├── /specs          # Active specs only (old ones archived ✓)
├── /logs           # Recent logs only (old ones archived ✓)
└── .fractary/      # Configuration (cloud-backed ✓)
```

**Key improvements**:
- ✓ Clean local context (old specs/logs archived to cloud)
- ✓ Searchable history (find archived content easily)
- ✓ Better codex integration (standardized front matter)
- ✓ Consistent documentation across projects
- ✓ Multi-provider storage (switch between S3, R2, GCS, etc.)

## Migration Time Estimate

- **Quick Start (minimal migration)**: 5-10 minutes
- **Full migration with existing content**: 30-45 minutes
- **Large projects (100+ docs/specs)**: 1-2 hours

**Factors affecting time**:
- Number of existing docs/specs to migrate
- Cloud storage setup complexity
- Testing thoroughness

## Quick Start (5 minutes)

⏱️ **Estimated time**: 5-10 minutes

### 1. Initialize New Plugins

⏱️ **Time**: 2-3 minutes

```bash
# Initialize file plugin (choose your storage provider)
/fractary-file:init --handler local  # or: s3, r2, gcs, gdrive

# Initialize other plugins (uses file plugin for storage)
/fractary-docs:init
/fractary-spec:init
/fractary-logs:init
```

This creates:
- `.fractary/plugins/file/config.json` - Storage configuration
- `.fractary/plugins/docs/config.json` - Documentation settings
- `.fractary/plugins/spec/config.json` - Spec lifecycle settings
- `.fractary/plugins/logs/config.json` - Log retention settings
- `/docs`, `/specs`, `/logs` directories

### 2. Update FABER Config

⏱️ **Time**: 1-2 minutes

Edit `.faber.config.toml`:

```toml
# Add plugin declarations
[plugins]
file = "fractary-file"
docs = "fractary-docs"
spec = "fractary-spec"
logs = "fractary-logs"

# Enable in workflow phases
[workflow.architect]
generate_spec = true

[workflow.evaluate]
validate_spec = true

[workflow.release]
archive_specs = true
archive_logs = true
```

### 3. Test with New Workflow

⏱️ **Time**: 2-5 minutes (per test issue)

```bash
# Run FABER with a new or test issue
/faber:run <issue> --autonomy guarded

# You'll see:
# - Spec generated in /specs during Architect
# - Session captured in /logs during Build
# - Spec validated during Evaluate
# - Everything archived during Release
```

That's it! New issues will automatically use the new plugins.

## Migrating Existing Content (Optional)

⏱️ **Estimated time**: 15-30 minutes (depends on content volume)

If you have existing docs, specs, or logs, migrate them:

### Migrate Documentation

⏱️ **Time**: 5-10 minutes

Add codex-compatible front matter to existing docs:

```bash
# Bulk add front matter
./tools/add-frontmatter-bulk.sh docs/

# Or manually migrate specific files
./tools/migrate-docs.sh docs/architecture/design.md
```

**What it does**:
- Adds front matter with `codex_sync: true`
- Preserves existing content
- Makes docs discoverable by codex

**Example**:
```markdown
# Before
# Database Architecture

Our database uses PostgreSQL...

# After
---
title: "Database Architecture"
type: design
created: "2025-01-15"
codex_sync: true
---

# Database Architecture

Our database uses PostgreSQL...
```

### Migrate Specifications

⏱️ **Time**: 5-10 minutes

Move old specs to /specs with proper front matter:

```bash
# Migrate all specs from current directory
./tools/migrate-specs.sh .

# Or from specific directory
./tools/migrate-specs.sh old-specs/
```

**What it does**:
- Moves SPEC-*.md files to /specs
- Adds spec front matter (spec_id, issue_number, status)
- Marks as archived (already complete)

**Note**: Old specs are marked `status: archived` so they'll be ready for cloud archival but won't interfere with new work.

### Archive Old Specs

⏱️ **Time**: 5-15 minutes (depends on number of specs)

Once migrated, archive old specs to cloud:

```bash
# Archive specs for specific issues
/fractary-spec:archive 101
/fractary-spec:archive 102

# Or archive all archived specs
find /specs -name "*.md" -exec grep -l "status: archived" {} \; | while read spec; do
  ISSUE=$(grep "issue_number:" "$spec" | cut -d: -f2 | tr -d ' ')
  /fractary-spec:archive "$ISSUE"
done
```

### Validate Migration

⏱️ **Time**: 1-2 minutes

Check everything is set up correctly:

```bash
./tools/validate-migration.sh
```

Expected output:
```
=== Migration Validation ===

Checking plugin dependencies...
  ✓ fractary-file dependency present
  ✓ fractary-docs dependency present
  ✓ fractary-spec dependency present
  ✓ fractary-logs dependency present

Checking configuration...
  ✓ Plugin configuration present in .faber.config.toml

Checking directory structure...
  ✓ /docs exists (15 markdown files)
  ✓ /specs exists (3 markdown files)
  ✓ /logs exists (0 markdown files)

Checking documentation front matter...
  ✓ All docs have codex_sync front matter

=== Validation Complete ===
```

## What Changes in Your Workflow

### Before (Without New Plugins)

```bash
# Manual spec creation
echo "# Spec for #123" > SPEC-123.md

# Specs stay in repo forever
git add SPEC-*.md
git commit -m "Add spec"

# Docs manually created
echo "# Design" > docs/design.md

# No session logging
```

### After (With New Plugins)

```bash
# Automatic spec generation
/faber:run 123

# During workflow:
# ✓ Spec generated from issue automatically
# ✓ Session captured automatically
# ✓ Logs retained locally for 30 days
# ✓ Everything archived when complete

# Specs removed from local (in cloud)
# Logs archived to cloud (searchable)
# Docs remain in git (with codex sync)
```

### Archive Command

New command to manually archive completed work:

```bash
# Archive specs and logs for a closed issue
/faber:archive 123

# Or let FABER do it automatically during release phase
```

## Configuration Options

### Storage Provider

Choose where to store archived specs and logs:

**Local** (default - good for testing):
```json
{
  "active_handler": "local",
  "handlers": {
    "local": {
      "base_path": "./storage"
    }
  }
}
```

**AWS S3** (production):
```json
{
  "active_handler": "s3",
  "handlers": {
    "s3": {
      "region": "us-east-1",
      "bucket_name": "my-project-archives"
    }
  }
}
```

**Cloudflare R2** (cost-effective):
```json
{
  "active_handler": "r2",
  "handlers": {
    "r2": {
      "account_id": "${R2_ACCOUNT_ID}",
      "bucket_name": "my-project-archives"
    }
  }
}
```

Set environment variables:
```bash
export R2_ACCOUNT_ID="your-account-id"
export R2_ACCESS_KEY_ID="your-access-key"
export R2_SECRET_ACCESS_KEY="your-secret-key"
```

See `plugins/file/README.md` for all providers (S3, R2, GCS, Google Drive).

### Retention Settings

Customize how long to keep logs locally:

```json
{
  "retention": {
    "local_days": 30,
    "auto_archive_on_age": true
  }
}
```

### Spec Archival

Control when specs are archived:

```json
{
  "archive": {
    "auto_archive_on": {
      "issue_close": true,
      "pr_merge": true,
      "faber_release": true
    }
  }
}
```

## Reading Archived Content

### Read Archived Spec

```bash
# Stream spec from cloud (no download)
/fractary-spec:read 123

# Shows the spec content even though it's not local
```

### Read Archived Logs

```bash
# Read session logs from cloud
/fractary-logs:read 123

# Search across local and archived logs
/fractary-logs:search "OAuth error"
```

### Search Archive

```bash
# Search specs (hybrid: local + cloud)
/fractary-spec:search "authentication"

# Search logs with filters
/fractary-logs:search "error" --since 2024-01-01 --type deployment
```

## Rollback Procedures

⏱️ **Time to rollback**: 5-10 minutes

If you need to rollback the migration, follow these procedures:

### Scenario 1: Rollback Before Any Work Completed

**Situation**: Just initialized plugins, no work done yet.

⏱️ **Time**: 2-3 minutes

**Steps**:
1. **Remove FABER config changes**:
   ```bash
   # Edit .faber.config.toml and remove:
   # [plugins] section with file/docs/spec/logs
   # [workflow.architect] generate_spec
   # [workflow.release] archive settings
   ```

2. **Remove plugin configurations** (optional):
   ```bash
   rm -rf .fractary/plugins/{file,docs,spec,logs}
   ```

3. **Remove directories** (optional, if empty):
   ```bash
   # Only if no content
   rmdir /docs /specs /logs 2>/dev/null
   ```

**Result**: System back to pre-migration state.

---

### Scenario 2: Rollback After Content Migration

**Situation**: Migrated docs/specs, want to undo.

⏱️ **Time**: 5-10 minutes

**Steps**:
1. **Restore original docs** (if backed up):
   ```bash
   # If you made backups before migration
   cp -r docs.backup/* docs/
   ```

2. **Remove front matter from docs**:
   ```bash
   # Remove YAML front matter (---...--- blocks) from docs
   for file in docs/**/*.md; do
     sed -i '/^---$/,/^---$/d' "$file"
   done
   ```

3. **Move specs back** (if you moved them):
   ```bash
   # If specs were in root, move back
   mv /specs/SPEC-*.md .
   rmdir /specs
   ```

4. **Remove FABER config changes** (from Scenario 1)

**Result**: Docs and specs back to original state.

---

### Scenario 3: Rollback After Cloud Archival

**Situation**: Content archived to cloud, want to restore locally.

⏱️ **Time**: 10-15 minutes

**Steps**:
1. **Download archived content**:
   ```bash
   # For each archived spec
   /fractary-spec:read 123 > SPEC-123.md

   # For archived logs
   /fractary-logs:read 123 > logs-123.md
   ```

2. **Alternative: Download from cloud directly**:
   ```bash
   # If using fractary-file directly
   Use @agent-fractary-file:file-manager to download:
   {
     "operation": "download",
     "parameters": {
       "remote_path": "archive/specs/2025/123.md",
       "local_path": "./SPEC-123.md"
     }
   }
   ```

3. **Remove plugin config** (as in Scenario 1)

**Result**: Archived content restored locally.

---

### Scenario 4: Partial Rollback (Keep Some Plugins)

**Situation**: Want to keep some plugins but not others.

⏱️ **Time**: 5-10 minutes

**Example: Keep docs/file, remove spec/logs**:

1. **Update FABER config**:
   ```toml
   [plugins]
   file = "fractary-file"     # Keep
   docs = "fractary-docs"     # Keep
   # spec = "fractary-spec"   # Remove
   # logs = "fractary-logs"   # Remove

   [workflow.architect]
   # generate_spec = true     # Remove

   [workflow.release]
   # archive_specs = true     # Remove
   # archive_logs = true      # Remove
   ```

2. **Restore affected content** (specs/logs as needed)

3. **Test**:
   ```bash
   /faber:run <test-issue> --autonomy guarded
   ```

**Result**: Selective plugin usage.

---

### Prevention: Create Backup Before Migration

**Recommended**: Before migrating, create backup:

```bash
# Backup entire project
tar czf project-backup-$(date +%Y%m%d).tar.gz \
  docs/ \
  SPEC-*.md \
  .faber.config.toml \
  .fractary/

# Or use git
git add -A
git commit -m "Pre-migration backup"
git tag pre-migration-backup
```

**Restore from backup**:
```bash
# From tar
tar xzf project-backup-YYYYMMDD.tar.gz

# From git
git reset --hard pre-migration-backup
```

---

### Rollback Checklist

- [ ] Backup created before migration
- [ ] Know which scenario applies
- [ ] Have access to cloud storage (if needed)
- [ ] FABER config backed up
- [ ] Tested rollback in dev environment first
- [ ] Team notified (if shared project)
- [ ] Documented reason for rollback

---

### After Rollback

1. **Document issues encountered**:
   - What went wrong?
   - What would help next time?

2. **Consider partial migration**:
   - Start with just one plugin
   - Gradual adoption
   - Test thoroughly at each step

3. **Get help if needed**:
   - Review troubleshooting guide
   - Check GitHub issues
   - Ask for support

---

### Rollback FAQ

**Q: Can I rollback after archiving content?**
A: Yes, use `/fractary-spec:read` and `/fractary-logs:read` to retrieve from cloud.

**Q: Will I lose archived content if I rollback?**
A: No, content remains in cloud storage. Only local config changes revert.

**Q: Can I rollback just one plugin?**
A: Yes, see Scenario 4 for partial rollback.

**Q: How long does rollback take?**
A: 5-15 minutes depending on scenario and content volume.

**Q: Will rollback affect other team members?**
A: Not if you haven't pushed changes. If pushed, coordinate with team.

---

## Troubleshooting

### Plugin not found

**Error**: Command `/fractary-file:init` not recognized

**Solution**: Install plugins from repository:
```bash
# Ensure plugins are in ./plugins directory
ls plugins/file plugins/docs plugins/spec plugins/logs
```

### Configuration not initialized

**Error**: No configuration file found

**Solution**: Run init commands:
```bash
/fractary-file:init
/fractary-docs:init
/fractary-spec:init
/fractary-logs:init
```

### Upload fails

**Error**: Failed to upload to cloud storage

**Solution**: Check file plugin configuration:
```bash
# Verify configuration
cat .fractary/plugins/file/config.json

# Check environment variables
env | grep -E "(AWS|R2|GOOGLE)"

# Test connection
/fractary-file:test-connection
```

### Old specs interfering

**Problem**: Old specs polluting context

**Solution**: Archive them:
```bash
# Move old specs to /specs if not there
./tools/migrate-specs.sh .

# Archive them
/fractary-spec:archive <issue>
```

## FAQ

### Do I need cloud storage?

**No**. The local handler works without any cloud provider:
```bash
/fractary-file:init --handler local
```

This stores "archived" content in `./storage` on your machine. Good for:
- Development and testing
- Projects without cloud access
- Privacy-sensitive work

For production or team projects, cloud storage is recommended.

### What happens to my existing workflow?

**No disruption**. The new plugins enhance FABER but don't break existing functionality:
- Old commands still work
- Configuration is additive
- Migration is optional
- Rollback is easy

### Can I switch storage providers?

**Yes**. Change the `active_handler` in config:

```json
{
  "active_handler": "r2"  // changed from "local"
}
```

Archives already uploaded to old provider remain there. New uploads use new provider.

### How much does cloud storage cost?

Very little:
- **R2**: $0.015/GB/month storage, $0 egress
- **S3**: $0.023/GB/month storage, egress varies
- **GCS**: $0.020/GB/month storage, egress varies

For typical projects (1-10 GB archives): $0.15-$1.50/month.

### Do archived specs/logs stay in git history?

Yes, git history is unchanged. Only future commits exclude archived specs/logs.

To clean git history (optional):
```bash
# Remove old specs from git history (advanced)
git filter-branch --tree-filter 'rm -f SPEC-*.md' HEAD

# Only do this if you understand git history rewriting
```

## Next Steps

1. ✅ Initialize plugins (`/fractary-file:init` etc.)
2. ✅ Update FABER config
3. ✅ Test with new issue
4. ⏸️ Optionally migrate existing content
5. ⏸️ Configure cloud storage (if desired)
6. ⏸️ Archive old specs/logs

## Support

For help:
- **Plugin docs**: See `plugins/*/README.md`
- **Troubleshooting**: See `docs/guides/troubleshooting.md`
- **Specs**: See `specs/SPEC-00029-*.md`
- **Issues**: Report on GitHub

## Learn More

- [Plugin Developer Migration Guide](./migrating-plugin-to-new-utils.md) - For plugin authors
- [fractary-file Guide](./fractary-file-guide.md) - Cloud storage details
- [fractary-spec Guide](./fractary-spec-guide.md) - Spec lifecycle
- [fractary-logs Guide](./fractary-logs-guide.md) - Log management

## Version

**v1.0** (2025-01-15) - Initial release
