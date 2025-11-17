# Migrating Your Plugin to Use New Utility Plugins

This guide helps plugin developers migrate existing plugins to use fractary-file, fractary-docs, fractary-spec, and fractary-logs.

## Overview

The new utility plugins provide:
- **fractary-file**: Multi-provider cloud storage
- **fractary-docs**: Living documentation management
- **fractary-spec**: Ephemeral specification lifecycle
- **fractary-logs**: Operational log management

These plugins replace custom implementations with standardized, tested, and maintained solutions.

## Step 1: Update Dependencies

Add to `.claude-plugin/plugin.json`:

```json
{
  "name": "your-plugin",
  "version": "2.0.0",
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

**Note**: Not all plugins need all utilities. Include only what you need:
- **fractary-file**: If you need cloud storage or archival
- **fractary-docs**: If you generate living documentation
- **fractary-spec**: If you create ephemeral specifications
- **fractary-logs**: If you capture operational logs

## Step 2: Replace Custom Documentation

### Before (Custom Implementation)

```markdown
<!-- In your skill -->
<WORKFLOW>
1. Create design document
2. Render template with parameters
3. Write to docs/ directory
4. Add to git
</WORKFLOW>
```

### After (Using fractary-docs)

```markdown
<!-- In your skill -->
<WORKFLOW>
1. Prepare documentation parameters
2. Use @agent-fractary-docs:docs-manager to generate:
   {
     "operation": "generate",
     "doc_type": "design",
     "parameters": {
       "title": "System Architecture",
       "content": {...}
     }
   }
3. Documentation automatically includes front matter, validation, and git integration
</WORKFLOW>
```

### Migration Steps

1. **Identify custom template location**:
   ```bash
   find plugins/your-plugin -name "*.template"
   ```

2. **Copy templates to fractary-docs** (if custom):
   ```bash
   cp plugins/your-plugin/templates/custom.md.template \
      plugins/docs/skills/doc-generator/templates/your-custom-type.md.template
   ```

3. **Update skills to use fractary-docs agent**:
   - Replace template rendering logic
   - Remove file writing logic
   - Remove git commit logic
   - Invoke docs-manager agent instead

4. **Update configuration**:
   ```json
   {
     "documentation": {
       "use_fractary_docs": true,
       "custom_templates": ["your-custom-type"]
     }
   }
   ```

## Step 3: Add Spec Generation

### When to Use fractary-spec

Use if your plugin:
- Creates requirements or specifications
- Works with GitHub issues
- Needs to validate implementation against plans
- Benefits from archiving old specs

### Implementation

**In your architect/planning skill**:

```markdown
<WORKFLOW>
1. Fetch work item details
2. Classify work type (feature, bug, infrastructure)
3. Use @agent-fractary-spec:spec-manager to generate:
   {
     "operation": "generate",
     "issue_number": "{{issue_number}}",
     "template": "infrastructure"
   }
4. Spec created in /specs with proper front matter
5. Spec linked to issue via GitHub comment
</WORKFLOW>
```

**In your evaluation skill**:

```markdown
<WORKFLOW>
1. Implementation complete
2. Use @agent-fractary-spec:spec-manager to validate:
   {
     "operation": "validate",
     "issue_number": "{{issue_number}}"
   }
3. Validation report shows coverage
</WORKFLOW>
```

**In your release skill**:

```markdown
<WORKFLOW>
1. Work complete and verified
2. Use @agent-fractary-spec:spec-manager to archive:
   {
     "operation": "archive",
     "issue_number": "{{issue_number}}"
   }
3. Specs uploaded to cloud, removed locally
4. Archive link added to GitHub
</WORKFLOW>
```

## Step 4: Add Log Management

### When to Use fractary-logs

Use if your plugin:
- Performs long-running operations
- Generates deployment/build logs
- Benefits from historical log search
- Needs to preserve logs but not in git

### Implementation

**At workflow start**:

```markdown
Use @agent-fractary-logs:log-manager to start capture:
{
  "operation": "capture",
  "issue_number": "{{issue_number}}",
  "type": "deployment"
}
```

**During operations (optional)**:

```markdown
Use @agent-fractary-logs:log-manager to append:
{
  "operation": "log",
  "issue_number": "{{issue_number}}",
  "message": "Deploying to production...",
  "level": "info"
}
```

**At workflow end**:

```markdown
Use @agent-fractary-logs:log-manager to archive:
{
  "operation": "archive",
  "issue_number": "{{issue_number}}"
}
```

## Step 5: Integrate Cloud Storage

### When to Use fractary-file

Use if you need to:
- Archive specifications (via fractary-spec)
- Archive logs (via fractary-logs)
- Store artifacts (builds, reports, exports)
- Support multiple cloud providers

### Direct Usage

If your plugin needs direct file storage:

```markdown
Use @agent-fractary-file:file-manager to upload:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./deployment-report.pdf",
    "remote_path": "deployments/2025/01/report.pdf",
    "public": false
  }
}
```

### Indirect Usage

If using fractary-spec or fractary-logs, they automatically use fractary-file for archival. No direct integration needed.

## Step 6: Update Configuration

### Plugin Configuration

Add plugin settings to your config file:

```json
{
  "plugins": {
    "docs": {
      "enabled": true,
      "use_custom_templates": true
    },
    "spec": {
      "generate_on_architect": true,
      "archive_on_release": true
    },
    "logs": {
      "capture_sessions": true,
      "archive_on_release": true,
      "retention_days": 30
    },
    "file": {
      "handler": "s3"
    }
  }
}
```

### FABER Integration (if using FABER)

Update `.faber.config.toml`:

```toml
[plugins]
file = "fractary-file"
docs = "fractary-docs"
spec = "fractary-spec"
logs = "fractary-logs"

[workflow.architect]
generate_spec = true

[workflow.release]
archive_specs = true
archive_logs = true
```

## Step 7: Test Migration

### Unit Testing

Test each integration point:

```bash
# Test documentation generation
/your-plugin:test-docs

# Test spec generation
/your-plugin:test-specs

# Test log capture
/your-plugin:test-logs

# Test file upload
/your-plugin:test-storage
```

### Integration Testing

Run a complete workflow:

```bash
# Use a test issue
/faber:run 999 --autonomy guarded

# Verify:
# - Docs created in /docs
# - Spec created in /specs
# - Logs captured in /logs
# - All archived on completion
```

### Validation

Run migration validation:

```bash
./tools/validate-migration.sh
```

Expected output:
- ✓ All plugin dependencies present
- ✓ Configuration files exist
- ✓ Directory structure correct
- ✓ Front matter complete

## Step 8: Update Documentation

### Plugin README

Update your plugin's README.md:

```markdown
## Dependencies

This plugin requires:
- fractary-file (cloud storage)
- fractary-docs (documentation)
- fractary-spec (specifications)
- fractary-logs (logging)

## Features

- Uses fractary-docs for standardized documentation
- Specs automatically archived via fractary-spec
- Session logs captured via fractary-logs
- Cloud storage via fractary-file (S3, R2, GCS, etc.)
```

### Migration Notes

Add a MIGRATION.md:

```markdown
# Migration to v2.0

Version 2.0 adopts fractary utility plugins.

## Breaking Changes

- Custom templates moved to fractary-docs
- Specs now in /specs (not project root)
- Logs archived to cloud (not in git)

## Migration Steps

1. Run: /your-plugin:migrate-v2
2. Update configuration
3. Test with dry-run

See docs/guides/migrating-plugin-to-new-utils.md for details.
```

## Rollback Plan

If migration causes issues:

### Option 1: Parallel Mode

Run both old and new systems:

```json
{
  "migration": {
    "mode": "parallel",
    "prefer_new_plugins": true,
    "fallback_to_old": true
  }
}
```

### Option 2: Gradual Cutover

Migrate one feature at a time:

1. **Week 1**: Documentation only
2. **Week 2**: Add specs
3. **Week 3**: Add logs
4. **Week 4**: Remove old implementation

### Option 3: Full Revert

Revert to previous version:

```bash
git revert <migration-commit>
git push
```

## Common Issues

### "Agent not found"

**Problem**: fractary-docs agent not available

**Solution**: Ensure plugin installed and in `.claude-plugin/plugin.json` requires list

### "Configuration missing"

**Problem**: Plugin not initialized

**Solution**:
```bash
/fractary-file:init
/fractary-docs:init
/fractary-spec:init
/fractary-logs:init
```

### "Template not found"

**Problem**: Custom template not recognized

**Solution**: Copy template to fractary-docs and update config

### "Upload failed"

**Problem**: Cloud storage not configured

**Solution**: Configure fractary-file handler:
```bash
# Edit config
vim .fractary/plugins/file/config.json

# Set environment variables
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
```

## Best Practices

### 1. Don't Duplicate Functionality

If utility plugin does it, use it. Don't reimplement:
- ❌ Custom template rendering → ✅ Use fractary-docs
- ❌ Custom cloud upload → ✅ Use fractary-file
- ❌ Custom archive logic → ✅ Use fractary-spec/fractary-logs

### 2. Maintain Backward Compatibility

During transition:
- Keep old commands working
- Add deprecation warnings
- Provide migration tools
- Support both modes for 2-3 releases

### 3. Document Migration

- Clear migration guide
- Before/after examples
- Known issues
- Rollback procedures

### 4. Test Thoroughly

- Unit tests for each integration
- Integration tests for workflows
- Performance tests (context usage)
- User acceptance testing

### 5. Monitor and Iterate

- Collect user feedback
- Track migration success rate
- Fix issues quickly
- Iterate on documentation

## Example: faber-cloud Migration

The faber-cloud plugin successfully migrated. See:
- `plugins/faber-cloud/.claude-plugin/plugin.json` - Dependencies
- `plugins/faber-cloud/skills/infra-architect/SKILL.md` - Spec generation
- `plugins/faber-cloud/skills/infra-deployer/SKILL.md` - Log capture
- `plugins/faber-cloud/docs/MIGRATION-v2.md` - Migration notes

## Support

For help:
1. Check plugin README troubleshooting sections
2. Review this guide
3. Check specs in specs/SPEC-00029-*.md
4. Open GitHub issue

## Version History

- **v1.0** (2025-01-15): Initial guide
