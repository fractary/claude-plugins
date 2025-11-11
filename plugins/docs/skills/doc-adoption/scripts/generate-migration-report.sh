#!/usr/bin/env bash
#
# generate-migration-report.sh - Generate comprehensive migration report
#
# Usage: generate-migration-report.sh <discovery_docs> <discovery_structure> <discovery_frontmatter> <discovery_quality> <output_md>
#
# Output: Markdown migration guide

set -euo pipefail

DISCOVERY_DOCS="${1:-discovery-docs.json}"
DISCOVERY_STRUCTURE="${2:-discovery-structure.json}"
DISCOVERY_FRONTMATTER="${3:-discovery-frontmatter.json}"
DISCOVERY_QUALITY="${4:-discovery-quality.json}"
OUTPUT_MD="${5:-MIGRATION.md}"

# Load data
total_files=$(jq -r '.total_files' "$DISCOVERY_DOCS")
structure_type=$(jq -r '.structure_type' "$DISCOVERY_STRUCTURE")
with_frontmatter=$(jq -r '.with_frontmatter' "$DISCOVERY_FRONTMATTER")
without_frontmatter=$(jq -r '.without_frontmatter' "$DISCOVERY_FRONTMATTER")
avg_quality=$(jq -r '.average_quality_score' "$DISCOVERY_QUALITY")
low_quality=$(jq -r '.distribution.low_quality' "$DISCOVERY_QUALITY")

# Determine complexity
complexity="MINIMAL"
estimated_hours=4
if [ $total_files -gt 30 ] || [ $without_frontmatter -gt 15 ] || [ $low_quality -gt 10 ]; then
    complexity="EXTENSIVE"
    estimated_hours=16
elif [ $total_files -gt 10 ] || [ $without_frontmatter -gt 5 ]; then
    complexity="MODERATE"
    estimated_hours=8
fi

# Generate report
cat > "$OUTPUT_MD" <<EOF
# Documentation Migration Guide

**Generated:** $(date "+%Y-%m-%d %H:%M:%S")

## Executive Summary

This report provides a comprehensive analysis and migration plan for adopting fractary-docs to manage your project documentation.

**Complexity Level:** $complexity
**Estimated Migration Time:** $estimated_hours hours
**Documentation Files:** $total_files
**Current Structure:** $structure_type

## Current State Assessment

### Documentation Inventory

- **Total Documentation Files:** $total_files
- **Documentation Types:** $(jq -r '.by_type | to_entries | map("\(.key): \(.value)") | join(", ")' "$DISCOVERY_DOCS")

### Structure Analysis

- **Organization Type:** $structure_type
- **Primary Location:** $(jq -r '.primary_docs_dir' "$DISCOVERY_STRUCTURE")

### Front Matter Status

- **With Front Matter:** $with_frontmatter files
- **Without Front Matter:** $without_frontmatter files
- **Coverage:** $((total_files > 0 ? with_frontmatter * 100 / total_files : 0))%

### Quality Assessment

- **Average Quality Score:** $avg_quality/10
- **High Quality:** $(jq -r '.distribution.high_quality' "$DISCOVERY_QUALITY") files
- **Medium Quality:** $(jq -r '.distribution.medium_quality' "$DISCOVERY_QUALITY") files
- **Low Quality:** $low_quality files

## Migration Plan

### Phase 1: Configuration Setup (1-2 hours)

1. Review generated configuration
2. Install fractary-docs configuration
3. Validate configuration

### Phase 2: Front Matter Standardization ($([ $without_frontmatter -gt 10 ] && echo "4-6 hours" || echo "2-3 hours"))

1. Add front matter to $without_frontmatter files
2. Standardize existing front matter fields
3. Enable codex sync

### Phase 3: Documentation Organization ($([ "$structure_type" = "flat" ] && echo "2-3 hours" || echo "1 hour"))

1. Organize documentation by type
2. Move files to standard locations
3. Update cross-references

### Phase 4: Quality Improvements ($([ $low_quality -gt 5 ] && echo "3-5 hours" || echo "1-2 hours"))

1. Improve $low_quality low-quality documents
2. Fix broken links
3. Add missing sections

### Phase 5: Validation and Testing (1 hour)

1. Validate all documentation
2. Check links
3. Generate index

## Recommendations

### High Priority

$([ $without_frontmatter -gt 0 ] && echo "- Add front matter to $without_frontmatter files for codex integration" || echo "- Front matter coverage is complete")
$([ $low_quality -gt 0 ] && echo "- Improve $low_quality low-quality documents" || echo "- Documentation quality is good")
$([ "$structure_type" = "flat" ] && echo "- Organize documentation into type-based directories" || echo "- Current structure is well-organized")

### Medium Priority

- Standardize naming conventions to kebab-case
- Add cross-references between related documents
- Generate documentation index

### Low Priority

- Add more detailed API documentation
- Create additional runbooks for operational procedures
- Set up automated validation in CI/CD

## Migration Checklist

- [ ] Review generated configuration
- [ ] Install fractary-docs configuration
- [ ] Add front matter to existing documents
- [ ] Reorganize documentation structure
- [ ] Fix broken links
- [ ] Validate all documentation
- [ ] Generate documentation index
- [ ] Update team documentation guidelines
- [ ] Train team on new workflow

## Next Steps

1. Review this migration report thoroughly
2. Install configuration: Use provided docs-config.json
3. Start with high-value documents (ADRs, critical runbooks)
4. Migrate systematically using /fractary-docs commands
5. Validate frequently: /fractary-docs:validate

## Rollback Plan

If migration doesn't work as expected:
1. Configuration is in .fractary/ (can be removed)
2. Original documentation is unchanged
3. Continue using previous workflow

## Support

For detailed documentation on fractary-docs:
- Plugin README: plugins/docs/README.md
- Command reference: plugins/docs/commands/
- Integration guide: plugins/docs/docs/integration-testing.md
EOF

echo "Migration report generated: $OUTPUT_MD"
