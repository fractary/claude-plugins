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

## Quick Start (5 minutes)

### 1. Initialize New Plugins

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

If you have existing docs, specs, or logs, migrate them:

### Migrate Documentation

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
- **Specs**: See `docs/specs/SPEC-0029-*.md`
- **Issues**: Report on GitHub

## Learn More

- [Plugin Developer Migration Guide](./migrating-plugin-to-new-utils.md) - For plugin authors
- [fractary-file Guide](./fractary-file-guide.md) - Cloud storage details
- [fractary-spec Guide](./fractary-spec-guide.md) - Spec lifecycle
- [fractary-logs Guide](./fractary-logs-guide.md) - Log management

## Version

**v1.0** (2025-01-15) - Initial release
