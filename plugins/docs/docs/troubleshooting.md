---
title: "Troubleshooting Guide"
type: troubleshooting
date: "2025-01-15"
status: approved
tags: ["documentation", "support", "debugging"]
---

# fractary-docs Troubleshooting Guide

Common issues and their solutions when using the fractary-docs plugin.

## Table of Contents

1. [Installation Issues](#installation-issues)
2. [Document Generation Issues](#document-generation-issues)
3. [Validation Issues](#validation-issues)
4. [Link Management Issues](#link-management-issues)
5. [Update Issues](#update-issues)
6. [Performance Issues](#performance-issues)
7. [Configuration Issues](#configuration-issues)
8. [Advanced Debugging](#advanced-debugging)

## Installation Issues

### Issue: Plugin commands not recognized

**Symptoms**:
```bash
/fractary-docs:generate adr
# Error: Command not found
```

**Diagnosis**:
```bash
# Check if plugin directory exists
ls -la plugins/docs/

# Verify command files exist
ls plugins/docs/commands/

# Check .claude-plugin/plugin.json
cat plugins/docs/.claude-plugin/plugin.json
```

**Solution**:
```bash
# Ensure plugin properly structured
cd plugins/docs
ls -la commands/ agents/ skills/

# Reload Claude Code plugin system
# (restart Claude Code or reload plugins)
```

### Issue: Configuration file not found

**Symptoms**:
```bash
/fractary-docs:init
# Error: Config directory not found
```

**Solution**:
```bash
# Create config directory
mkdir -p .fractary/plugins/docs/config

# Copy example config
cp plugins/docs/config/config.example.json \
   .fractary/plugins/docs/config/config.json

# Verify
cat .fractary/plugins/docs/config/config.json
```

### Issue: Permission denied on scripts

**Symptoms**:
```bash
# Error: Permission denied: skills/doc-generator/scripts/render-template.sh
```

**Solution**:
```bash
# Make scripts executable
chmod +x plugins/docs/skills/*/scripts/*.sh

# Verify permissions
find plugins/docs/skills -name "*.sh" -exec ls -l {} \;
```

## Document Generation Issues

### Issue: Template not found

**Symptoms**:
```bash
/fractary-docs:generate adr --title "Test" --output test.md
# Error: Template not found: adr
```

**Diagnosis**:
```bash
# Check template files exist
ls plugins/docs/skills/doc-generator/templates/

# Should show: adr.md.template, design.md.template, etc.
```

**Solution**:
```bash
# Verify template name is valid
# Valid types: adr, design, runbook, api-spec, test-report,
#              deployment, changelog, architecture,
#              troubleshooting, postmortem

# Check spelling in command
/fractary-docs:generate adr --title "..." --output ...
#                       ^^^ Correct: all lowercase
```

### Issue: Generated document has no content

**Symptoms**:
- Document created but only has front matter
- No template sections present

**Diagnosis**:
```bash
# Check template file content
cat plugins/docs/skills/doc-generator/templates/adr.md.template

# Verify render-template.sh works
./plugins/docs/skills/doc-generator/scripts/render-template.sh \
  --template plugins/docs/skills/doc-generator/templates/adr.md.template \
  --variables '{"title":"Test"}'
```

**Solution**:
1. Verify template file is not corrupted
2. Check template has proper Mustache syntax
3. Regenerate from clean template:
   ```bash
   git checkout plugins/docs/skills/doc-generator/templates/adr.md.template
   ```

### Issue: Invalid front matter generated

**Symptoms**:
```yaml
---
title: Untitled Document
type:  # Empty type
date:  # Empty date
---
```

**Solution**:
```bash
# Always provide required parameters
/fractary-docs:generate adr \
  --title "Proper Title" \
  --output docs/adrs/ADR-001.md \
  --author "Your Name" \
  --status "proposed"

# Or set defaults in config
jq '.frontmatter.default_author = "Engineering Team"' \
  .fractary/plugins/docs/config/config.json > tmp.$$ && \
  mv tmp.$$ .fractary/plugins/docs/config/config.json
```

## Validation Issues

### Issue: "Missing required field" errors

**Symptoms**:
```bash
/fractary-docs:validate doc.md
# Error: Missing required field: type
# Error: Missing required field: date
```

**Diagnosis**:
```bash
# Check front matter
head -20 doc.md

# Should have:
# ---
# title: "..."
# type: "adr"  # or other valid type
# date: "2025-01-15"
# ---
```

**Solution**:
```bash
# Fix front matter manually
vim doc.md

# Or use update command
/fractary-docs:update doc.md --field type --value "adr"
/fractary-docs:update doc.md --field date --value "$(date +%Y-%m-%d)"
```

### Issue: "Invalid document type" error

**Symptoms**:
```bash
/fractary-docs:validate doc.md
# Error: Invalid document type: 'ADR'. Must be one of: adr, design, ...
```

**Solution**:
```bash
# Type must be lowercase
# Invalid: type: ADR
# Valid:   type: adr

# Fix with:
/fractary-docs:update doc.md --field type --value "adr"
```

### Issue: "Missing required section" errors

**Symptoms**:
```bash
/fractary-docs:validate docs/adrs/ADR-001.md
# Error: Missing required section: Context
# Error: Missing required section: Decision
```

**Diagnosis**:
```bash
# Check document structure
grep "^##" docs/adrs/ADR-001.md

# ADR requires: Status, Context, Decision, Consequences
```

**Solution**:
```bash
# Add missing sections to document
vim docs/adrs/ADR-001.md

# Add:
# ## Context
# [Your content]
#
# ## Decision
# [Your content]
```

**Reference**: See [Validation Rules](../skills/doc-validator/docs/validation-rules.md) for required sections per type

### Issue: Validation passes but should fail

**Symptoms**:
- Obvious errors but validation succeeds
- Broken links not detected

**Diagnosis**:
```bash
# Check if validation disabled in config
jq '.validation.enabled' .fractary/plugins/docs/config/config.json

# Check validation mode
/fractary-docs:validate doc.md --format json | jq '.total_issues'
```

**Solution**:
```bash
# Enable strict mode
jq '.validation.strict_mode = true' \
  .fractary/plugins/docs/config/config.json > tmp.$$ && \
  mv tmp.$$ .fractary/plugins/docs/config/config.json

# Run with strict validation
/fractary-docs:validate docs/ --strict
```

## Link Management Issues

### Issue: "Broken link detected"

**Symptoms**:
```bash
/fractary-docs:validate doc.md
# Error: Broken internal link: ../missing.md (file not found)
```

**Diagnosis**:
```bash
# Check if file exists
ls -la ../missing.md

# Check relative path from document
cd $(dirname doc.md)
ls -la ../missing.md
```

**Solution**:
```bash
# Option 1: Fix the link
vim doc.md
# Update link to correct path

# Option 2: Create missing file
touch ../missing.md

# Option 3: Remove the link
# Edit document to remove broken reference
```

### Issue: Bidirectional link not created

**Symptoms**:
- Link added to source file
- Link NOT added to target file

**Diagnosis**:
```bash
# Check both files
grep "related:" source.md
grep "related:" target.md  # Empty or missing

# Check configuration
jq '.linking.bidirectional_links' .fractary/plugins/docs/config/config.json
```

**Solution**:
```bash
# Ensure bidirectional linking enabled
jq '.linking.bidirectional_links = true' \
  .fractary/plugins/docs/config/config.json > tmp.$$ && \
  mv tmp.$$ .fractary/plugins/docs/config/config.json

# Re-create link
/fractary-docs:link source.md target.md
```

### Issue: "Related array not found"

**Symptoms**:
```bash
/fractary-docs:link source.md target.md
# Warning: source.md has no front matter, skipping
```

**Solution**:
```bash
# Add front matter to document
cat > source.md << 'EOF'
---
title: "Document Title"
type: design
date: "2025-01-15"
related: []
---

# Document Title

[Existing content...]
EOF

# Then retry linking
/fractary-docs:link source.md target.md
```

### Issue: Circular reference detected

**Symptoms**:
```bash
# A links to B, B links to C, C links back to A
# Graph generation fails or warns
```

**Solution**:
```bash
# Identify the cycle
/fractary-docs:generate-graph docs/ --output graph.json --format json
jq '.edges' graph.json | grep -E '(A|B|C)'

# Break the cycle by removing one link
/fractary-docs:update C.md \
  --field related \
  --value '[]'  # Remove link back to A
```

## Update Issues

### Issue: Update corrupts front matter

**Symptoms**:
```bash
/fractary-docs:update doc.md --field status --value "accepted"
# Front matter becomes invalid YAML
```

**Diagnosis**:
```bash
# Check front matter before
head -20 doc.md

# Check if backup exists
ls -la doc.md.backup.*
```

**Solution**:
```bash
# Restore from backup
mv doc.md.backup.20250115120000 doc.md

# Use proper JSON format for complex values
/fractary-docs:update doc.md \
  --field tags \
  --value '["tag1", "tag2"]'  # Valid JSON array
```

### Issue: Section not found

**Symptoms**:
```bash
/fractary-docs:update doc.md --section "Missing Section" --content "..."
# Error: Section not found: Missing Section
```

**Diagnosis**:
```bash
# List all sections
grep "^##" doc.md
```

**Solution**:
```bash
# Use exact section name (case-sensitive)
/fractary-docs:update doc.md --section "Context" --content "..."

# Or create new section with append mode
/fractary-docs:update doc.md \
  --section "New Section" \
  --content "## New Section\n\nContent here" \
  --mode append
```

### Issue: Backup files accumulating

**Symptoms**:
```bash
ls docs/
# doc.md.backup.20250115120000
# doc.md.backup.20250115130000
# doc.md.backup.20250115140000
# ... many backups
```

**Solution**:
```bash
# Clean old backups (keep last 5)
find docs -name "*.backup.*" -type f | \
  sort -r | tail -n +6 | xargs rm -f

# Or disable backups in config
jq '.updates.create_backup = false' \
  .fractary/plugins/docs/config/config.json > tmp.$$ && \
  mv tmp.$$ .fractary/plugins/docs/config/config.json
```

## Performance Issues

### Issue: Validation very slow

**Symptoms**:
```bash
time /fractary-docs:validate docs/
# Takes > 5 minutes for 100 documents
```

**Diagnosis**:
```bash
# Check if external link checking enabled
jq '.validation.check_external_links' .fractary/plugins/docs/config/config.json

# Check document count
find docs -name "*.md" | wc -l
```

**Solution**:
```bash
# Disable external link checking
jq '.validation.check_external_links = false' \
  .fractary/plugins/docs/config/config.json > tmp.$$ && \
  mv tmp.$$ .fractary/plugins/docs/config/config.json

# Or validate in batches
find docs -name "*.md" | head -50 | while read f; do
  /fractary-docs:validate "$f"
done
```

### Issue: Index generation hangs

**Symptoms**:
```bash
/fractary-docs:create-index docs/ --output README.md
# Hangs indefinitely
```

**Diagnosis**:
```bash
# Check for corrupted files
find docs -name "*.md" -size 0

# Check for circular symlinks
find docs -type l
```

**Solution**:
```bash
# Remove empty/corrupted files
find docs -name "*.md" -size 0 -delete

# Remove problematic symlinks
find docs -type l -delete

# Retry index generation
/fractary-docs:create-index docs/ --output README.md
```

### Issue: Graph generation fails with large dataset

**Symptoms**:
```bash
/fractary-docs:generate-graph docs/ --output graph.json
# Error: Out of memory
```

**Solution**:
```bash
# Generate in smaller batches
/fractary-docs:generate-graph docs/adrs/ --output adrs-graph.json
/fractary-docs:generate-graph docs/designs/ --output designs-graph.json

# Or exclude tags to reduce graph size
/fractary-docs:generate-graph docs/ \
  --output graph.json \
  --format json
  # Without --include-tags
```

## Configuration Issues

### Issue: Config changes not applied

**Symptoms**:
- Updated config.json
- Behavior unchanged

**Diagnosis**:
```bash
# Verify config file location
ls -la .fractary/plugins/docs/config/config.json

# Check JSON syntax
jq '.' .fractary/plugins/docs/config/config.json
```

**Solution**:
```bash
# Ensure config in correct location
mkdir -p .fractary/plugins/docs/config
mv config.json .fractary/plugins/docs/config/

# Validate JSON syntax
cat .fractary/plugins/docs/config/config.json | jq '.'

# If syntax error, fix or restore from example
cp plugins/docs/config/config.example.json \
   .fractary/plugins/docs/config/config.json
```

### Issue: Invalid JSON in config

**Symptoms**:
```bash
/fractary-docs:validate docs/
# Error: Failed to parse config: Unexpected token
```

**Diagnosis**:
```bash
# Validate JSON
jq '.' .fractary/plugins/docs/config/config.json
# Shows line with error
```

**Solution**:
```bash
# Common JSON errors:
# - Trailing commas
# - Unquoted keys
# - Single quotes instead of double

# Fix example:
# Bad:  {'key': 'value',}
# Good: {"key": "value"}

# Or restore from example
cp plugins/docs/config/config.example.json \
   .fractary/plugins/docs/config/config.json
```

## Advanced Debugging

### Enable Debug Mode

```bash
# Add debug flag to config
jq '.debug = true' .fractary/plugins/docs/config/config.json > tmp.$$ && \
  mv tmp.$$ .fractary/plugins/docs/config/config.json

# Run command with verbose output
/fractary-docs:validate docs/ 2>&1 | tee debug.log
```

### Test Individual Scripts

```bash
# Test render-template.sh
./plugins/docs/skills/doc-generator/scripts/render-template.sh \
  --template plugins/docs/skills/doc-generator/templates/adr.md.template \
  --variables '{"title":"Test","date":"2025-01-15"}'

# Test validate-structure.sh
./plugins/docs/skills/doc-validator/scripts/validate-structure.sh \
  --file docs/adrs/ADR-001.md \
  --doc-type adr

# Test check-links.sh
./plugins/docs/skills/doc-validator/scripts/check-links.sh \
  --file docs/adrs/ADR-001.md
```

### Check Dependencies

```bash
# Required tools
command -v jq || echo "jq not found"
command -v yq || echo "yq not found (optional)"
command -v markdownlint || echo "markdownlint not found (optional)"

# Install missing dependencies
# macOS:
brew install jq yq markdownlint-cli

# Ubuntu/Debian:
sudo apt-get install jq
npm install -g markdownlint-cli

# Alpine:
apk add jq
npm install -g markdownlint-cli
```

### Inspect Plugin State

```bash
# Check plugin structure
tree plugins/docs

# Verify all required files present
find plugins/docs -name "*.md" -o -name "*.sh" | sort

# Check file permissions
find plugins/docs/skills -name "*.sh" -exec ls -l {} \;
```

### Analyze Error Messages

**Common error patterns**:

| Error Message | Likely Cause | Solution |
|---------------|--------------|----------|
| "File not found" | Incorrect path | Use absolute or correct relative path |
| "Permission denied" | Script not executable | `chmod +x script.sh` |
| "JSON parse error" | Invalid JSON | Validate with `jq '.' file.json` |
| "YAML parse error" | Invalid front matter | Check YAML syntax |
| "Template not found" | Invalid type | Check valid types list |
| "Section not found" | Case mismatch | Use exact section heading |
| "Command not found" | Plugin not loaded | Restart Claude Code |

## Getting Help

### Collect Debug Information

```bash
# Create debug report
cat > debug-report.md << EOF
# Debug Report

## Environment
- OS: $(uname -s)
- Shell: $SHELL
- Plugin location: $(pwd)/plugins/docs

## Config
\`\`\`json
$(cat .fractary/plugins/docs/config/config.json)
\`\`\`

## Error
\`\`\`
[Paste error message]
\`\`\`

## Steps to Reproduce
1. [Step 1]
2. [Step 2]
3. [Error occurs]

## Expected Behavior
[What should happen]

## Actual Behavior
[What actually happens]
EOF
```

### Report Issues

1. **Check existing issues**: [GitHub Issues](https://github.com/fractary/claude-plugins/issues)
2. **Create new issue** with debug report
3. **Include**:
   - Error message
   - Steps to reproduce
   - Configuration (sanitized)
   - Plugin version
   - OS and environment

### Community Support

- **Slack**: #fractary-docs channel
- **Discussions**: GitHub Discussions
- **Documentation**: [Full README](../README.md)

## Prevention

### Best Practices

1. **Always validate after changes**:
   ```bash
   vim doc.md
   /fractary-docs:validate doc.md
   ```

2. **Use backups for updates**:
   ```bash
   /fractary-docs:update doc.md --field ... --backup
   ```

3. **Test on samples first**:
   ```bash
   # Test on sample before real docs
   /fractary-docs:validate samples/
   /fractary-docs:validate docs/
   ```

4. **Keep configuration simple**:
   ```bash
   # Start with defaults
   cp config.example.json config.json
   # Add customizations gradually
   ```

5. **Regular maintenance**:
   ```bash
   # Weekly: Check links
   /fractary-docs:link-check docs/

   # Monthly: Full validation
   /fractary-docs:validate docs/ --strict
   ```

## Common Workflows Checklist

### Creating New Document
- [ ] Use appropriate template type
- [ ] Provide title and output path
- [ ] Validate after generation
- [ ] Add to git

### Updating Document
- [ ] Create backup if making large changes
- [ ] Validate after update
- [ ] Check related documents if changing links
- [ ] Update index if adding/removing documents

### Validating Documentation
- [ ] Run validation after significant changes
- [ ] Check links periodically
- [ ] Use strict mode for releases
- [ ] Fix errors before warnings

### Linking Documents
- [ ] Use relative paths
- [ ] Enable bidirectional linking
- [ ] Validate both documents after linking
- [ ] Update graph after major changes

## Reference

- [Quick Start Guide](./quick-start.md) - Getting started
- [Integration Testing](./integration-testing.md) - Testing procedures
- [Plugin README](../README.md) - Complete documentation
- [Validation Rules](../skills/doc-validator/docs/validation-rules.md) - Validation details
- [Linking Conventions](../skills/doc-linker/docs/linking-conventions.md) - Linking best practices

## Version History

- **v1.0.0** - Initial release
- **Current** - See [CHANGELOG](../CHANGELOG.md)

---

**Still having issues?** Create a [GitHub Issue](https://github.com/fractary/claude-plugins/issues) with your debug report.
