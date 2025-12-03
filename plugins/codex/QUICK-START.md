# Codex Plugin - Quick Start Guide

**Get up and running with codex sync in 5 minutes**

---

## Prerequisites

1. **Fractary-Repo Plugin** must be installed and configured
   ```bash
   # Check if repo plugin is available
   /fractary-repo:init --help
   ```

2. **Git Repository** with a remote (GitHub, GitLab, or Bitbucket)
   ```bash
   git remote -v
   # Should show your organization's remote
   ```

3. **Codex Repository** exists in your organization
   - Naming convention: `codex.{organization}.{tld}`
   - Examples: `codex.fractary.com`, `codex.myorg.io`

---

## Step 1: Initialize Configuration (2 minutes)

### Run the Init Command

```bash
/fractary-codex:init
```

### What Happens

1. **Auto-Detection**: Extracts organization from your git remote
   ```
   Detected organization: fractary
   Is this correct? (Y/n)
   ```

2. **Codex Discovery**: Searches for `codex.*` repositories
   ```
   Found codex repository: codex.fractary.com
   Use this repository? (Y/n)
   ```

3. **Configuration Creation**: Creates config file
   ```
   ✅ Codex plugin initialized successfully!

   Created:
     - Project config: .fractary/plugins/codex/config.json

   Configuration:
     Organization: fractary
     Codex Repository: codex.fractary.com
     Sync Patterns: docs/**, CLAUDE.md, README.md, .claude/**
   ```

### Manual Configuration (Optional)

If auto-detection fails, specify manually:
```bash
/fractary-codex:init --org fractary --codex codex.fractary.com
```

---

## Step 2: Preview Your First Sync (1 minute)

### Run a Dry-Run

```bash
/fractary-codex:sync-project --dry-run
```

### What You'll See

```
🔍 DRY-RUN MODE: No changes will be applied

Detected project: my-project
Would sync: my-project ↔ codex.fractary.com

To Codex (Project → Codex):
  Would add: 12 files
  Would modify: 5 files
  Would delete: 0 files
  Deletion threshold: ✓ PASS (0 < 50)

From Codex (Codex → Project):
  Would add: 8 files
  Would modify: 2 files
  Would delete: 0 files
  Deletion threshold: ✓ PASS (0 < 50)

Recommendation: Safe to proceed

Run without --dry-run to apply changes:
/fractary-codex:sync-project
```

### Review the Changes

The dry-run shows:
- ✅ What files will be added
- ✅ What files will be modified
- ✅ What files will be deleted
- ✅ Whether deletion thresholds are exceeded

---

## Step 3: Perform Your First Sync (2 minutes)

### Run the Real Sync

```bash
/fractary-codex:sync-project
```

### What Happens

1. **Discovery**: Detects current project from git remote
2. **Phase 1 (To Codex)**: Copies docs from project → codex
3. **Phase 2 (From Codex)**: Copies docs from codex → project
4. **Commits**: Creates commits in both repositories
5. **Results**: Shows summary with commit URLs

### Expected Output

```
✅ Project Sync Complete: my-project

Direction: Bidirectional

To Codex:
  Files synced: 17 (12 added, 5 modified)
  Files deleted: 0
  Commit: abc123...
  URL: https://github.com/fractary/codex.fractary.com/commit/abc123

From Codex:
  Files synced: 10 (8 added, 2 modified)
  Files deleted: 0
  Commit: def456...
  URL: https://github.com/fractary/my-project/commit/def456

Next: Review commits and verify changes
```

### Verify the Results

1. **Check Codex Repository**: Visit the commit URL
2. **Check Project Repository**: Visit the commit URL
3. **Review Changes**: Ensure files synced correctly

---

## Common Use Cases

### Sync Specific Direction Only

```bash
# Only pull project docs to codex
/fractary-codex:sync-project --to-codex

# Only push codex docs to project
/fractary-codex:sync-project --from-codex
```

### Sync a Different Project

```bash
/fractary-codex:sync-project other-project
```

### Sync Entire Organization

```bash
# Preview first (recommended)
/fractary-codex:sync-org --dry-run

# Sync all projects
/fractary-codex:sync-org

# Exclude certain repos
/fractary-codex:sync-org --exclude "archive-*" --exclude "test-*"
```

### Override Sync Patterns

```bash
/fractary-codex:sync-project --patterns "docs/**,standards/**"
```

---

## Customization

### Project Configuration

Edit `.fractary/plugins/codex/config.json`:

```json
{
  "version": "1.0",
  "organization": "fractary",
  "codex_repo": "codex.fractary.com",
  "sync_patterns": [
    "docs/**",
    "CLAUDE.md",
    "README.md",
    ".claude/**",
    "standards/**",     // Add custom patterns
    "guides/**"
  ],
  "exclude_patterns": [
    "**/.git/**",
    "**/node_modules/**",
    "docs/private/**"   // Add custom excludes
  ],
  "sync_direction": "bidirectional",
  "handlers": {
    "sync": {
      "active": "github",
      "options": {
        "github": {
          "parallel_repos": 5,           // Increase for faster org sync
          "deletion_threshold": 50,      // Adjust safety threshold
          "deletion_threshold_percent": 20
        }
      }
    }
  }
}
```

### Frontmatter-Based Routing

Add sync rules to markdown files:

```markdown
---
codex_sync_include: ["docs/api/**", "docs/guides/**"]
codex_sync_exclude: ["docs/internal/**"]
---

# Your Document Content
```

---

## Troubleshooting

### Configuration Not Found

**Problem**:
```
⚠️ Configuration required
Run: /fractary-codex:init
```

**Solution**: Run the init command to create configuration

### Authentication Failed

**Problem**:
```
❌ Failed to clone repository: authentication required
```

**Solution**: Configure fractary-repo plugin authentication
```bash
/fractary-repo:init
```

### Deletion Threshold Exceeded

**Problem**:
```
⚠️ Deletion threshold exceeded
Would delete: 75 files (threshold: 50)
```

**Solutions**:
1. Review deletion list carefully (might be legitimate refactor)
2. Adjust threshold in config if intentional
3. Fix sync patterns if unintentional

### Project Not Detected

**Problem**:
```
❌ Cannot detect project from git remote
```

**Solution**: Specify project name explicitly
```bash
/fractary-codex:sync-project my-project
```

---

## Best Practices

### 1. Always Dry-Run First

```bash
/fractary-codex:sync-project --dry-run
```

Review what will change before applying.

### 2. Start Small

Test with one project before syncing entire organization.

### 3. Review Commits

After sync, review the commits in both repositories to ensure correctness.

### 4. Use Exclude Patterns

Don't sync:
- Private documentation
- Generated files
- Temporary files
- Environment files

### 5. Monitor Deletion Counts

If you see high deletions, investigate before proceeding.

### 6. Document Your Patterns

Keep a record of why certain patterns are included/excluded.

### 7. Automate in CI/CD

Set up automatic syncs on documentation changes:
```yaml
# .github/workflows/sync-docs.yml
on:
  push:
    paths:
      - 'docs/**'
jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Sync to codex
        run: /fractary-codex:sync-project --to-codex
```

---

## Next Steps

### Explore Advanced Features

1. **Organization Sync**: Sync all projects at once
2. **Pattern Customization**: Fine-tune what syncs
3. **Frontmatter Routing**: Per-file sync rules
4. **Automation**: Set up CI/CD sync

### Learn More

- **Full Documentation**: See [README.md](README.md)
- **Architecture**: Understand the 3-layer design
- **Configuration**: All available options
- **Troubleshooting**: Common issues and solutions

### Contribute

- **Report Issues**: Found a bug? Report it!
- **Suggest Features**: Ideas for improvements?
- **Share Patterns**: Useful sync pattern combinations?

---

## Quick Reference

### Commands

```bash
# Initialize
/fractary-codex:init

# Sync project (preview)
/fractary-codex:sync-project --dry-run

# Sync project (real)
/fractary-codex:sync-project

# Sync specific direction
/fractary-codex:sync-project --to-codex
/fractary-codex:sync-project --from-codex

# Sync organization (preview)
/fractary-codex:sync-org --dry-run

# Sync organization (real)
/fractary-codex:sync-org
```

### Configuration Location

```
Project: .fractary/plugins/codex/config.json
Schema:  .claude-plugin/config.schema.json
```

### Common Patterns

```json
{
  "sync_patterns": [
    "docs/**",           // All docs recursively
    "CLAUDE.md",         // Specific file
    "README.md",         // Specific file
    ".claude/**",        // Claude tools
    "standards/**",      // Standards docs
    "guides/**"          // Guide docs
  ],
  "exclude_patterns": [
    "**/.git/**",        // Git directories
    "**/node_modules/**",// Dependencies
    "**/.env*",          // Environment files
    "docs/private/**",   // Private docs
    "docs/drafts/**"     // Work in progress
  ]
}
```

---

**Ready to sync!** If you encounter issues, see the [README.md](README.md) for comprehensive documentation.
