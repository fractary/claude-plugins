# FABER Workflow Templates

This directory contains workflow template files for the FABER plugin. These templates define the complete workflow structure including phases, steps, hooks, and autonomy settings.

## Overview

Workflows are now stored as separate JSON files instead of being embedded in the main `config.json`. This provides:

- **Better maintainability**: Each workflow is in its own file
- **Easier version control**: Fewer merge conflicts
- **Plugin extensibility**: Specialized plugins can provide workflow templates
- **Clearer configuration**: Config file just references workflows

## Available Workflows

### default.json
**Standard FABER workflow** for most development tasks.

- **Phases**: Frame → Architect → Build → Evaluate → Release
- **Use case**: Feature development, enhancements, refactoring
- **Autonomy**: Guarded (pauses before release)
- **Specification**: Always generated in Architect phase
- **Testing**: Full test suite with 3 retry attempts

### hotfix.json
**Expedited workflow** for critical production fixes.

- **Phases**: Frame → Build → Evaluate → Release (skips Architect)
- **Use case**: Critical bugs, security patches, urgent fixes
- **Autonomy**: Assist (human oversight throughout)
- **Specification**: Skipped for speed
- **Testing**: Quick validation with 2 retry attempts

## File Structure

Each workflow file follows the workflow.schema.json structure:

```json
{
  "$schema": "../workflow.schema.json",
  "id": "workflow-name",
  "description": "Human-readable description",
  "phases": {
    "frame": { ... },
    "architect": { ... },
    "build": { ... },
    "evaluate": { ... },
    "release": { ... }
  },
  "hooks": { ... },
  "autonomy": { ... }
}
```

## Using Workflows

### In Config File

Reference workflows in `.fractary/plugins/faber/config.json`:

```json
{
  "workflows": [
    {
      "id": "default",
      "file": "./workflows/default.json"
    },
    {
      "id": "hotfix",
      "file": "./workflows/hotfix.json"
    }
  ]
}
```

### Selecting Workflow

FABER provides three ways to select which workflow to use:

#### 1. Explicit Selection (Highest Priority)

Use the `--workflow` flag to explicitly specify which workflow to use:

```bash
# Use specific workflow
/fractary-faber:run --work-id 123 --workflow hotfix
/fractary-faber:run --work-id 456 --workflow default
```

#### 2. Automatic Inference from Issue Labels (Smart Default)

When `--workflow` is not specified, FABER automatically infers the workflow from issue labels:

```bash
# Issue #123 has label "hotfix" → automatically uses hotfix workflow
/fractary-faber:run 123

# Issue #456 has label "feature" → automatically uses default workflow
/fractary-faber:run 456
```

**Configuration** (`config.json`):
```json
{
  "workflow_inference": {
    "label_mapping": {
      "hotfix": "hotfix",
      "urgent": "hotfix",
      "critical": "hotfix",
      "security": "hotfix",
      "bug": "default",
      "feature": "default",
      "enhancement": "default"
    }
  }
}
```

**How it works:**
1. FABER fetches issue labels from the work tracking system (GitHub, Jira, Linear)
2. Checks if any label matches a key in `label_mapping`
3. Uses the mapped workflow (e.g., label "urgent" → workflow "hotfix")
4. If multiple labels match, uses the first match
5. If no labels match, falls back to first workflow in config

#### 3. Default Fallback (Last Resort)

If no `--workflow` flag is provided AND no labels match, uses the first workflow in the `workflows` array:

```bash
# No --workflow flag, issue has no matching labels → uses workflows[0] (typically "default")
/fractary-faber:run 789
```

**Selection Priority:**
```
1. --workflow flag (explicit)
   ↓
2. Issue label mapping (inferred)
   ↓
3. First workflow in config (fallback)
```

## Creating Custom Workflows

1. **Copy a template**:
   ```bash
   cp plugins/faber/config/workflows/default.json .fractary/plugins/faber/workflows/custom.json
   ```

2. **Edit workflow** to meet your needs:
   - Modify phase steps
   - Add/remove hooks
   - Adjust autonomy level
   - Customize validation

3. **Reference in config**:
   ```json
   {
     "workflows": [
       {
         "id": "custom",
         "file": "./workflows/custom.json",
         "description": "My custom workflow"
       }
     ]
   }
   ```

4. **Validate**:
   ```bash
   /fractary-faber:audit
   ```

## Workflow Schema

All workflow files must validate against `workflow.schema.json`. This ensures:

- Required fields are present (id, phases, autonomy)
- Phase structure is correct
- Step definitions are valid
- Hook configurations are proper
- Autonomy settings are valid

## Plugin-Provided Workflows

Specialized FABER plugins (like `faber-cloud`, `faber-app`) provide domain-specific workflow templates:

**Example**: `plugins/faber-cloud/workflows/`
- `infrastructure.json` - Infrastructure deployment workflow
- `terraform-aws.json` - Terraform + AWS workflow

During plugin initialization, these templates are copied to your project's workflows directory and referenced in config.json.

## Best Practices

1. **Start with templates**: Use default.json or hotfix.json as starting points
2. **Version control**: Commit workflow files to share across team
3. **Document changes**: Add description fields to custom workflows
4. **Test workflows**: Use `--autonomy dry-run` to test changes
5. **Keep workflows focused**: One workflow per use case
6. **Use meaningful IDs**: `infrastructure-aws`, `api-deployment`, etc.

## Migration from v1.x

Old TOML configs embedded workflows inline. To migrate:

1. Extract workflow from `.faber.config.toml`
2. Convert to JSON format
3. Save as `workflows/default.json`
4. Update config.json to reference file
5. Validate with `/fractary-faber:audit`

See [docs/MIGRATION-v2.md](../../docs/MIGRATION-v2.md) for detailed migration guide.

## See Also

- [workflow.schema.json](../workflow.schema.json) - Workflow validation schema
- [config.schema.json](../config.schema.json) - Main config validation schema
- [FABER Configuration Guide](../../docs/CONFIGURATION.md) - Complete configuration documentation
- [Plugin Extension Guide](../../docs/PLUGIN-EXTENSION.md) - Creating plugin-specific workflows
