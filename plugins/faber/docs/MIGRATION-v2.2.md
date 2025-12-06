# Migration Guide: FABER v2.1 → v2.2

This guide helps projects migrate from FABER v2.1 (automatic primitives) to v2.2 (workflow inheritance).

## Table of Contents

- [Overview](#overview)
- [What Changed](#what-changed)
- [Migration Checklist](#migration-checklist)
- [Breaking Changes](#breaking-changes)
- [Examples](#examples)

## Overview

FABER v2.2 introduces **workflow inheritance** which fundamentally changes how workflows are configured:

- **Workflows can extend other workflows** via the `extends` field
- **Pre/post steps replace automatic primitives** - all operations are now explicit steps
- **Hooks are deprecated** - use `pre_steps` and `post_steps` instead
- **Default workflow stays in plugin** - projects reference it, not copy it

This change:
- **Eliminates workflow drift** - updates to default workflow apply to all projects
- **Enables customization without duplication** - extend and override specific steps
- **Increases transparency** - all operations visible in workflow definition
- **Simplifies maintenance** - single source of truth for default behavior

## What Changed

### Architecture Changes

**v2.1 (Automatic Primitives)**:
```
config.json
└── workflows/
    └── default.json (copy of plugin default)
        ├── Frame: minimal steps + automatic issue fetch
        ├── Architect: steps + automatic classification
        ├── Build: steps + automatic branch creation
        ├── Evaluate: steps + automatic issue review
        └── Release: steps + automatic PR creation
```

**v2.2 (Workflow Inheritance)**:
```
config.json
├── default_workflow: "fractary-faber:default"  (reference, not copy)
└── workflows/
    └── my-project.json (optional, extends default)
        └── extends: "fractary-faber:default"
            ├── skip_steps: ["merge-pr"]
            └── phases with pre_steps, steps, post_steps
```

### Key Changes

| v2.1 | v2.2 |
|------|------|
| Copy default.json to project | Reference fractary-faber:default |
| Automatic primitives in manager | Explicit steps in workflow |
| Hooks for pre/post actions | pre_steps and post_steps in phases |
| Hardcoded step order | Configurable inheritance chain |
| Can't skip built-in steps | skip_steps to exclude any step |

## Migration Checklist

### For Projects Using Default Workflow Only

If you're using the default workflow without modifications:

1. **Update config.json**:
   ```json
   {
     "schema_version": "2.2",
     "default_workflow": "fractary-faber:default",
     "workflows": []
   }
   ```

2. **Delete local workflow copy** (if present):
   ```bash
   rm .fractary/plugins/faber/workflows/default.json
   ```

3. **Done!** The plugin's default workflow will be used directly.

### For Projects with Custom Workflows

If you've customized the workflow:

1. **Create extension workflow**:
   ```json
   {
     "$schema": "../workflow.schema.json",
     "id": "my-project",
     "extends": "fractary-faber:default",
     "skip_steps": [],
     "phases": {
       "frame": { "enabled": true, "pre_steps": [], "steps": [], "post_steps": [] },
       "architect": { "enabled": true, "pre_steps": [], "steps": [], "post_steps": [] },
       "build": { "enabled": true, "pre_steps": [], "steps": [], "post_steps": [] },
       "evaluate": { "enabled": true, "pre_steps": [], "steps": [], "post_steps": [] },
       "release": { "enabled": true, "pre_steps": [], "steps": [], "post_steps": [] }
     },
     "autonomy": { "level": "guarded", "require_approval_for": ["release"] }
   }
   ```

2. **Move custom steps to appropriate position**:
   - Steps that ran before a phase → put in `pre_steps` of that phase
   - Steps that ran after a phase → put in `post_steps` of that phase
   - Steps that replace default behavior → put in `steps` and add default step ID to `skip_steps`

3. **Convert hooks to pre/post steps**:

   **Before (v2.1 hooks)**:
   ```json
   {
     "hooks": {
       "pre_build": [
         { "type": "script", "name": "lint", "path": "./scripts/lint.sh" }
       ]
     }
   }
   ```

   **After (v2.2 pre_steps)**:
   ```json
   {
     "phases": {
       "build": {
         "pre_steps": [
           { "id": "lint", "name": "Lint Check", "prompt": "Run ./scripts/lint.sh" }
         ]
       }
     }
   }
   ```

4. **Update config.json**:
   ```json
   {
     "schema_version": "2.2",
     "default_workflow": "my-project",
     "workflows": [
       { "id": "my-project", "file": "./workflows/my-project.json" }
     ]
   }
   ```

### For Projects with Multiple Workflows

If you have multiple custom workflows:

1. Identify which workflows should extend the default
2. Create inheritance chains (e.g., `my-hotfix` extends `my-project` extends `fractary-faber:default`)
3. Deduplicate steps that were copied across workflows
4. Use `skip_steps` to exclude inherited steps where needed

## Breaking Changes

### 1. Automatic Primitives Removed

**v2.1**: Issue fetch, branch creation, PR creation happened automatically.

**v2.2**: These are now explicit steps in the default workflow:
- `fetch-or-create-issue` (Frame)
- `switch-or-create-branch` (Frame)
- `create-pr` (Evaluate)
- `merge-pr` (Release)

**Migration**: If using default workflow, no action needed. If custom workflow, ensure these steps exist or extend from default.

### 2. Hooks Deprecated

**v2.1**: Used `hooks.pre_build`, `hooks.post_build`, etc.

**v2.2**: Use `pre_steps` and `post_steps` in phase definitions.

**Migration**: Convert all hooks to steps. See conversion examples above.

### 3. Schema Version

**v2.1**: `"schema_version": "2.1"`

**v2.2**: `"schema_version": "2.2"`

**Migration**: Update schema_version in config.json.

### 4. Workflow File Location

**v2.1**: Workflow files copied to `.fractary/plugins/faber/workflows/`

**v2.2**: Plugin workflows accessed via namespace (e.g., `fractary-faber:default`)

**Migration**: Remove copied workflow files, use namespace references.

## Examples

### Example 1: Minimal Migration (Default Workflow)

**Before (v2.1)**:
```json
{
  "schema_version": "2.1",
  "workflows": [
    { "id": "default", "file": "./workflows/default.json" }
  ],
  "integrations": { ... }
}
```

**After (v2.2)**:
```json
{
  "schema_version": "2.2",
  "default_workflow": "fractary-faber:default",
  "workflows": [],
  "integrations": { ... }
}
```

### Example 2: Custom Workflow with Additional Steps

**Before (v2.1)**:
```json
{
  "phases": {
    "build": {
      "steps": [
        { "name": "lint", "prompt": "Run linter" },
        { "name": "implement", "prompt": "Implement solution" },
        { "name": "commit", "skill": "fractary-repo:commit-creator" }
      ]
    }
  }
}
```

**After (v2.2)**:
```json
{
  "extends": "fractary-faber:default",
  "phases": {
    "build": {
      "pre_steps": [
        { "id": "lint", "name": "Lint Check", "prompt": "Run linter" }
      ],
      "steps": [],
      "post_steps": []
    }
  }
}
```

(The `implement` and `commit` steps are inherited from default.)

### Example 3: Skipping Default Steps

**To skip PR merge (maybe you want manual merge)**:
```json
{
  "extends": "fractary-faber:default",
  "skip_steps": ["merge-pr"],
  "phases": { ... }
}
```

### Example 4: Converting Hooks

**Before (v2.1)**:
```json
{
  "hooks": {
    "post_evaluate": [
      {
        "type": "skill",
        "name": "notify-slack",
        "skill": "my-plugin:slack-notifier"
      }
    ]
  }
}
```

**After (v2.2)**:
```json
{
  "extends": "fractary-faber:default",
  "phases": {
    "evaluate": {
      "post_steps": [
        {
          "id": "notify-slack",
          "name": "Notify Slack",
          "skill": "my-plugin:slack-notifier"
        }
      ]
    }
  }
}
```

## Validation

After migration, validate your configuration:

```bash
/fractary-faber:audit --verbose
```

The audit command will check:
- Schema version compatibility
- Workflow reference resolution
- Step ID uniqueness
- Deprecated hook usage (warnings)

## FAQ

### Q: Can I still copy the default workflow to my project?

Yes, but it's not recommended. If you copy, you won't receive updates when the default workflow is improved. Instead, use `extends` to inherit and customize.

### Q: What happens to existing state files?

State files remain compatible. The v2.2 manager can read v2.1 state and will write v2.2 format.

### Q: Can I mix v2.1 and v2.2 workflows?

No. Once you migrate config.json to v2.2, all workflow references must use the new format.

### Q: How do I debug workflow inheritance?

Use the `resolve-workflow` operation in faber-config skill:
```
Invoke Skill: faber-config
Operation: resolve-workflow
Parameters: workflow_id="my-project"
```

This shows the fully merged workflow with inheritance chain.

## See Also

- [CONFIGURATION.md](./CONFIGURATION.md) - Complete configuration reference
- [Workflow Schema](../config/workflow.schema.json) - JSON Schema for workflows
- [Default Workflow](../config/workflows/default.json) - Plugin default workflow
