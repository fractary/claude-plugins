---
model: claude-haiku-4-5
---

# /fractary-faber:init

Initialize FABER workflow configuration for a project.

## What This Does

Creates the complete FABER runtime environment with run isolation and event logging support.

**The baseline FABER workflow is issue-centric**:
- **Frame**: Fetch issue, classify work, create branch
- **Architect**: Generate specification document
- **Build**: Implement solution, commit changes
- **Evaluate**: Run tests, perform review
- **Release**: Create PR, merge, deploy

**Core artifacts**: Issue + Branch + Spec + Run Events

**Features**:
- 📝 Creates default "workflows" array with standard workflow
- ⚙️ Configures all 5 FABER phases with basic steps
- 🪝 Sets up 10 hook arrays (empty, ready for customization)
- 🔒 Configures safe defaults (autonomy: guarded)
- 🔌 Sets up plugin integrations (work, repo, spec, logs)
- 🆔 Initializes Run ID system for per-run isolation
- 📊 Configures Event Gateway for workflow logging
- ✅ Validates configuration after creation

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
├── config.json              # Main configuration (references workflows)
├── gateway.json             # Event Gateway configuration
├── workflows/               # Workflow definition files
│   └── default.json         # Standard FABER workflow
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
  "schema_version": "2.1",
  "workflows": [
    {
      "id": "default",
      "file": "./workflows/default.json",
      "description": "Standard FABER workflow"
    }
  ],
  "integrations": { ... },
  "logging": { ... },
  "safety": { ... }
}
```

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

**Workflow files** contain the complete phase definitions, hooks, and autonomy settings.

## Implementation

This command should:
1. Check if config already exists
   - If `--force` flag: create backup, proceed with overwrite
   - Otherwise: create backup, then proceed (always upgrades to latest)
2. Create `.fractary/plugins/faber/` directory if needed
3. Create `.fractary/plugins/faber/workflows/` directory
4. Create `.fractary/plugins/faber/runs/` directory (for Run ID system)
5. Copy workflow template:
   - `plugins/faber/config/workflows/default.json` → `.fractary/plugins/faber/workflows/default.json`
6. Copy config template:
   - `plugins/faber/config/faber.example.json` → `.fractary/plugins/faber/config.json`
7. Copy gateway template:
   - `plugins/faber/gateway/config.template.json` → `.fractary/plugins/faber/gateway.json`
8. Validate configuration (including workflow file references)
9. Report success with next steps and file locations

## After Init

After creating the config, customize it for your project:

1. **Validate**: `/fractary-faber:audit`
2. **Customize workflows**: Edit `.fractary/plugins/faber/workflows/default.json`
   - Modify phase steps for your tools (test framework, build system, etc.)
   - Add hooks for your existing scripts
   - Adjust autonomy level for your workflow
3. **Add custom workflows**: Copy and customize templates for specific scenarios
4. **Reference custom workflows**: Add them to `config.json` workflows array
5. **Test**: `/fractary-faber:run <work-id> --autonomy dry-run`

## See Also

- `/fractary-faber:audit` - Validate and get customization suggestions
- `/fractary-faber:run` - Execute workflow for a work item
- `/fractary-faber:run --resume <run-id>` - Resume a failed/paused run
- `/fractary-faber:run --rerun <run-id>` - Re-run with different parameters
- `/fractary-faber:status` - View current and past run status
- Example config: `plugins/faber/config/faber.example.json`
- Documentation: `plugins/faber/docs/CONFIGURATION.md`
- Run ID System: `plugins/faber/docs/RUN-ID-SYSTEM.md`
