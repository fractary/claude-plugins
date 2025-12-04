# Integration Testing Guide

This guide demonstrates how to test the fractary-docs plugin end-to-end using the provided sample documentation.

## Overview

The integration tests validate:
1. Document generation from templates
2. Document updates and modifications
3. Validation of all document types
4. Link checking and relationship management
5. Index generation and graph visualization

## Prerequisites

```bash
# Navigate to plugin directory
cd plugins/docs

# Ensure config exists
mkdir -p .fractary/plugins/docs
cp config/config.example.json .fractary/plugins/docs/config.json

# Verify samples directory
ls -la samples/
```

## Test Suite

### Test 1: Document Generation

**Objective**: Generate new documents from templates

**Steps**:

1. Generate an ADR:
```bash
/fractary-docs:generate adr --title "ADR-002: Use Redis for Caching" --output samples/adrs/ADR-002-redis.md

# Verify front matter is present
head -20 samples/adrs/ADR-002-redis.md

# Expected: YAML front matter with title, type, date, status
```

2. Generate a design document:
```bash
/fractary-docs:generate design --title "Caching Architecture" --output samples/designs/caching-architecture.md

# Verify template structure
grep -E "^##" samples/designs/caching-architecture.md

# Expected: ## Overview, ## Architecture, etc.
```

3. Generate a runbook:
```bash
/fractary-docs:generate runbook --title "Cache Invalidation" --output samples/runbooks/cache-invalidation.md

# Check sections
grep -E "^##" samples/runbooks/cache-invalidation.md

# Expected: ## Purpose, ## Prerequisites, ## Steps
```

**Success Criteria**:
- ✅ All documents created with correct file paths
- ✅ Front matter contains required fields (title, type, date)
- ✅ Document structure matches template
- ✅ Markdown is valid

### Test 2: Document Updates

**Objective**: Update existing documents without breaking structure

**Steps**:

1. Update front matter metadata:
```bash
# Update status of ADR-001
/fractary-docs:update samples/adrs/ADR-001-postgresql.md \
  --field status \
  --value "superseded"

# Verify update
grep "status:" samples/adrs/ADR-001-postgresql.md
# Expected: status: superseded
```

2. Update section content:
```bash
# Add new consequence to ADR
/fractary-docs:update samples/adrs/ADR-001-postgresql.md \
  --section "Consequences" \
  --content "### Cost Optimization\n\nRDS Reserved Instances provide 40% cost savings over on-demand." \
  --mode append

# Verify section added
grep -A 3 "Cost Optimization" samples/adrs/ADR-001-postgresql.md
```

3. Replace content with pattern:
```bash
# Update author information
/fractary-docs:update samples/designs/database-architecture.md \
  --pattern "Platform Team" \
  --replacement "Database Team" \
  --backup

# Verify backup created
ls -la samples/designs/database-architecture.md.backup.*
```

**Success Criteria**:
- ✅ Metadata updated correctly
- ✅ Section content preserved
- ✅ Backups created automatically
- ✅ No structure corruption

### Test 3: Validation

**Objective**: Validate all document types

**Steps**:

1. Validate individual document:
```bash
/fractary-docs:validate samples/adrs/ADR-001-postgresql.md

# Expected output:
# ✅ Front matter: valid
# ✅ Structure: all required sections present
# ✅ Links: no broken links
# ✅ Markdown: valid syntax
```

2. Validate entire directory:
```bash
/fractary-docs:validate samples/

# Expected summary:
# Total files: 5
# Valid files: 5
# Errors: 0
# Warnings: 0
```

3. Strict mode validation:
```bash
/fractary-docs:validate samples/ --strict

# Expected: Additional warnings for missing optional fields
```

4. Validate with external link checking:
```bash
/fractary-docs:validate samples/adrs/ADR-001-postgresql.md --check-external

# Note: This may be slow, verifies HTTP/HTTPS links
```

**Success Criteria**:
- ✅ All required front matter fields present
- ✅ All required sections exist per document type
- ✅ No broken internal links
- ✅ Valid markdown syntax

### Test 4: Link Management

**Objective**: Create and verify document relationships

**Steps**:

1. Create bidirectional link:
```bash
/fractary-docs:link \
  samples/adrs/ADR-001-postgresql.md \
  samples/designs/database-architecture.md

# Verify both files updated
grep "related:" samples/adrs/ADR-001-postgresql.md
grep "related:" samples/designs/database-architecture.md

# Expected: Both files reference each other in related[] array
```

2. Add multiple relationships:
```bash
# Link design to runbooks
/fractary-docs:link \
  samples/designs/database-architecture.md \
  samples/runbooks/database-failover.md

/fractary-docs:link \
  samples/designs/database-architecture.md \
  samples/runbooks/database-maintenance.md

# Verify all links
grep -A 5 "related:" samples/designs/database-architecture.md
```

3. Check for broken links:
```bash
/fractary-docs:link-check samples/

# Expected: Report showing all links healthy
# Total links: ~15
# Broken links: 0
```

**Success Criteria**:
- ✅ Bidirectional links created
- ✅ related[] arrays updated in front matter
- ✅ No duplicate links
- ✅ All links validate successfully

### Test 5: Index Generation

**Objective**: Generate browsable documentation indexes

**Steps**:

1. Create type-based index:
```bash
/fractary-docs:create-index samples/ \
  --output samples/README.md \
  --title "Sample Documentation" \
  --group-by type

# View result
cat samples/README.md

# Expected:
# ## Architecture Decision Records
# - [ADR-001: PostgreSQL]...
# ## Design Documents
# - [Database Architecture]...
```

2. Create tag-based index:
```bash
/fractary-docs:create-index samples/ \
  --output samples/INDEX-BY-TAG.md \
  --group-by tag

# View result
cat samples/INDEX-BY-TAG.md

# Expected grouping by: database, infrastructure, operations, etc.
```

3. Create flat index:
```bash
/fractary-docs:create-index samples/ \
  --output samples/INDEX-FLAT.md \
  --group-by flat

# Verify alphabetical listing
grep -E "^-" samples/INDEX-FLAT.md
```

**Success Criteria**:
- ✅ Index files created
- ✅ All documents listed
- ✅ Grouping correct
- ✅ Links functional

### Test 6: Graph Generation

**Objective**: Visualize document relationships

**Steps**:

1. Generate Mermaid graph:
```bash
/fractary-docs:generate-graph samples/ \
  --output samples/GRAPH.md \
  --format mermaid

# View graph
cat samples/GRAPH.md

# Expected: Mermaid diagram showing document relationships
```

2. Generate DOT format:
```bash
/fractary-docs:generate-graph samples/ \
  --output samples/graph.dot \
  --format dot

# Render with GraphViz (if installed)
dot -Tpng samples/graph.dot -o samples/graph.png
```

3. Generate JSON graph:
```bash
/fractary-docs:generate-graph samples/ \
  --output samples/graph.json \
  --format json

# View structure
cat samples/graph.json | jq '.nodes | length'
cat samples/graph.json | jq '.edges | length'
```

4. Include tag relationships:
```bash
/fractary-docs:generate-graph samples/ \
  --output samples/GRAPH-TAGS.md \
  --format mermaid \
  --include-tags

# Compare with non-tag version
diff samples/GRAPH.md samples/GRAPH-TAGS.md
```

**Success Criteria**:
- ✅ Graph files generated
- ✅ All documents represented as nodes
- ✅ Relationships shown as edges
- ✅ Visual grouping by type/tags

## Complete Workflow Test

**Scenario**: Create a new feature documentation set

**Steps**:

1. **Generate Base Documents**:
```bash
# Create ADR
/fractary-docs:generate adr \
  --title "ADR-003: Implement Circuit Breaker" \
  --output samples/adrs/ADR-003-circuit-breaker.md

# Create Design
/fractary-docs:generate design \
  --title "Circuit Breaker Design" \
  --output samples/designs/circuit-breaker.md

# Create Runbook
/fractary-docs:generate runbook \
  --title "Circuit Breaker Operations" \
  --output samples/runbooks/circuit-breaker-ops.md
```

2. **Update Content**:
```bash
# Update ADR status
/fractary-docs:update samples/adrs/ADR-003-circuit-breaker.md \
  --field status \
  --value "accepted"

# Add tags
/fractary-docs:update samples/adrs/ADR-003-circuit-breaker.md \
  --field tags \
  --value '["reliability", "patterns"]'
```

3. **Create Relationships**:
```bash
# Link ADR to Design
/fractary-docs:link \
  samples/adrs/ADR-003-circuit-breaker.md \
  samples/designs/circuit-breaker.md

# Link Design to Runbook
/fractary-docs:link \
  samples/designs/circuit-breaker.md \
  samples/runbooks/circuit-breaker-ops.md
```

4. **Validate**:
```bash
# Validate all new documents
/fractary-docs:validate samples/adrs/ADR-003-circuit-breaker.md
/fractary-docs:validate samples/designs/circuit-breaker.md
/fractary-docs:validate samples/runbooks/circuit-breaker-ops.md

# Check links
/fractary-docs:link-check samples/
```

5. **Update Index**:
```bash
# Regenerate index
/fractary-docs:create-index samples/ \
  --output samples/README.md \
  --group-by type

# Verify new docs appear
grep "Circuit Breaker" samples/README.md
```

6. **Update Graph**:
```bash
# Regenerate graph
/fractary-docs:generate-graph samples/ \
  --output samples/GRAPH.md \
  --format mermaid

# Verify relationships
grep "ADR-003" samples/GRAPH.md
```

**Success Criteria**:
- ✅ Complete documentation set created
- ✅ All documents properly linked
- ✅ Validation passes
- ✅ Index includes new documents
- ✅ Graph shows relationships

## Automated Test Script

Create `test-integration.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "🧪 Running fractary-docs Integration Tests"
echo "=========================================="

TEST_DIR="samples"
FAILED=0

# Test 1: Validate all samples
echo "Test 1: Validating samples..."
if /fractary-docs:validate $TEST_DIR > /dev/null 2>&1; then
  echo "✅ Validation passed"
else
  echo "❌ Validation failed"
  ((FAILED++))
fi

# Test 2: Check links
echo "Test 2: Checking links..."
RESULT=$(/fractary-docs:link-check $TEST_DIR)
BROKEN=$(echo "$RESULT" | jq -r '.summary.total_broken_links')
if [[ "$BROKEN" -eq 0 ]]; then
  echo "✅ All links valid"
else
  echo "❌ Found $BROKEN broken links"
  ((FAILED++))
fi

# Test 3: Generate index
echo "Test 3: Generating index..."
if /fractary-docs:create-index $TEST_DIR --output $TEST_DIR/README.md > /dev/null 2>&1; then
  echo "✅ Index generated"
else
  echo "❌ Index generation failed"
  ((FAILED++))
fi

# Test 4: Generate graph
echo "Test 4: Generating graph..."
if /fractary-docs:generate-graph $TEST_DIR --output $TEST_DIR/GRAPH.md > /dev/null 2>&1; then
  echo "✅ Graph generated"
else
  echo "❌ Graph generation failed"
  ((FAILED++))
fi

# Summary
echo ""
echo "=========================================="
if [[ $FAILED -eq 0 ]]; then
  echo "✅ All tests passed!"
  exit 0
else
  echo "❌ $FAILED test(s) failed"
  exit 1
fi
```

## Performance Testing

Test plugin performance with larger documentation sets:

```bash
# Generate 100 sample documents
for i in {1..100}; do
  /fractary-docs:generate adr \
    --title "ADR-$i: Sample Decision" \
    --output test/adrs/ADR-$(printf "%03d" $i).md
done

# Measure validation time
time /fractary-docs:validate test/

# Measure index generation time
time /fractary-docs:create-index test/ --output test/README.md

# Measure graph generation time
time /fractary-docs:generate-graph test/ --output test/GRAPH.md
```

**Performance Targets**:
- Validation: < 100ms per document
- Index generation: < 1s for 100 documents
- Graph generation: < 2s for 100 documents
- Link checking: < 500ms per document (internal only)

## Regression Testing

Before releases, run complete regression suite:

```bash
# 1. Validate all samples
/fractary-docs:validate samples/ --strict

# 2. Check all links (including external)
/fractary-docs:link-check samples/ --check-external

# 3. Generate all output formats
/fractary-docs:create-index samples/ --output samples/README.md --group-by type
/fractary-docs:create-index samples/ --output samples/INDEX-TAG.md --group-by tag
/fractary-docs:generate-graph samples/ --output samples/GRAPH.md --format mermaid
/fractary-docs:generate-graph samples/ --output samples/graph.dot --format dot
/fractary-docs:generate-graph samples/ --output samples/graph.json --format json

# 4. Test error handling
/fractary-docs:validate nonexistent.md  # Should fail gracefully
/fractary-docs:link missing1.md missing2.md  # Should error clearly

# 5. Test edge cases
touch samples/empty.md  # Empty file
/fractary-docs:validate samples/empty.md  # Should handle gracefully
```

## Troubleshooting Tests

### Test Failures

**Validation fails**:
- Check sample files exist
- Verify front matter format
- Review validation error messages

**Link checking fails**:
- Verify relative paths correct
- Check file references exist
- Review related[] arrays in front matter

**Generation fails**:
- Verify templates exist in skills/doc-generator/templates/
- Check output directory writable
- Review template syntax

### Debugging

Enable verbose output:
```bash
# Set debug flag in config
jq '.debug = true' .fractary/plugins/docs/config.json

# Run with verbose logging
/fractary-docs:validate samples/ --verbose
```

## CI/CD Integration

Add to CI pipeline:

```yaml
# .github/workflows/docs-test.yml
name: Documentation Tests

on: [push, pull_request]

jobs:
  test-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup fractary-docs
        run: |
          # Install plugin
          # Configure plugin

      - name: Validate documentation
        run: |
          /fractary-docs:validate docs/

      - name: Check links
        run: |
          /fractary-docs:link-check docs/

      - name: Generate artifacts
        run: |
          /fractary-docs:create-index docs/ --output docs/README.md
          /fractary-docs:generate-graph docs/ --output docs/GRAPH.md

      - name: Commit updates
        run: |
          git add docs/README.md docs/GRAPH.md
          git commit -m "Update documentation index and graph" || true
```

## Test Coverage

Current test coverage:
- ✅ Document generation (all 10 types)
- ✅ Document updates (4 operations)
- ✅ Validation (4 checks)
- ✅ Link management (4 operations)
- ✅ Index generation (4 grouping strategies)
- ✅ Graph generation (3 formats)
- ✅ Error handling
- ✅ Edge cases

## Next Steps

1. **Expand Sample Set**: Add more document types (API spec, test report, postmortem)
2. **Performance Benchmarks**: Establish baseline metrics
3. **Error Case Coverage**: Test more failure scenarios
4. **Integration with Codex**: Test memory/knowledge features
5. **Multi-Project Testing**: Test across multiple documentation sets

## References

- [Sample Documentation](../samples/)
- [Quick Start Guide](./quick-start.md)
- [Troubleshooting Guide](./troubleshooting.md)
- [Plugin README](../README.md)
