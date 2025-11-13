# ⚠️ DEPRECATED: doc-manage-adr

**This skill has been renamed and relocated.**

## New Skill Name

**`docs-manage-architecture-adr`**

This skill has been renamed to follow the consistent naming convention for all documentation type skills in the docs plugin.

## What Changed

| Aspect | Old | New |
|--------|-----|-----|
| **Skill Name** | `doc-manage-adr` | `docs-manage-architecture-adr` |
| **Directory** | `plugins/docs/skills/doc-manage-adr/` | `plugins/docs/skills/docs-manage-architecture-adr/` |
| **Default Path** | `docs/architecture/adrs` | `docs/architecture/ADR` (uppercase) |
| **Number Format** | 3-digit (ADR-001-...) | 5-digit (ADR-00001-...) |

## Migration Required

If you have existing ADR documents using the old format, please see the migration guide:

**[MIGRATION.md](../docs-manage-architecture-adr/MIGRATION.md)**

## Backward Compatibility

This deprecated directory is maintained for backward compatibility only. All new development and updates should use the new skill name.

### For Plugin Users

If you are invoking this skill directly, update your code:

**Old:**
```
Use the doc-manage-adr skill to generate ADR...
```

**New:**
```
Use the docs-manage-architecture-adr skill to generate ADR...
```

### For Command Users

Commands have been updated automatically. No changes needed for command usage.

## Timeline

- **Now**: Both names work (deprecated version shows warning)
- **2 months**: This directory will be removed
- **After removal**: Only `docs-manage-architecture-adr` will work

## Need Help?

See the full migration guide: [MIGRATION.md](../docs-manage-architecture-adr/MIGRATION.md)

---

**Deprecated**: 2025-11-13
**Removal Date**: 2026-01-13
