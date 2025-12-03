---
model: claude-haiku-4-5
---

# /fractary-codex:migrate

Migrate configuration from SPEC-00012 (v2.0 push-based sync) to SPEC-00030 (v3.0 pull-based retrieval).

## Usage

```bash
# Interactive migration with prompts
/fractary-codex:migrate

# Dry-run mode (preview changes without applying)
/fractary-codex:migrate --dry-run

# Automatic mode (no prompts, use defaults)
/fractary-codex:migrate --yes

# Force migration even if already migrated
/fractary-codex:migrate --force
```

## What It Does

1. **Detects** existing v2.0 configuration
2. **Converts** to v3.0 format with `sources` array
3. **Backs up** old configuration
4. **Validates** new configuration
5. **Tests** retrieval with new config
6. **Reports** migration summary

## Options

- `--dry-run`: Preview changes without applying
- `--yes`: Skip confirmation prompts
- `--force`: Migrate even if config appears already migrated
- `--backup-path <path>`: Custom backup location (default: `.backup`)

## Migration Process

The script converts your configuration from:

**v2.0 format**:
```json
{
  "organization": "fractary",
  "codex_repo": "codex.fractary.com",
  "sync_patterns": {
    "include": ["*.md"],
    "exclude": ["temp/**"]
  }
}
```

**To v3.0 format**:
```json
{
  "organization": "fractary",
  "codex_repo": "codex.fractary.com",
  "sources": [
    {
      "name": "fractary-codex",
      "type": "codex",
      "handler": "github",
      "permissions": {"enabled": true},
      "cache": {"ttl_days": 7}
    }
  ]
}
```

## Safety

- Creates backup before modification
- Validates new config before saving
- Dry-run mode available
- Rollback instructions provided

## Examples

```bash
# Preview migration
/fractary-codex:migrate --dry-run

# Execute migration with prompts
/fractary-codex:migrate

# Automated migration for CI/CD
/fractary-codex:migrate --yes --backup-path /backups
```

## Related

- [Migration Guide](../docs/MIGRATION-PHASE4.md) - Full migration documentation
- [README](../README.md) - v3.0 documentation
