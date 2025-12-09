# FABER Configuration Guide (v2.1)

Complete guide to configuring FABER workflow for your projects using the new JSON-based configuration.

## Table of Contents

- [Quick Start](#quick-start)
- [Configuration File Location](#configuration-file-location)
- [Workflow Resolution Order](#workflow-resolution-order)
- [Configuration Structure](#configuration-structure)
- [Configuration Sections](#configuration-sections)
- [Plan and Run Artifacts](#plan-and-run-artifacts)

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

**Directory structure (v2.0)**:
```
.fractary/plugins/faber/
|-- config.json              # Main configuration (references workflows)
|-- workflows/               # Workflow definition files
    |-- default.json         # Standard FABER workflow
    |-- hotfix.json          # Expedited hotfix workflow
    |-- custom.json          # Your custom workflows
```

**Old location (v1.x) - NO LONGER USED**:
```
.faber.config.toml
```

The configuration uses JSON format and follows the standard Fractary plugin configuration pattern. Workflows are now stored as separate files (referenced by config.json) instead of being embedded inline.

## Workflow Resolution Order

When FABER resolves a workflow, it searches in a specific order. Understanding this helps when customizing workflows.

### Resolution Precedence (Highest to Lowest)

1. **Project Workflows** (`.fractary/plugins/faber/workflows/`)
   - Workflows defined in your project's `.fractary/` directory
   - Use `project:` namespace prefix (or no prefix)
   - Example: `project:custom-workflow` or just `custom-workflow`

2. **Plugin-Provided Workflows** (installed plugin cache)
   - Workflows shipped with the FABER plugin
   - Use `fractary-faber:` namespace prefix
   - Example: `fractary-faber:default`, `fractary-faber:core`
   - Located in: `~/.claude/plugins/cache/fractary/fractary-faber/{version}/config/workflows/`

3. **Built-in Defaults**
   - Hardcoded fallback workflows
   - Only used if no other workflows found

### Namespace Prefixes

| Prefix | Source | Example |
|--------|--------|---------|
| `fractary-faber:` | Plugin installation | `fractary-faber:default` |
| `project:` | Project `.fractary/` | `project:my-workflow` |
| (none) | Searches project first, then plugin | `default` |

### How Resolution Works

When you specify `--workflow my-workflow`:

```
1. Check: .fractary/plugins/faber/workflows/my-workflow.json
   - If found: Use it (project workflow)
   - If not found: Continue

2. Check: ~/.claude/plugins/.../workflows/my-workflow.json
   - If found: Use it (plugin workflow)
   - If not found: Continue

3. Check: Built-in defaults
   - If matches known ID: Use it
   - If not found: Error
```

### Workflow Inheritance

Workflows can extend other workflows using the `extends` field:

```json
{
  "id": "hotfix",
  "extends": "fractary-faber:default",
  "description": "Fast-track workflow for critical fixes",
  "phases": {
    "architect": {
      "enabled": false
    }
  }
}
```

The inheritance chain is resolved in order:
1. Start with the base workflow (`fractary-faber:default`)
2. Apply each extension's overrides
3. Result is a fully merged workflow

**Example inheritance chain**:
```
fractary-faber:core (base primitives)
    |
    +-- fractary-faber:default (adds spec generation, implementation)
        |
        +-- project:hotfix (disables architect phase)
```

### Best Practices

1. **Use plugin workflows as-is** for standard development
2. **Extend plugin workflows** rather than copying them
3. **Use `fractary-faber:` prefix** when explicitly referencing plugin workflows
4. **Keep project workflows in `.fractary/`** for version control

## Configuration Structure

**The baseline FABER workflow is issue-centric**:
- Core workflow: **Frame** -> **Architect** -> **Build** -> **Evaluate** -> **Release**
- Core artifacts: **Issue** + **Branch** + **Spec**

### Plugin-Provided Workflows

The FABER plugin provides two centrally-maintained workflows that most projects will use or extend:

| Workflow | Namespace | Purpose |
|----------|-----------|---------|
| `fractary-faber:core` | Plugin | Base primitives: issue management, branching, PR lifecycle |
| `fractary-faber:default` | Plugin | Standard software dev workflow (extends `core` + spec generation + implementation) |

**`fractary-faber:core`** contains only the essential primitives:
- **Frame**: Fetch/create issue, create/switch branch
- **Build** (post): Commit and push
- **Evaluate**: Issue review, commit fixes, create PR, review CI checks
- **Release**: Merge PR

**`fractary-faber:default`** extends `core` and adds:
- **Architect**: Generate specification from issue
- **Build**: Implement solution based on spec

These workflows are maintained in the plugin source code and update automatically when the plugin is updated. Projects reference them via the `fractary-faber:` namespace prefix.

**For most projects**: Simply run `/fractary-faber:init` and use the default workflow as-is. The config will reference `fractary-faber:default` which provides a complete software development workflow.

**For custom needs**: Create project-specific workflows in `.fractary/plugins/faber/workflows/` that extend either `fractary-faber:core` or `fractary-faber:default`.

### Main Configuration File (config.json)

The main configuration file references workflows stored in separate files:

```json
{
  "$schema": "https://fractary.io/schemas/faber-config-v2.json",
  "schema_version": "2.0",
  "workflows": [
    {
      "id": "default",
      "file": "./workflows/default.json",
      "description": "Standard FABER workflow"
    },
    {
      "id": "hotfix",
      "file": "./workflows/hotfix.json",
      "description": "Expedited workflow for critical fixes"
    }
  ],
  "integrations": { ... },
  "logging": { ... },
  "safety": { ... }
}
```

### Workflow Files (workflows/*.json)

Each workflow file contains the complete phase definitions, hooks, and autonomy settings:

```json
{
  "$schema": "../workflow.schema.json",
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
```

**Benefits of separate workflow files**:
- **Maintainability**: Each workflow in its own file (easier to edit)
- **Version control**: Fewer merge conflicts
- **Reusability**: Share workflows across projects
- **Plugin extensibility**: Specialized plugins provide workflow templates

## Configuration Sections

### Workflows Array

Projects can define multiple workflows for different scenarios. The `/fractary-faber:init` command creates workflow templates and references them in config.json.

#### Important: Always Keep the Default Workflow

**CRITICAL**: The default workflow should **ALWAYS be retained** even when adding custom workflows. Custom workflows are **added alongside** the default workflow, not as replacements.

**Example of correct configuration:**
```json
{
  "workflows": [
    {
      "id": "default",
      "file": "./workflows/default.json",
      "description": "Standard feature development"
      // ALWAYS RETAINED as baseline workflow
    },
    {
      "id": "hotfix",
      "file": "./workflows/hotfix.json",
      "description": "Fast-track critical fixes"
      // custom workflow ADDED
    },
    {
      "id": "documentation",
      "file": "./workflows/documentation.json",
      "description": "Docs-only changes"
      // another custom workflow ADDED
    }
  ]
}
```

**Creating custom workflows:**
```bash
# Copy a template as starting point
cp .fractary/plugins/faber/workflows/default.json .fractary/plugins/faber/workflows/documentation.json

# Edit the new workflow file
vim .fractary/plugins/faber/workflows/documentation.json

# Add reference to config.json workflows array
# Then validate
/fractary-faber:audit
```

**Why keep the default workflow?**
- Provides a working baseline for general development tasks
- Serves as fallback when custom workflows don't apply
- Acts as reference implementation for creating custom workflows
- Ensures FABER works out-of-the-box

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

### Step Identification (id vs name)

FABER v2.1 introduces a required `id` field for step identification. This enables:
- **Step targeting**: Run specific steps via `--step build:implement`
- **Logging**: Clear identification in event logs
- **State tracking**: Precise step status in state.json
- **Uniqueness validation**: Catch duplicate step IDs during config validation

#### Step Schema

```json
{
  "id": "implement",
  "name": "Implement Solution",
  "description": "Implement solution from specification",
  "skill": "fractary-spec:spec-generator"
}
```

| Field | Required | Purpose |
|-------|----------|---------|
| `id` | Yes* | Unique identifier for targeting, logging, state tracking |
| `name` | No | Human-readable display name (defaults to `id` if omitted) |
| `description` | Conditional | Documentation (what the step does) |
| `prompt` | Conditional | Execution instruction (how to do it) |
| `skill` | Conditional | Skill to invoke |

*For backward compatibility, `name` is accepted as identifier if `id` is missing. New workflows should use explicit `id` fields.

#### Uniqueness Requirement

Step IDs must be unique across ALL phases in a workflow. This allows unambiguous step targeting:

```bash
# Target specific step
/fractary-faber:run --work-id 123 --step build:implement

# If "implement" existed in both build and evaluate phases, this would be ambiguous
# Solution: use unique IDs like "build-implement" and "evaluate-implement"
```

**Example: Same skill, different IDs**
```json
{
  "phases": {
    "frame": {
      "steps": [
        {"id": "initial-inspect", "name": "Initial Inspection", "skill": "data-inspector"}
      ]
    },
    "evaluate": {
      "steps": [
        {"id": "final-inspect", "name": "Final Validation", "skill": "data-inspector"}
      ]
    }
  }
}
```

#### Validation

Workflow validation now checks for:
- Missing step identifier (requires `id` or `name`)
- Duplicate step IDs across phases
- Deprecation warning for steps using `name` as identifier

```bash
# Run validation
/fractary-faber:audit

# Output includes step ID validation:
# All step IDs are unique across phases
# Step 'test' uses deprecated 'name' as identifier. Add explicit 'id' field.
```

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
  "id": "fetch-work",
  "name": "Fetch Work Item",
  "description": "Fetch work item details from issue tracker",
  "skill": "fractary-work:issue-fetcher"
}
```
**Behavior**: Skill executes with default behavior. Description used for documentation.

#### Pattern 2: Step with Skill + Prompt
```json
{
  "id": "create-pr",
  "name": "Create Pull Request",
  "description": "Create pull request for review",
  "skill": "fractary-repo:pr-manager",
  "prompt": "Create PR with comprehensive summary, test plan, and FABER attribution"
}
```
**Behavior**: Skill executes with customized behavior based on prompt. Description used for documentation.

#### Pattern 3: Direct Claude Execution (No Skill)
```json
{
  "id": "implement",
  "name": "Implement Solution",
  "description": "Implement solution from specification",
  "prompt": "Implement based on specification, following project code standards and best practices"
}
```
**Behavior**: Claude executes directly using prompt as instruction. Description used for documentation.

#### Pattern 4: Legacy (Description Only, No Skill) - Deprecated
```json
{
  "name": "test",
  "description": "Run automated tests"
}
```
**Behavior**: Claude executes using description as prompt (backward compatibility). Recommended to add explicit `id` and `prompt` fields for clarity.

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

## Result Handling

Steps and hooks can optionally define `result_handling` to control behavior based on execution outcomes. **If omitted, sensible defaults are applied automatically.**

### Default Result Handling

```json
{
  "on_success": "continue",
  "on_warning": "continue",
  "on_failure": "stop"
}
```

- **on_success**: `"continue"` (proceed automatically) or `"prompt"` (ask user)
- **on_warning**: `"continue"` (log and proceed), `"prompt"` (ask user with options), or `"stop"` (halt workflow)
- **on_failure**: `"stop"` (IMMUTABLE for steps - always stops workflow)

### Example: Using Defaults

Most steps don't need explicit result_handling:

```json
{
  "name": "implement",
  "description": "Implement solution"
}
```

This uses defaults: continue on success/warning, stop on failure.

### Example: Custom Warning Behavior

Override only what you need:

```json
{
  "name": "security-scan",
  "description": "Run security scan",
  "result_handling": {
    "on_warning": "prompt"
  }
}
```

This prompts the user on warnings, but uses defaults for success/failure.

### Intelligent Prompts

When warnings or failures occur with `prompt` behavior, FABER displays intelligent prompts with:
- Analysis of what went wrong
- Suggested fixes or actions
- Options ordered by recommendation (ignore and continue first for warnings, stop workflow recommended for failures)

For complete documentation, see [RESULT-HANDLING.md](./RESULT-HANDLING.md).

## Plan and Run Artifacts

### Storage Locations

FABER stores operational artifacts in the `logs/` directory:

```
logs/fractary/plugins/faber/
|-- plans/                   # Plan artifacts from /fractary-faber:plan
|   |-- {plan-id}.json       # Individual plan files
|-- runs/                    # Run state and events
    |-- {run-id}/
        |-- state.json       # Current workflow state
        |-- metadata.json    # Run metadata
        |-- events/          # Event log files
```

**Why `logs/` instead of `.fractary/`?**

- `.fractary/` is for **committed configuration** (version controlled)
- `logs/` is for **operational artifacts** (gitignored)
- Plans and runs are operational data, not source code
- Can be synced/archived via fractary-logs plugin

### Listing Plans

```bash
# List available plans
ls logs/fractary/plugins/faber/plans/

# View a specific plan
cat logs/fractary/plugins/faber/plans/{plan-id}.json
```

### Plan Lifecycle

1. **Created** by `/fractary-faber:plan` or `/fractary-faber:run`
2. **Read** by `/fractary-faber:execute`
3. **Updated** with execution results
4. **Archived** (optionally) via fractary-logs plugin

## See Also

- [RESULT-HANDLING.md](./RESULT-HANDLING.md) - Complete result handling guide
- [HOOKS.md](./HOOKS.md) - Complete guide to phase-level hooks
- [STATE-TRACKING.md](./STATE-TRACKING.md) - Dual-state tracking guide
- [MIGRATION-v2.md](./MIGRATION-v2.md) - Migration from v1.x to v2.0
- [architecture.md](./architecture.md) - FABER architecture overview
- Example config: `plugins/faber/config/faber.example.json`
