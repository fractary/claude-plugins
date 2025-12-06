---
name: fractary-faber:init
description: Initialize FABER workflow configuration for a project
model: claude-haiku-4-5
---

# /fractary-faber:init

Initialize FABER workflow configuration for a project.

## What This Does

Creates a minimal FABER configuration that references the default workflow from the plugin.
With workflow inheritance (v2.2+), projects no longer need to copy workflow files - they simply
reference `fractary-faber:default` and optionally extend it with customizations.

**The default FABER workflow (`fractary-faber:default`) is issue-centric**:
- **Frame**: Fetch/create issue, checkout/create branch
- **Architect**: Generate specification document
- **Build**: Implement solution, commit and push changes
- **Evaluate**: Issue review, commit fixes, create PR, review CI checks
- **Release**: Merge PR and cleanup

**Core artifacts**: Issue + Branch + Spec + PR

**Features**:
- 📝 Creates minimal config referencing `fractary-faber:default`
- 🔒 Configures safe defaults (autonomy: guarded)
- 🔌 Sets up plugin integrations (work, repo, spec, logs)
- 🆔 Initializes Run ID system for per-run isolation
- 📊 Configures Event Gateway for workflow logging
- ✅ Validates configuration after creation
- 🧬 Optional: Create custom workflow that extends default

## Usage

```bash
# Generate default FABER configuration
/fractary-faber:init

# Dry-run (show what would be created without creating)
/fractary-faber:init --dry-run

# Force overwrite existing config (creates backup)
/fractary-faber:init --force
```

## What Gets Created

**Directory structure**:
```
.fractary/plugins/faber/
├── config.json              # Main configuration (references default workflow)
├── gateway.json             # Event Gateway configuration
├── workflows/               # Project-specific workflow extensions (optional)
└── runs/                    # Per-run storage (created on first run)
    └── {org}/
        └── {project}/
            └── {uuid}/      # Individual run directories
                ├── state.json
                ├── metadata.json
                └── events/
```

**Config file** (`.fractary/plugins/faber/config.json`):

```json
{
  "$schema": "https://raw.githubusercontent.com/fractary/claude-plugins/main/plugins/faber/config/config.schema.json",
  "schema_version": "2.2",
  "default_workflow": "fractary-faber:default",
  "workflows": [],
  "integrations": {
    "work_plugin": "fractary-work",
    "repo_plugin": "fractary-repo",
    "spec_plugin": "fractary-spec",
    "logs_plugin": "fractary-logs",
    "docs_plugin": "fractary-docs"
  },
  "logging": {
    "use_logs_plugin": true,
    "log_level": "info"
  },
  "safety": {
    "protected_paths": [".env", "credentials.json"],
    "require_confirm_for": ["delete", "deploy"]
  }
}
```

**Key change in v2.2**: The `workflows` array is **empty by default**. The config references
`fractary-faber:default` via `default_workflow`. This eliminates workflow drift - updates to
the default workflow in the plugin automatically apply to all projects.

**Gateway config** (`.fractary/plugins/faber/gateway.json`):

```json
{
  "version": "1.0",
  "backends": {
    "local_files": { "enabled": true, "config": { "base_path": ".fractary/plugins/faber/runs" } },
    "s3_archive": { "enabled": false, "config": { ... } }
  },
  "event_retention": { "local_days": 30, "archive_days": 365 }
}
```

## Implementation

This command should:
1. Check if config already exists
   - If `--force` flag: create backup, proceed with overwrite
   - Otherwise: create backup, then proceed (always upgrades to latest)
2. Create `.fractary/plugins/faber/` directory if needed
3. Create `.fractary/plugins/faber/workflows/` directory (empty, for project extensions)
4. Create `.fractary/plugins/faber/runs/` directory (for Run ID system)
5. Generate config file (NOT copy - generate from template):
   - Create `.fractary/plugins/faber/config.json` with default_workflow="fractary-faber:default"
   - Empty workflows array (project doesn't define workflows, uses default)
6. Copy gateway template:
   - `plugins/faber/gateway/config.template.json` → `.fractary/plugins/faber/gateway.json`
7. Validate configuration (including resolving default_workflow)
8. Report success with next steps

**Important**: No workflow files are copied. The project uses `fractary-faber:default` directly
from the installed plugin. This ensures automatic updates and eliminates drift.

## After Init

After creating the config, optionally customize it for your project:

1. **Validate**: `/fractary-faber:audit`
2. **Use as-is**: The default workflow (`fractary-faber:default`) works out of the box
3. **Test**: `/fractary-faber:run <work-id> --autonomy dry-run`

### Customizing (Optional)

**To extend the default workflow with project-specific steps:**

1. Create a custom workflow file: `.fractary/plugins/faber/workflows/my-project.json`
```json
{
  "$schema": "../../../.claude/plugins/marketplaces/fractary/plugins/faber/config/workflow.schema.json",
  "id": "my-project",
  "description": "My project workflow extending FABER defaults",
  "extends": "fractary-faber:default",
  "skip_steps": [],
  "phases": {
    "frame": { "enabled": true, "pre_steps": [], "steps": [], "post_steps": [] },
    "architect": { "enabled": true, "pre_steps": [], "steps": [], "post_steps": [] },
    "build": {
      "enabled": true,
      "pre_steps": [],
      "steps": [
        {
          "id": "my-lint-check",
          "name": "Run Linter",
          "description": "Run project-specific linter before implementation",
          "prompt": "Run npm run lint and fix any issues"
        }
      ],
      "post_steps": []
    },
    "evaluate": { "enabled": true, "pre_steps": [], "steps": [], "post_steps": [] },
    "release": { "enabled": true, "pre_steps": [], "steps": [], "post_steps": [] }
  },
  "autonomy": { "level": "guarded", "require_approval_for": ["release"] }
}
```

2. Reference it in config.json:
```json
{
  "default_workflow": "my-project",
  "workflows": [
    { "id": "my-project", "file": "./workflows/my-project.json" }
  ]
}
```

**To skip specific default steps:**
```json
{
  "extends": "fractary-faber:default",
  "skip_steps": ["merge-pr", "review-pr-checks"]
}
```

## See Also

- `/fractary-faber:audit` - Validate and get customization suggestions
- `/fractary-faber:run` - Execute workflow for a work item
- `/fractary-faber:run --resume <run-id>` - Resume a failed/paused run
- `/fractary-faber:run --rerun <run-id>` - Re-run with different parameters
- `/fractary-faber:status` - View current and past run status
- Example config: `plugins/faber/config/faber.example.json`
- Documentation: `plugins/faber/docs/CONFIGURATION.md`
- Run ID System: `plugins/faber/docs/RUN-ID-SYSTEM.md`
