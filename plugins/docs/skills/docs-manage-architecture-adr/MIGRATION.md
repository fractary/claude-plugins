# ADR Skill Migration Guide

This guide helps you migrate from `doc-manage-adr` to `docs-manage-architecture-adr`.

## Overview of Changes

The ADR skill has been renamed and enhanced as part of the docs plugin expansion (Issue #106):

### 1. Skill Naming Convention

**Old**: `doc-manage-adr`
**New**: `docs-manage-architecture-adr`

All documentation type skills now follow the `docs-manage-{type}` naming pattern for consistency.

### 2. Number Format

**Old**: 3-digit zero-padded (ADR-001, ADR-002, ..., ADR-999)
**New**: 5-digit zero-padded (ADR-00001, ADR-00002, ..., ADR-99999)

**Why**: Supports larger projects with more than 999 ADRs while maintaining sortability.

### 3. Storage Path

**Old**: `docs/architecture/adrs` (lowercase)
**New**: `docs/architecture/ADR` (uppercase)

**Why**: Distinguishes ADRs from other architecture documents, follows uppercase acronym convention.

## Do You Need to Migrate?

### ✅ You Should Migrate If:

- You have existing ADRs in the old 3-digit format
- You want to use the new skill features
- You're starting a new project and want the latest conventions

### ❌ You Can Skip Migration If:

- You're starting fresh with no existing ADRs
- You're happy with the 3-digit format and lowercase path (old skill still works)

## Migration Options

### Option 1: Automatic Migration (Recommended)

Use the provided migration script to automatically convert all ADRs:

```bash
# Run from your project root
bash plugins/docs/skills/docs-manage-architecture-adr/scripts/migrate-adrs.sh

# With dry-run to preview changes
bash plugins/docs/skills/docs-manage-architecture-adr/scripts/migrate-adrs.sh --dry-run
```

**What the script does:**
1. Scans `docs/architecture/adrs` for existing ADRs
2. Renames files from ADR-NNN-... to ADR-000NN-...
3. Creates new directory `docs/architecture/ADR`
4. Moves renamed files to new directory
5. Updates all cross-references in markdown files
6. Preserves git history (uses `git mv`)

### Option 2: Manual Migration

If you prefer manual control:

#### Step 1: Create New Directory

```bash
mkdir -p docs/architecture/ADR
```

#### Step 2: Rename Files

For each ADR file, rename from 3-digit to 5-digit format:

```bash
# Example: ADR-001-api-choice.md → ADR-00001-api-choice.md
for file in docs/architecture/adrs/ADR-*.md; do
  filename=$(basename "$file")
  if [[ "$filename" =~ ADR-([0-9]{3})-(.+) ]]; then
    old_num="${BASH_REMATCH[1]}"
    rest="${BASH_REMATCH[2]}"
    new_num=$(printf "%05d" $((10#$old_num)))
    new_filename="ADR-${new_num}-${rest}"
    git mv "$file" "docs/architecture/ADR/$new_filename"
  fi
done
```

#### Step 3: Update Cross-References

Search your project for references to old ADR paths and update them:

```bash
# Find files referencing old ADR path
grep -r "docs/architecture/adrs" docs/ --include="*.md"

# Find references to old ADR numbering
grep -r "ADR-[0-9]\{3\}-" docs/ --include="*.md"
```

Manually update each reference:
- `docs/architecture/adrs/ADR-001-...` → `docs/architecture/ADR/ADR-00001-...`
- `ADR-001` → `ADR-00001`

#### Step 4: Update Configuration

Update your `.fractary/plugins/docs/config.json`:

```json
{
  "doc_types": {
    "adr": {
      "enabled": true,
      "path": "docs/architecture/ADR",
      "auto_number": true,
      "number_format": "%05d"
    }
  }
}
```

#### Step 5: Update Project Documentation

Update any project documentation that references ADR conventions:
- README.md
- CONTRIBUTING.md
- Development guides

### Option 3: Fresh Start (No Migration)

If you have few ADRs or want a clean slate:

1. **Create new directory**: `docs/architecture/ADR`
2. **Archive old ADRs**: Move `docs/architecture/adrs` to `docs/archive/adrs-old`
3. **Start fresh**: Create new ADRs with 5-digit format
4. **Add reference**: Link to archived ADRs from new README.md

## Migration Script Reference

### Usage

```bash
migrate-adrs.sh [OPTIONS]

Options:
  --dry-run          Show what would be changed without making changes
  --source PATH      Source directory (default: docs/architecture/adrs)
  --dest PATH        Destination directory (default: docs/architecture/ADR)
  --keep-old         Keep old directory after migration
  --no-git           Don't use git mv (use regular mv instead)
  --help             Show this help message
```

### Examples

```bash
# Preview migration
./migrate-adrs.sh --dry-run

# Migrate with default settings
./migrate-adrs.sh

# Migrate and keep old directory
./migrate-adrs.sh --keep-old

# Migrate custom paths
./migrate-adrs.sh --source docs/decisions --dest docs/ADR

# Migrate without git (if not in git repo)
./migrate-adrs.sh --no-git
```

### What Gets Updated

The script updates:
- ✅ ADR filenames (3-digit → 5-digit)
- ✅ File locations (adrs/ → ADR/)
- ✅ Cross-references in markdown files
- ✅ Frontmatter links in `related` and `supersedes` fields
- ✅ README.md index
- ✅ Git history preservation

The script does NOT update:
- ❌ External documentation (wikis, Confluence, etc.)
- ❌ Code comments referencing ADRs
- ❌ Commit messages (historical)
- ❌ Issue/PR descriptions

## Verification Checklist

After migration, verify:

- [ ] All ADR files are in `docs/architecture/ADR/`
- [ ] All filenames use 5-digit format (ADR-00001-...)
- [ ] No files remain in old `docs/architecture/adrs/`
- [ ] All cross-references updated correctly
- [ ] README.md index reflects new structure
- [ ] Configuration file updated
- [ ] Git history preserved (use `git log --follow`)
- [ ] All markdown links work (no 404s)
- [ ] Builds/tests still pass
- [ ] CI/CD pipelines unaffected

## Troubleshooting

### Problem: Script fails with "not a git repository"

**Solution**: Use `--no-git` flag to use standard `mv` instead of `git mv`.

### Problem: Cross-references not updated

**Solution**: The script only updates references in `.md` files. Check:
- Code comments (`.ts`, `.js`, `.py`, etc.)
- Configuration files
- External documentation

### Problem: Git history lost

**Solution**: Ensure you used `git mv` for renaming. Check history:
```bash
git log --follow docs/architecture/ADR/ADR-00001-api-choice.md
```

### Problem: Old ADRs still appear in commands

**Solution**: Clear any cached indexes:
```bash
rm -rf .fractary/cache/docs/
```

### Problem: Links broken in documentation

**Solution**: Search for old paths and update:
```bash
# Find all broken ADR references
grep -r "ADR-[0-9]\{3\}-" . --include="*.md" | grep -v "docs/architecture/ADR"
```

## Rollback Procedure

If you need to rollback the migration:

### If You Used Git

```bash
# Revert the migration commit
git log --oneline | grep "Migrate ADR"  # Find commit hash
git revert <commit-hash>
```

### If You Kept Backup

```bash
# Restore from backup
rm -rf docs/architecture/ADR
mv docs/architecture/adrs.backup docs/architecture/adrs
```

### Manual Rollback

```bash
# Rename back to 3-digit
for file in docs/architecture/ADR/ADR-*.md; do
  filename=$(basename "$file")
  if [[ "$filename" =~ ADR-([0-9]{5})-(.+) ]]; then
    old_num="${BASH_REMATCH[1]}"
    rest="${BASH_REMATCH[2]}"
    new_num=$(printf "%03d" $((10#$old_num)))
    new_filename="ADR-${new_num}-${rest}"
    git mv "$file" "docs/architecture/adrs/$new_filename"
  fi
done
```

## FAQ

### Q: Will old commands still work?

**A**: Yes, during the deprecation period (2 months). Commands are backward compatible but will show warnings to migrate.

### Q: Do I need to migrate immediately?

**A**: No. The old skill name works during the deprecation period. Migrate when convenient.

### Q: What if I have 1000+ ADRs?

**A**: The 5-digit format supports up to 99,999 ADRs. If you need more, contact the maintainers to discuss custom formatting.

### Q: Can I use custom numbering?

**A**: Yes, configure `number_format` in the ADR schema or project config:
```json
{"number_format": "%06d"}  // 6-digit
```

### Q: Will this break my CI/CD?

**A**: Check your CI/CD for hardcoded paths like `docs/architecture/adrs`. Update to `docs/architecture/ADR`.

### Q: Can I keep the old directory structure?

**A**: Yes, you can override the path in your project config:
```json
{
  "doc_types": {
    "adr": {
      "path": "docs/architecture/adrs"  // Keep old path
    }
  }
}
```

But you'll still need to rename files for 5-digit format.

## Support

If you encounter issues during migration:

1. **Check the troubleshooting section** above
2. **Run with --dry-run** to preview changes
3. **Create a backup** before migrating
4. **File an issue** on GitHub if problems persist

## Timeline

- **2025-11-13**: New skill released, old skill deprecated
- **2026-01-13**: Old skill directory removed (2 months)
- **After removal**: Only `docs-manage-architecture-adr` works

---

**Questions?** Open an issue at https://github.com/fractary/claude-plugins/issues

**Related**: See [Issue #106](https://github.com/fractary/claude-plugins/issues/106) for full context on this change.
