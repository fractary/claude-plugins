# faber-cloud Workflow Templates

This directory contains workflow templates for the faber-cloud plugin. These templates define complete infrastructure lifecycle workflows that are copied to projects during initialization.

## Overview

Workflows are stored as separate JSON files instead of being embedded in configuration. This provides:

- **Better maintainability**: Each workflow in its own file
- **Easier version control**: Fewer merge conflicts
- **Clear separation**: Infrastructure workflows separate from cloud-specific workflows
- **Plugin extensibility**: Domain plugins provide specialized workflows

## Available Workflows

### infrastructure-deploy.json
**Purpose**: Standard infrastructure deployment workflow

**Use case**: New infrastructure, updates to existing infrastructure, infrastructure migrations

**Phases**:
- **Frame**: Fetch work item, classify change type, create infrastructure branch
- **Architect**: Design architecture, analyze requirements, estimate costs
- **Build**: Generate Terraform code, configure backend, commit changes
- **Evaluate**: Validate configuration, run security scans, check compliance, review costs
- **Release**: Generate plan, review changes, deploy infrastructure, verify deployment, create PR

**Autonomy**: Guarded (pauses before deployment for approval)

**When to use**:
- Deploying new infrastructure components
- Updating existing infrastructure
- Migrating infrastructure between providers
- Implementing infrastructure changes from work items

**Example**:
```bash
/fractary-faber-cloud:manage 123 --workflow infrastructure-deploy
```

---

### infrastructure-audit.json
**Purpose**: Non-destructive infrastructure audit and compliance checking

**Use case**: Regular infrastructure health checks, security audits, compliance verification, cost optimization

**Phases**:
- **Frame**: Identify environment and audit scope
- **Architect**: Disabled (no changes)
- **Build**: Disabled (no changes)
- **Evaluate**: Configuration audit, drift detection, security scan, cost analysis, IAM health check, compliance verification
- **Release**: Generate audit report, prioritize findings, create remediation issues, commit report

**Autonomy**: Autonomous (fully automated, non-destructive)

**When to use**:
- Regular scheduled infrastructure audits
- Pre-deployment compliance checks
- Security posture assessments
- Cost optimization reviews
- Drift detection and remediation planning

**Example**:
```bash
/fractary-faber-cloud:manage 456 --workflow infrastructure-audit
```

---

### infrastructure-teardown.json
**Purpose**: Safe infrastructure destruction with backup and verification

**Use case**: Decommissioning infrastructure, environment cleanup, cost reduction

**Phases**:
- **Frame**: Identify resources to destroy, confirm intent
- **Architect**: Analyze dependencies, plan data backup, estimate savings
- **Build**: Generate destroy plan, create backup scripts, document procedure
- **Evaluate**: Review plan, execute backups, verify backups, final safety check
- **Release**: Confirm destruction, execute teardown, verify destruction, cleanup artifacts, document completion

**Autonomy**: Assist (requires approval at each major step)

**When to use**:
- Decommissioning test/staging environments
- Removing unused infrastructure
- Cost reduction initiatives
- Environment migrations (destroy old after new validated)

**⚠️ CRITICAL**: This workflow is DESTRUCTIVE. Always:
- Verify correct environment (not production without explicit approval)
- Execute data backups before destruction
- Review destroy plan carefully
- Have rollback plan ready

**Example**:
```bash
/fractary-faber-cloud:manage 789 --workflow infrastructure-teardown
```

---

## Workflow File Structure

Each workflow file follows the workflow.schema.json structure:

```json
{
  "$schema": "../../../faber/config/workflow.schema.json",
  "id": "workflow-name",
  "description": "Workflow description",
  "phases": {
    "frame": { ... },
    "architect": { ... },
    "build": { ... },
    "evaluate": { ... },
    "release": { ... }
  },
  "hooks": {
    "pre_frame": [],
    "post_frame": [],
    "pre_architect": [],
    "post_architect": [],
    "pre_build": [],
    "post_build": [],
    "pre_evaluate": [],
    "post_evaluate": [],
    "pre_release": [],
    "post_release": []
  },
  "autonomy": {
    "level": "guarded|assist|autonomous|dry-run",
    "pause_before_release": true|false,
    "require_approval_for": [...],
    "overrides": {}
  }
}
```

## Using Workflows

### In Config File

Workflows are referenced in `.fractary/plugins/faber-cloud/config.json`:

```json
{
  "workflows": [
    {
      "id": "infrastructure-deploy",
      "file": "./workflows/infrastructure-deploy.json",
      "description": "Standard infrastructure deployment"
    },
    {
      "id": "infrastructure-audit",
      "file": "./workflows/infrastructure-audit.json",
      "description": "Non-destructive infrastructure audit"
    },
    {
      "id": "infrastructure-teardown",
      "file": "./workflows/infrastructure-teardown.json",
      "description": "Safe infrastructure destruction"
    }
  ]
}
```

### Selecting Workflow

```bash
# Use default workflow (infrastructure-deploy)
/fractary-faber-cloud:manage 123

# Use specific workflow
/fractary-faber-cloud:manage 456 --workflow infrastructure-audit
/fractary-faber-cloud:manage 789 --workflow infrastructure-teardown

# Use workflow with specific phase
/fractary-faber-cloud:architect 123 --workflow infrastructure-deploy
```

## Creating Custom Workflows

### 1. Copy a Template

```bash
cp .fractary/plugins/faber-cloud/workflows/infrastructure-deploy.json \
   .fractary/plugins/faber-cloud/workflows/my-custom-workflow.json
```

### 2. Edit Workflow

Modify phases, steps, hooks, and autonomy settings:

```json
{
  "$schema": "../../../faber/config/workflow.schema.json",
  "id": "my-custom-workflow",
  "description": "Custom infrastructure workflow for specific use case",
  "phases": {
    "frame": {
      "enabled": true,
      "steps": [
        // Custom steps
      ]
    }
    // ... other phases
  }
}
```

### 3. Add Reference to Config

Add workflow reference to `.fractary/plugins/faber-cloud/config.json`:

```json
{
  "workflows": [
    {
      "id": "my-custom-workflow",
      "file": "./workflows/my-custom-workflow.json",
      "description": "My custom workflow description"
    }
  ]
}
```

### 4. Validate

```bash
/fractary-faber-cloud:status
```

## Workflow Customization

### Common Customizations

**1. Skip Phases**:
```json
{
  "phases": {
    "architect": {
      "enabled": false  // Skip architecture phase
    }
  }
}
```

**2. Add Custom Steps**:
```json
{
  "phases": {
    "evaluate": {
      "steps": [
        {
          "name": "custom-validation",
          "description": "Run custom validation",
          "prompt": "Execute custom validation logic here"
        }
      ]
    }
  }
}
```

**3. Add Hooks**:
```json
{
  "hooks": {
    "pre_release": [
      {
        "type": "script",
        "name": "custom-check",
        "path": "./scripts/custom-pre-release.sh",
        "description": "Custom pre-release validation"
      }
    ]
  }
}
```

**4. Adjust Autonomy**:
```json
{
  "autonomy": {
    "level": "dry-run",  // Test without making changes
    "pause_before_release": true,
    "require_approval_for": ["evaluate", "release"]
  }
}
```

**5. Environment-Specific Overrides**:
```json
{
  "autonomy": {
    "overrides": {
      "production": {
        "level": "assist",
        "require_approval_for": ["architect", "build", "evaluate", "release"]
      }
    }
  }
}
```

## Best Practices

1. **Always keep default workflows**: Custom workflows should be **added alongside** defaults, not replace them

2. **Test with dry-run**: Use `autonomy.level: "dry-run"` when testing new workflows

3. **Document custom workflows**: Add clear descriptions and usage notes

4. **Version control workflows**: Commit workflow files to repository for team sharing

5. **Validate regularly**: Run status checks after workflow modifications

6. **Use environment overrides**: Set stricter autonomy for production environments

7. **Leverage hooks**: Use hooks for project-specific validations and notifications

## Troubleshooting

**Workflow not found**:
- Check workflow ID matches reference in config.json
- Verify workflow file exists at specified path
- Validate JSON syntax

**Validation errors**:
- Ensure workflow follows workflow.schema.json structure
- Check all required fields present (id, phases, autonomy)
- Verify phase structure (enabled, steps)

**Skill not found**:
- Verify skill name format: `plugin:skill-name`
- Check skill exists in faber-cloud or referenced plugin
- Ensure plugin is installed and configured

## See Also

- [FABER Configuration Guide](../../../faber/docs/CONFIGURATION.md) - Complete configuration documentation
- [Plugin Extension Guide](../../../faber/docs/PLUGIN-EXTENSION-GUIDE.md) - Creating custom plugins
- [faber-cloud User Guide](../../docs/guides/user-guide.md) - Complete usage guide
- [Workflow Schema](../../../faber/config/workflow.schema.json) - Workflow validation schema
