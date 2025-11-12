# Codex Plugin Configuration Migration Guide

**Last Updated**: 2025-11-12

This document clarifies the configuration formats used by the codex plugin across different versions and addresses common migration questions.

---

## Configuration File Standards

The codex plugin follows the Fractary plugin configuration standard:

**Standard Location**:
```
.fractary/plugins/codex/config.json
```

**Global Configuration** (optional):
```
~/.config/fractary/codex/config.json
```

---

## Version History

### v2.0+ (Current - Since 2025-11-04)

**Format**: JSON
**Locations**:
- Global: `~/.config/fractary/codex/config.json`
- Project: `.fractary/plugins/codex/config.json`

**Configuration Method**: Run `/fractary-codex:init`

**Features**:
- Organization-agnostic configuration
- Auto-detection of organization and codex repository
- JSON schema validation
- Handler-based sync mechanisms

### v1.x (Legacy - Before 2025-11-04)

**Format**: `.env` files
**Locations**: Root directory of projects

**Configuration Method**: Manual `.env` file creation with hardcoded values

**Migration**: v1.x is completely deprecated. Run `/fractary-codex:init` to create v2.0+ configuration.

---

## Non-Standard Configurations

### YAML Configuration Files (`codex-sync.yaml`)

**Status**: ❌ **Never officially supported**

If you find a file named `docs/codex-sync.yaml` or similar YAML configuration files in your project:

1. **These were NOT created by the codex plugin** - The plugin has never used YAML for configuration
2. **Possible sources**:
   - Manually created for experimentation
   - Created by a different tool or workflow
   - Legacy from a non-standard setup
3. **Safe to remove** - The codex plugin does not read or use these files

**Note**: YAML is used for *frontmatter* in markdown files (to control per-file sync behavior), but not for plugin configuration.

---

## Migration Paths

### From v1.x (.env files)

1. **Remove old configuration**:
   ```bash
   # Backup for reference
   mv .env .env.backup
   ```

2. **Initialize new configuration**:
   ```bash
   /fractary-codex:init
   ```

3. **Verify configuration**:
   ```bash
   cat .fractary/plugins/codex/config.json
   ```

4. **Test sync**:
   ```bash
   /fractary-codex:sync-project --dry-run
   ```

### From YAML files (non-standard)

If you have YAML configuration files:

1. **Extract relevant settings** (if any are codex-related)
2. **Run init to create proper configuration**:
   ```bash
   /fractary-codex:init
   ```
3. **Manually transfer any custom patterns** to `.fractary/plugins/codex/config.json`
4. **Remove YAML configuration files** (they are not used)

---

## Configuration Schema

The codex plugin uses JSON configuration validated against a schema:

**Schema Location**: `.claude-plugin/config.schema.json`

**Example Configuration**:

```json
{
  "version": "1.0",
  "codex_repo": "codex.fractary.com",
  "sync_patterns": [
    "docs/**",
    "CLAUDE.md",
    "README.md"
  ],
  "exclude_patterns": [
    "docs/private/**"
  ],
  "auto_sync": false,
  "sync_direction": "bidirectional"
}
```

**View full examples**:
- Global: `plugins/codex/config/codex.example.json`
- Project: `plugins/codex/config/codex.project.example.json`

---

## Per-File Control with Frontmatter

The codex plugin supports YAML frontmatter in markdown files for per-file sync control:

```yaml
---
codex_sync_include: ["docs/api/**", "docs/guides/**"]
codex_sync_exclude: ["docs/internal/**"]
---
```

**Important**: This is frontmatter for *content files*, not plugin configuration.

---

## Verification

To verify your configuration is correct:

1. **Check file exists**:
   ```bash
   ls -la .fractary/plugins/codex/config.json
   ```

2. **Validate JSON**:
   ```bash
   cat .fractary/plugins/codex/config.json | jq empty
   ```

3. **Test with dry-run**:
   ```bash
   /fractary-codex:sync-project --dry-run
   ```

---

## Troubleshooting

### "Configuration not found" error

**Cause**: No configuration file exists
**Solution**: Run `/fractary-codex:init`

### "Invalid JSON" error

**Cause**: Malformed JSON in config file
**Solution**: Validate with `jq` and fix syntax errors

### Old YAML files causing confusion

**Cause**: Legacy YAML files in project
**Solution**: Remove them - they are not used by the plugin

### Wrong configuration location

**Cause**: Config in wrong directory (e.g., `.fractary/plugins/codex/config/codex.json`)
**Solution**: Move to correct location `.fractary/plugins/codex/config.json`

---

## Summary

✅ **Current Standard**: JSON at `.fractary/plugins/codex/config.json`
✅ **Global Config**: JSON at `~/.config/fractary/codex/config.json`
✅ **Frontmatter**: YAML in content files (not configuration)
❌ **YAML Config**: Never officially used - safe to remove
❌ **.env Files**: Deprecated in v1.x - migrate to JSON

**Always use** `/fractary-codex:init` to create proper configuration.
