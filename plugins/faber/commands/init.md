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

`.fractary/plugins/faber/config.json` with:

```json
{
  "workflows": [
    {
      "id": "default",
      "description": "Standard FABER workflow",
      "phases": { ... all 5 phases ... },
      "hooks": { ... 10 empty hook arrays ... },
      "autonomy": { "level": "guarded" }
    }
  ],
  "integrations": { ... },
  "logging": { ... },
  "safety": { ... }
}
```

## Implementation

This command should:
1. Check if config already exists (warn if exists)
2. Copy from `plugins/faber/config/faber.example.json`
3. Create `.fractary/plugins/faber/` directory if needed
4. Write config to `.fractary/plugins/faber/config.json`
5. Validate configuration
6. Report success with next steps

## After Init

After creating the config, customize it for your project:

1. **Validate**: `/fractary-faber:audit`
2. **Customize phase steps** for your tools (test framework, build system, etc.)
3. **Add hooks** for your existing scripts
4. **Configure autonomy level** for your workflow
5. **Test**: `/fractary-faber:run <work-id> --autonomy dry-run`

## See Also

- `/fractary-faber:audit` - Validate and get customization suggestions
- `/fractary-faber:run` - Execute workflow for a work item
- Example config: `plugins/faber/config/faber.example.json`
- Documentation: `plugins/faber/docs/CONFIGURATION.md`
