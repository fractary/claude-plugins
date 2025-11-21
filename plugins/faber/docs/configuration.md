# FABER Configuration Guide (v2.0)

Complete guide to configuring FABER workflow for your projects using the new JSON-based configuration.

## Table of Contents

- [Quick Start](#quick-start)
- [Configuration File Location](#configuration-file-location)
- [Configuration Structure](#configuration-structure)
- [Configuration Sections](#configuration-sections)

## Quick Start

### Option 1: Auto-Initialize (Recommended)

```bash
# Generate default FABER configuration
/fractary-faber:init

# This creates .fractary/plugins/faber/config.json with baseline workflow
```

### Option 2: Manual Configuration

```bash
# Copy example configuration
cp plugins/faber/config/faber.example.json .fractary/plugins/faber/config.json

# Customize for your project
vim .fractary/plugins/faber/config.json
```

### After Initialization

```bash
# Validate configuration
/fractary-faber:audit

# Customize workflows, phases, hooks for your project
# Then validate again
/fractary-faber:audit --verbose
```

## Configuration File Location

**New location (v2.0)**:
```
.fractary/plugins/faber/config.json
```

**Old location (v1.x) - NO LONGER USED**:
```
.faber.config.toml
```

The configuration uses JSON format and follows the standard Fractary plugin configuration pattern.

## Configuration Structure

**The baseline FABER workflow is issue-centric**:
- Core workflow: **Frame** → **Architect** → **Build** → **Evaluate** → **Release**
- Core artifacts: **Issue** + **Branch** + **Spec**

```json
{
  "$schema": "https://fractary.io/schemas/faber-config-v2.json",
  "schema_version": "2.0",
  "workflows": [
    {
      "id": "default",
      "description": "Standard FABER workflow",
      "phases": {
        "frame": { ... },
        "architect": { ... },
        "build": { ... },
        "evaluate": { ... },
        "release": { ... }
      },
      "hooks": {
        "pre_frame": [], "post_frame": [],
        "pre_architect": [], "post_architect": [],
        "pre_build": [], "post_build": [],
        "pre_evaluate": [], "post_evaluate": [],
        "pre_release": [], "post_release": []
      },
      "autonomy": { ... }
    }
  ],
  "integrations": { ... },
  "logging": { ... },
  "safety": { ... }
}
```

## Configuration Sections

### Workflows Array

Projects can define multiple workflows for different scenarios. The `/fractary-faber:init` command creates a baseline configuration with the **default** workflow.

#### ⚠️ Important: Always Keep the Default Workflow

**CRITICAL**: The default workflow should **ALWAYS be retained** even when adding custom workflows. Custom workflows are **added alongside** the default workflow, not as replacements.

**Example of correct configuration:**
```json
{
  "workflows": [
    {
      "id": "default",
      "description": "Standard feature development"
      // ... ALWAYS RETAINED as baseline workflow
    },
    {
      "id": "hotfix",
      "description": "Fast-track critical fixes"
      // ... custom workflow ADDED
    },
    {
      "id": "documentation",
      "description": "Docs-only changes"
      // ... another custom workflow ADDED
    }
  ]
}
```

**Why keep the default workflow?**
- ✅ Provides a working baseline for general development tasks
- ✅ Serves as fallback when custom workflows don't apply
- ✅ Acts as reference implementation for creating custom workflows
- ✅ Ensures FABER works out-of-the-box

**How to use multiple workflows:**
```bash
# Use default workflow (when --workflow not specified)
/fractary-faber:run 123

# Use specific custom workflow
/fractary-faber:run 456 --workflow hotfix
/fractary-faber:run 789 --workflow documentation
```

Each workflow defines its own phases, hooks, and autonomy level.

### Complete Example

See `plugins/faber/config/faber.example.json` for a complete configuration with:
- All 5 phases fully defined
- Phase-level hooks examples
- Safe autonomy defaults
- Plugin integrations

## Step Configuration

### Understanding `description` vs `prompt`

FABER v2.0 introduces a powerful distinction between documentation and execution instructions:

#### `description` Field
- **Purpose**: Human-readable documentation
- **What it explains**: What this step does (the "what")
- **Usage**: Appears in logs, audit reports, and documentation
- **Example**: `"Create semantic commit with conventional format"`

#### `prompt` Field
- **Purpose**: Execution instruction for Claude
- **What it explains**: How Claude should execute (the "how")
- **Usage**: Direct instruction when no skill present, or customization when skill present
- **Example**: `"Create commit using conventional commit format, link to issue, and include co-author attribution"`

### Execution Patterns

#### Pattern 1: Step with Skill Only
```json
{
  "name": "fetch-work",
  "description": "Fetch work item details from issue tracker",
  "skill": "fractary-work:issue-fetcher"
}
```
**Behavior**: Skill executes with default behavior. Description used for documentation.

#### Pattern 2: Step with Skill + Prompt
```json
{
  "name": "create-pr",
  "description": "Create pull request for review",
  "skill": "fractary-repo:pr-manager",
  "prompt": "Create PR with comprehensive summary, test plan, and FABER attribution"
}
```
**Behavior**: Skill executes with customized behavior based on prompt. Description used for documentation.

#### Pattern 3: Direct Claude Execution (No Skill)
```json
{
  "name": "implement",
  "description": "Implement solution from specification",
  "prompt": "Implement based on specification, following project code standards and best practices"
}
```
**Behavior**: Claude executes directly using prompt as instruction. Description used for documentation.

#### Pattern 4: Legacy (Description Only, No Skill)
```json
{
  "name": "test",
  "description": "Run automated tests"
}
```
**Behavior**: Claude executes using description as prompt (backward compatibility). Recommended to add explicit `prompt` field for clarity.

### When to Use Each Pattern

| Pattern | Use When | Benefits |
|---------|----------|----------|
| Skill Only | Standard plugin operation needed | Simple, maintainable, reusable |
| Skill + Prompt | Need to customize plugin behavior | Flexible without forking plugin |
| Prompt Only | Custom logic for this workflow | Full control, project-specific |
| Description Only | Legacy configs, simple cases | Backward compatible, minimal |

### Best Practices

1. **Always provide description** - Helps humans understand the workflow
2. **Add prompt for non-skill steps** - Makes execution intent explicit
3. **Use prompt to customize skills** - Avoid forking plugins for small changes
4. **Keep prompts concise** - Focus on execution details, not full instructions

## See Also

- [HOOKS.md](./HOOKS.md) - Complete guide to phase-level hooks
- [STATE-TRACKING.md](./STATE-TRACKING.md) - Dual-state tracking guide
- [MIGRATION-v2.md](./MIGRATION-v2.md) - Migration from v1.x to v2.0
- [architecture.md](./architecture.md) - FABER architecture overview
- Example config: `plugins/faber/config/faber.example.json`
