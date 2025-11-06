#!/bin/bash
# validate-migration.sh
#
# Validate migration completeness for fractary plugins
# Usage: ./tools/validate-migration.sh

set -euo pipefail

echo "=== Migration Validation ==="
echo

# Check plugin dependencies
echo "Checking plugin dependencies..."
if [[ -f .claude-plugin/plugin.json ]]; then
    PLUGINS=$(jq -r '.requires[]' .claude-plugin/plugin.json 2>/dev/null || echo "")
    for PLUGIN in fractary-file fractary-docs fractary-spec fractary-logs; do
        if echo "$PLUGINS" | grep -q "$PLUGIN" 2>/dev/null; then
            echo "  ✓ $PLUGIN dependency present"
        else
            echo "  ✗ Missing dependency: $PLUGIN"
        fi
    done
else
    echo "  ⚠ No plugin.json found (not a plugin directory)"
fi

# Check configuration
echo
echo "Checking configuration..."
if [[ -f .faber.config.toml ]]; then
    if grep -q "\[plugins\]" .faber.config.toml 2>/dev/null; then
        echo "  ✓ Plugin configuration present in .faber.config.toml"
    else
        echo "  ⚠ Plugin configuration missing from .faber.config.toml"
    fi
else
    echo "  ⚠ .faber.config.toml not found (not a FABER project)"
fi

# Check directory structure
echo
echo "Checking directory structure..."
for DIR in /docs /specs /logs; do
    if [[ -d "$DIR" ]]; then
        FILE_COUNT=$(find "$DIR" -type f -name "*.md" 2>/dev/null | wc -l)
        echo "  ✓ $DIR exists ($FILE_COUNT markdown files)"
    else
        echo "  ⚠ $DIR missing (will be created on first use)"
    fi
done

# Check .fractary configuration directories
echo
echo "Checking .fractary configuration..."
for PLUGIN_DIR in .fractary/plugins/{file,docs,spec,logs}; do
    if [[ -d "$PLUGIN_DIR" ]]; then
        if [[ -f "$PLUGIN_DIR/config.json" ]]; then
            echo "  ✓ $PLUGIN_DIR configured"
        else
            echo "  ⚠ $PLUGIN_DIR exists but no config.json"
        fi
    else
        echo "  ⊘ $PLUGIN_DIR not initialized"
    fi
done

# Check front matter in docs
echo
echo "Checking documentation front matter..."
if [[ -d /docs ]]; then
    TOTAL_DOCS=$(find /docs -type f -name "*.md" 2>/dev/null | wc -l)
    DOCS_WITH_FM=$(find /docs -type f -name "*.md" -exec grep -l "^codex_sync:" {} \; 2>/dev/null | wc -l)
    DOCS_NO_FM=$((TOTAL_DOCS - DOCS_WITH_FM))

    if (( TOTAL_DOCS > 0 )); then
        echo "  Total docs: $TOTAL_DOCS"
        echo "  With codex_sync: $DOCS_WITH_FM"
        if (( DOCS_NO_FM > 0 )); then
            echo "  ⚠ $DOCS_NO_FM docs missing codex_sync front matter"
            echo "    Run: ./tools/add-frontmatter-bulk.sh /docs"
        else
            echo "  ✓ All docs have codex_sync front matter"
        fi
    else
        echo "  ⊘ No documentation files found"
    fi
else
    echo "  ⊘ /docs directory not found"
fi

# Check specs
echo
echo "Checking specifications..."
if [[ -d /specs ]]; then
    TOTAL_SPECS=$(find /specs -type f -name "*.md" 2>/dev/null | wc -l)
    SPECS_WITH_FM=$(find /specs -type f -name "*.md" -exec grep -l "^spec_id:" {} \; 2>/dev/null | wc -l)

    if (( TOTAL_SPECS > 0 )); then
        echo "  Total specs: $TOTAL_SPECS"
        echo "  With spec front matter: $SPECS_WITH_FM"
        if (( SPECS_WITH_FM < TOTAL_SPECS )); then
            MISSING=$((TOTAL_SPECS - SPECS_WITH_FM))
            echo "  ⚠ $MISSING specs missing proper front matter"
            echo "    Run: ./tools/migrate-specs.sh /specs"
        else
            echo "  ✓ All specs have proper front matter"
        fi
    else
        echo "  ⊘ No specification files found"
    fi
else
    echo "  ⊘ /specs directory not found"
fi

# Summary
echo
echo "=== Validation Complete ==="
echo
echo "Next steps:"
echo "  1. If plugins missing: Update .claude-plugin/plugin.json or .faber.config.toml"
echo "  2. If directories missing: Run plugin :init commands"
echo "  3. If front matter missing: Run migration tools"
echo "  4. Test with: /faber:run <issue> --autonomy guarded"
