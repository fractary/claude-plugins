---
model: claude-haiku-4-5
---

# /fractary-faber:init

Initialize FABER workflow configuration for a project.

## What This Does

Creates `.fractary/plugins/faber/config.json` with the baseline FABER workflow configuration.

**The baseline FABER workflow is issue-centric**:
- **Frame**: Fetch issue, classify work, create branch
- **Architect**: Generate specification document
- **Build**: Implement solution, commit changes
- **Evaluate**: Run tests, perform review
- **Release**: Create PR, merge, deploy

**Core artifacts**: Issue + Branch + Spec

**Features**:
- 📝 Creates default "workflows" array with standard workflow
- ⚙️ Configures all 5 FABER phases with basic steps
- 🪝 Sets up 10 hook arrays (empty, ready for customization)
- 🔒 Configures safe defaults (autonomy: guarded)
- 🔌 Sets up plugin integrations (work, repo, spec, logs)
- ✅ Validates configuration after creation

## Usage

```bash
# Generate default FABER configuration
/fractary-faber:init

# Dry-run (show what would be created without creating)
/fractary-faber:init --dry-run
```

## What Gets Created

**Directory structure**:
```
.fractary/plugins/faber/
├── config.json              # Main configuration (references workflows)
└── workflows/               # Workflow definition files
    └── default.json         # Standard FABER workflow
```

**Config file** (`.fractary/plugins/faber/config.json`):

```json
{
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

**Workflow files** contain the complete phase definitions, hooks, and autonomy settings.

## Implementation

This command should:
1. Check if config already exists (warn if exists, offer to backup)
2. Create `.fractary/plugins/faber/` directory if needed
3. Create `.fractary/plugins/faber/workflows/` directory
4. Copy workflow template:
   - `plugins/faber/config/workflows/default.json` → `.fractary/plugins/faber/workflows/default.json`
5. Copy config template:
   - `plugins/faber/config/faber.example.json` → `.fractary/plugins/faber/config.json`
6. Validate configuration (including workflow file references)
7. Report success with next steps and file locations

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
- Example config: `plugins/faber/config/faber.example.json`
- Documentation: `plugins/faber/docs/CONFIGURATION.md`
