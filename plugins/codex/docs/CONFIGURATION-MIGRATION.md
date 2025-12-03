# Codex Plugin Configuration Migration Guide

**Last Updated**: 2025-11-12

This document clarifies the configuration formats used by the codex plugin across different versions and addresses common migration questions.

---

## Configuration File Standards

The codex plugin follows the Fractary plugin configuration standard:

**Configuration Location**:
```
.fractary/plugins/codex/config.json
```

Note: Global configuration at `~/.config/fractary/codex/config.json` is **deprecated** and no longer used. All configuration should be project-level.

---

## Version History

### v2.1+ (Current - Since 2025-12-03)

**Format**: JSON
**Location**: `.fractary/plugins/codex/config.json` (project-level only)

**Configuration Method**: Run `/fractary-codex:init`

**Features**:
- Project-level configuration only (global config deprecated)
- Organization-agnostic configuration
- Auto-detection of organization and codex repository
- JSON schema validation
- Handler-based sync mechanisms

### v2.0 (2025-11-04 to 2025-12-03)

**Format**: JSON
**Locations**:
- Global: `~/.config/fractary/codex/config.json` (deprecated)
- Project: `.fractary/plugins/codex/config.json`

**Migration**: If you have a global config, run `/fractary-codex:init` to create project-level config. The global config is no longer used.

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

**Cause**: Config in wrong directory (e.g., `.fractary/plugins/codex/config/codex.json`, `~/.codex/config.json`, `docs/codex-sync.yaml`)
**Solution**:
1. Check for config in non-standard locations
2. If found, extract any useful settings
3. Run `/fractary-codex:init` to create config in correct location
4. Remove old configuration files

---

## Summary

✅ **Current Standard**: JSON at `.fractary/plugins/codex/config.json`
✅ **Frontmatter**: YAML in content files (not configuration)
❌ **Global Config**: `~/.config/fractary/codex/config.json` is deprecated - use project config
❌ **YAML Config**: Never officially used - safe to remove
❌ **.env Files**: Deprecated in v1.x - migrate to JSON

**Always use** `/fractary-codex:init` to create proper configuration.
