# SPEC-00029-18: Migration Strategy

**Issue**: #29
**Phase**: 6 (Migration & Documentation)
**Dependencies**: All previous specs (0029-01 through 0029-17)
**Status**: Draft
**Created**: 2025-01-15

## Overview

Strategy and tooling for migrating existing plugins (faber, faber-cloud, work, repo, codex) to use the new fractary-docs, fractary-spec, fractary-logs, and fractary-file plugins.

## Migration Scope

### Plugins to Migrate

1. **faber**: Use fractary-spec for specifications
2. **faber-cloud**: Use all four new plugins
3. **work**: No changes (no documentation generation)
4. **repo**: No changes (no documentation generation)
5. **codex**: Benefits from standardized front matter (no changes needed)

## Migration Phases

### Phase 1: faber-cloud (Pilot)

**Why first**: Most complex, already generates documentation, best test case

**Current State**:
- Custom templates in `skills/infra-architect/templates/`
- Design docs in `.fractary/plugins/faber-cloud/designs/`
- Deployment docs in `.fractary/plugins/faber-cloud/deployments/`
- No cloud archival (files stay in repo)

**Target State**:
- Use fractary-docs templates for design docs
- Use fractary-spec for infrastructure specifications
- Use fractary-logs for session capture and archival
- Use fractary-file for log/spec archival

**Migration Steps**:

1. **Update plugin.json dependencies**:
```json
{
  "name": "fractary-faber-cloud",
  "requires": [
    "fractary-work",
    "fractary-repo",
    "fractary-file",
    "fractary-docs",
    "fractary-spec",
    "fractary-logs"
  ]
}
```

2. **Migrate templates to fractary-docs**:
   - Copy `design-doc.md.template` → `fractary-docs/skills/doc-generator/templates/infrastructure-design.md.template`
   - Update infra-architect to use fractary-docs
   - Keep custom templates for now, migrate gradually

3. **Add spec generation to infra-architect**:
```markdown
Use @agent-fractary-spec:spec-manager to generate infrastructure spec:
{
  "operation": "generate",
  "issue_number": "{{issue_number}}",
  "template": "infrastructure"
}
```

4. **Add log archival to infra-deployer**:
```markdown
Use @agent-fractary-logs:log-manager to archive deployment logs:
{
  "operation": "archive",
  "issue_number": "{{issue_number}}"
}
```

5. **Update configuration**:
```json
{
  "documentation": {
    "use_fractary_docs": true,
    "template_dir": "custom"
  },
  "specs": {
    "generate_on_architect": true,
    "archive_on_release": true
  },
  "logs": {
    "capture_sessions": true,
    "archive_on_release": true,
    "retention_days": 30
  }
}
```

### Phase 2: faber (Core)

**Current State**:
- Architect phase creates basic specs in project root
- No log management
- No archival

**Target State**:
- Use fractary-spec for all specifications
- Session capture during workflows
- Archive specs and logs on completion

**Migration Steps**:

1. **Update architect skill**:
   - Replace inline spec generation with fractary-spec
   - Use templates from fractary-spec

2. **Add session capture**:
   - Frame phase starts capture
   - Release phase archives

3. **Update configuration**:
```toml
[plugins]
spec = "fractary-spec"
logs = "fractary-logs"
docs = "fractary-docs"

[workflow.architect]
generate_spec = true

[workflow.release]
archive_specs = true
archive_logs = true
```

### Phase 3: Existing Projects

**For projects already using faber/faber-cloud**:

**Migration steps**:

1. **Initialize new plugins**:
```bash
/fractary-file:init --handler local
/fractary-docs:init
/fractary-spec:init
/fractary-logs:init
```

2. **Migrate existing specs** (optional):
```bash
# Move existing specs to /specs
mkdir -p /specs
mv SPEC-*.md /specs/

# Add front matter to existing specs
/fractary-spec:migrate-existing /specs/*.md
```

3. **Update FABER config**:
```bash
# Update .faber.config.toml to include new plugins
# See examples in migration guide
```

4. **Test with new issue**:
```bash
# Run FABER workflow with new plugins
/faber:run <new_issue> --autonomy guarded
```

## Migration Tooling

### Tool 1: migrate-docs.sh

Migrate existing documentation to fractary-docs format:

```bash
#!/bin/bash
# migrate-docs.sh

DOC_FILE="$1"

# Add front matter if missing
if ! grep -q "^---$" "$DOC_FILE"; then
    TITLE=$(head -1 "$DOC_FILE" | sed 's/^# //')
    DATE=$(date +%Y-%m-%d)

    cat > "${DOC_FILE}.new" <<EOF
---
title: "$TITLE"
type: design
created: "$DATE"
updated: "$DATE"
codex_sync: true
---

EOF
    cat "$DOC_FILE" >> "${DOC_FILE}.new"
    mv "${DOC_FILE}.new" "$DOC_FILE"

    echo "✓ Added front matter to $DOC_FILE"
fi
```

### Tool 2: migrate-specs.sh

Migrate existing specs to fractary-spec format:

```bash
#!/bin/bash
# migrate-specs.sh

SPEC_DIR="${1:-.}"
TARGET_DIR="/specs"

mkdir -p "$TARGET_DIR"

# Find spec files
SPECS=$(find "$SPEC_DIR" -name "SPEC-*.md" -o -name "spec-*.md")

for SPEC in $SPECS; do
    BASENAME=$(basename "$SPEC")

    # Extract issue number if present
    ISSUE=$(echo "$BASENAME" | grep -oP '\d+' | head -1)

    # Add fractary-spec front matter
    if ! grep -q "^---$" "$SPEC"; then
        cat > "${TARGET_DIR}/${BASENAME}.new" <<EOF
---
spec_id: $(basename "$BASENAME" .md)
issue_number: ${ISSUE:-unknown}
status: archived
created: $(stat -c %y "$SPEC" | cut -d' ' -f1)
migrated: true
---

EOF
        cat "$SPEC" >> "${TARGET_DIR}/${BASENAME}.new"
        mv "${TARGET_DIR}/${BASENAME}.new" "${TARGET_DIR}/${BASENAME}"

        echo "✓ Migrated $BASENAME"
    else
        cp "$SPEC" "$TARGET_DIR/"
        echo "✓ Copied $BASENAME (already has front matter)"
    fi
done

echo "Migration complete! Specs in $TARGET_DIR"
```

### Tool 3: add-frontmatter-bulk.sh

Bulk add codex front matter to documentation:

```bash
#!/bin/bash
# add-frontmatter-bulk.sh

DOCS_DIR="${1:-./docs}"

find "$DOCS_DIR" -name "*.md" | while read DOC; do
    if ! grep -q "^codex_sync:" "$DOC"; then
        # Add codex_sync to existing front matter or create new
        if grep -q "^---$" "$DOC"; then
            # Has front matter, add field
            sed -i '/^---$/a codex_sync: true' "$DOC"
        else
            # No front matter, add minimal
            echo -e "---\ncodex_sync: true\n---\n\n$(cat "$DOC")" > "${DOC}.tmp"
            mv "${DOC}.tmp" "$DOC"
        fi
        echo "✓ Added codex_sync to $DOC"
    fi
done
```

### Tool 4: validate-migration.sh

Validate migration completeness:

```bash
#!/bin/bash
# validate-migration.sh

echo "=== Migration Validation ==="

# Check plugin dependencies
echo "Checking plugin dependencies..."
PLUGINS=$(jq -r '.requires[]' .claude-plugin/plugin.json 2>/dev/null)
for PLUGIN in fractary-file fractary-docs fractary-spec fractary-logs; do
    if echo "$PLUGINS" | grep -q "$PLUGIN"; then
        echo "✓ $PLUGIN dependency present"
    else
        echo "✗ Missing dependency: $PLUGIN"
    fi
done

# Check configuration
echo -e "\nChecking configuration..."
if [[ -f .faber.config.toml ]]; then
    if grep -q "\[plugins\]" .faber.config.toml; then
        echo "✓ Plugin configuration present"
    else
        echo "⚠ Plugin configuration missing"
    fi
fi

# Check directory structure
echo -e "\nChecking directory structure..."
for DIR in /docs /specs /logs; do
    if [[ -d "$DIR" ]]; then
        echo "✓ $DIR exists"
    else
        echo "⚠ $DIR missing (will be created on first use)"
    fi
done

# Check front matter
echo -e "\nChecking documentation front matter..."
DOCS_NO_FM=$(find /docs -name "*.md" -exec grep -L "^codex_sync:" {} \; 2>/dev/null | wc -l)
if (( DOCS_NO_FM > 0 )); then
    echo "⚠ $DOCS_NO_FM docs missing codex_sync front matter"
else
    echo "✓ All docs have codex_sync front matter"
fi

echo -e "\n=== Validation Complete ==="
```

## Migration Guides

### Guide 1: For Plugin Developers

**docs/guides/migrating-plugin-to-new-utils.md**:

```markdown
# Migrating Your Plugin to Use New Utility Plugins

This guide helps plugin developers migrate to fractary-docs, fractary-spec, fractary-logs, and fractary-file.

## Step 1: Update Dependencies

Add to `.claude-plugin/plugin.json`:
```json
{
  "requires": [
    "fractary-file",
    "fractary-docs",
    "fractary-spec",
    "fractary-logs"
  ]
}
```

## Step 2: Replace Custom Documentation

If your plugin generates documentation:
- Replace custom templates with fractary-docs templates
- Update skills to use @agent-fractary-docs:docs-manager
- Move custom templates to fractary-docs if needed

## Step 3: Add Spec Generation

If your plugin creates specifications:
- Use fractary-spec in architect/planning phases
- Remove custom spec generation logic
- Update to use fractary-spec templates

## Step 4: Add Log Management

For operational logs:
- Use fractary-logs for session capture
- Archive logs on completion
- Remove custom log management

## Step 5: Test Migration

1. Run existing workflows
2. Verify documentation generated correctly
3. Check specs created in /specs
4. Verify logs captured and archived
5. Confirm cloud storage working

## Rollback Plan

If migration causes issues:
1. Revert plugin.json changes
2. Keep custom implementation alongside new
3. Gradually migrate over multiple releases
```

### Guide 2: For End Users

**docs/guides/migrating-to-new-plugins.md**:

```markdown
# Migrating Your Project to New Plugins

Quick guide for projects using FABER to adopt new plugins.

## Quick Start

1. Initialize new plugins:
   ```bash
   /fractary-file:init --handler local
   /fractary-docs:init
   /fractary-spec:init
   /fractary-logs:init
   ```

2. Update FABER config:
   ```toml
   [plugins]
   file = "fractary-file"
   docs = "fractary-docs"
   spec = "fractary-spec"
   logs = "fractary-logs"
   ```

3. Test with new workflow:
   ```bash
   /faber:run <issue> --autonomy guarded
   ```

## Migrating Existing Docs/Specs (Optional)

Run migration tools:
```bash
./tools/migrate-docs.sh docs/
./tools/migrate-specs.sh .
./tools/add-frontmatter-bulk.sh docs/
```

## What Changes

- Specs now in `/specs` (archived to cloud when done)
- Docs in `/docs` (stay in git, synced with codex)
- Logs in `/logs` (archived to cloud after 30 days)
- Archive command: `/faber:archive <issue>`

## Benefits

- Clean local context (old specs/logs archived)
- Searchable history (search archived content)
- Better codex integration (standardized front matter)
- Consistent documentation across projects
```

## Backward Compatibility

### During Transition

- Keep old documentation generation working
- Run both old and new systems in parallel
- Gradual cutover over 2-3 releases

### Configuration

```toml
[migration]
mode = "parallel"  # parallel|new_only|old_only
prefer_new_plugins = true
fallback_to_old = true
```

## Success Criteria

- [ ] Migration tools created and tested
- [ ] faber-cloud migrated successfully
- [ ] faber core migrated successfully
- [ ] Migration guides written
- [ ] Validation tools working
- [ ] Backward compatibility maintained
- [ ] Example projects migrated

## Timeline

**Estimated**: 1 week

## Next Steps

- **SPEC-00029-19**: Comprehensive documentation plan
