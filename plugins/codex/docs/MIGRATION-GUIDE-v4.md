# Codex Plugin Migration Guide v3 → v4

This guide helps you migrate from codex plugin v3.0 (custom bash scripts + JSON config) to v4.0 (@fractary/cli + YAML config).

## Overview

**What's changing**:
- Configuration format: JSON → YAML
- Configuration location: `.fractary/plugins/codex/config.json` → `.fractary/codex.yaml`
- Implementation: Custom bash scripts → @fractary/cli delegation
- Global config: Deprecated (project-level only)

**What's staying**:
- All functionality remains the same
- codex:// URI format unchanged
- Sync patterns and behaviors unchanged
- Handler configuration preserved

**Why migrate**:
- ~95% code reduction (better maintainability)
- Better error messages from SDK
- TypeScript type safety
- Consistent with CLI ecosystem
- YAML is more readable

## Migration Checklist

### Prerequisites

Ensure you have required tools installed:

```bash
# Check CLI installation
fractary --version  # Should show >= 0.3.2

# If not installed
npm install -g @fractary/cli

# Check YAML tools (for manual migration)
yq --version  # mikefarah/yq
jq --version
```

### Step 1: Detect Current Config

```bash
# From your project directory
claude
```

Then in Claude Code:
```
USE SKILL: config-helper with operation="detect"
```

This will show you:
- Current config format (JSON or YAML)
- Current config location (project or global)
- Whether migration is needed

### Step 2: Preview Migration (Dry Run)

```
USE SKILL: config-helper with operation="migrate" and dry_run=true
```

This shows what the new YAML config will look like without making changes.

### Step 3: Execute Migration

```
USE SKILL: config-helper with operation="migrate" and remove_source=true
```

This will:
- Create `.fractary/codex.yaml` (version 4.0)
- Preserve all your settings
- Remove old JSON config (if `remove_source=true`)

### Step 4: Validate Migration

```
# Test CLI can read new config
fractary codex health

# Validate in Claude Code
USE SKILL: config-helper with operation="validate"
```

### Step 5: Test Sync Operations

```bash
# Dry-run sync to verify config works
fractary codex sync project <your-project> --dry-run

# Or in Claude Code
/fractary-codex:sync-project --dry-run
```

### Step 6: Update Scripts (if any)

If you have custom scripts that reference the old config path:

**Before**:
```bash
config_file=".fractary/plugins/codex/config.json"
org=$(jq -r '.organization' "$config_file")
```

**After**:
```bash
config_file=".fractary/codex.yaml"
org=$(yq '.organization' "$config_file")
```

### Step 7: Cleanup

After confirming everything works:

```bash
# Remove old config (if not already removed)
rm -f .fractary/plugins/codex/config.json

# Remove global config (if exists)
rm -f ~/.config/fractary/codex/config.json
```

## Manual Migration (Alternative)

If you prefer to migrate manually:

### 1. Copy Example YAML

```bash
cp ~/.claude/plugins/marketplaces/fractary/plugins/codex/config/codex.example.yaml .fractary/codex.yaml
```

### 2. Update Values

Edit `.fractary/codex.yaml` and update:
- `organization`: Your organization name
- `codex_repo`: Your codex repository
- `sync_patterns`: Patterns you want to sync
- `environments`: Environment-to-branch mappings

### 3. Validate

```bash
fractary codex health
```

## Configuration Comparison

### Old (v3.0 - JSON)
```json
{
  "version": "3.0",
  "organization": "fractary",
  "codex_repo": "codex.fractary.com",
  "sync_patterns": ["docs/**", "CLAUDE.md"],
  "cache": {
    "ttl_days": 7
  }
}
```

### New (v4.0 - YAML)
```yaml
version: "4.0"
organization: fractary
codex_repo: codex.fractary.com
sync_patterns:
  - "docs/**"
  - "CLAUDE.md"
cache:
  ttl_days: 7
```

## Common Issues

### Issue: "yq: command not found"

**Solution**: Install yq (mikefarah/yq)
```bash
# macOS
brew install yq

# Ubuntu/Debian
snap install yq

# Or download from
https://github.com/mikefarah/yq/releases
```

### Issue: "Target config already exists"

**Solution**: Remove or backup existing YAML config
```bash
# Backup first
mv .fractary/codex.yaml .fractary/codex.yaml.backup

# Then retry migration
```

### Issue: "CLI not available"

**Solution**: Install @fractary/cli
```bash
# Global install (recommended)
npm install -g @fractary/cli

# Or use npx (automatic fallback)
npx @fractary/cli codex health
```

### Issue: "Invalid JSON in source config"

**Solution**: Validate and fix JSON first
```bash
# Check JSON validity
jq . .fractary/plugins/codex/config.json

# If invalid, either:
# 1. Fix JSON manually
# 2. Start fresh: /fractary-codex:init
```

### Issue: "Global config still used"

**Solution**: Remove global config explicitly
```bash
rm ~/.config/fractary/codex/config.json
```

The CLI and plugin both prefer project-level config, but removing global ensures no confusion.

## Breaking Changes

### 1. Config Location Changed

**Before**: `.fractary/plugins/codex/config.json`
**After**: `.fractary/codex.yaml`

**Impact**: Any scripts or tools referencing the old path need updates.

### 2. Global Config Deprecated

**Before**: `~/.config/fractary/codex/config.json` (global)
**After**: `.fractary/codex.yaml` (project-level only)

**Impact**: Each project needs its own config. Benefits: version controlled, no global state.

### 3. Version Field Updated

**Before**: `"version": "3.0"`
**After**: `version: "4.0"`

**Impact**: Skills check version to determine CLI compatibility.

## Rollback Plan

If you need to rollback to v3.0:

```bash
# 1. Restore JSON config from backup
cp .fractary/plugins/codex/config.json.backup .fractary/plugins/codex/config.json

# 2. Remove YAML config
rm .fractary/codex.yaml

# 3. Checkout v3.0 skills (if needed)
git checkout v3.0.1 -- plugins/codex/skills/
```

However, v4.0 is backwards compatible - the SDK can read both JSON and YAML configs.

## FAQ

### Q: Can I use both JSON and YAML?

**A**: Yes, but YAML takes precedence. The detection order is:
1. `.fractary/codex.yaml` (preferred)
2. `.fractary/plugins/codex/config.json` (deprecated)
3. `~/.config/fractary/codex/config.json` (legacy)

Recommendation: Migrate to YAML to avoid confusion.

### Q: Do I need to update all projects at once?

**A**: No. Each project can migrate independently. The SDK supports both formats.

### Q: What if I don't have the @fractary/cli installed?

**A**: Skills automatically fall back to npx (~200ms overhead, cached). But global install is faster (<100ms overhead).

### Q: Will my sync patterns change?

**A**: No. Patterns are preserved exactly during migration. Same glob patterns, same behavior.

### Q: What about my cache?

**A**: Cache is unaffected. It's stored separately in `.fractary/plugins/codex/cache/` and works with both config formats.

## Support

If you encounter issues during migration:

1. Check this guide's Common Issues section
2. Validate prerequisites (jq, yq, @fractary/cli)
3. Try dry-run first to preview changes
4. Open an issue: https://github.com/fractary/claude-plugins/issues

## Next Steps

After migration:

1. ✅ Restart Claude Code (to reload MCP server with new config)
2. ✅ Test sync: `/fractary-codex:sync-project --dry-run`
3. ✅ Test fetch: Use codex:// URIs in your work
4. ✅ Review new YAML config for customization opportunities
5. ✅ Commit new config to git: `git add .fractary/codex.yaml`

---

**Migration Timeline**:
- **v3.0**: Deprecated (JSON config, bash scripts)
- **v4.0**: Current (YAML config, CLI delegation)
- **v3.0 support**: Maintained for 6 months (until 2025-06-15)
- **v3.0 removal**: After 2025-06-15
