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

Projects can define multiple workflows for different scenarios:
- **default** - Standard feature development
- **hotfix** - Fast-track critical fixes
- **documentation** - Docs-only changes

Each workflow defines its own phases, hooks, and autonomy level.

### Complete Example

See `plugins/faber/config/faber.example.json` for a complete configuration with:
- All 5 phases fully defined
- Phase-level hooks examples
- Safe autonomy defaults
- Plugin integrations

## See Also

- [HOOKS.md](./HOOKS.md) - Complete guide to phase-level hooks
- [STATE-TRACKING.md](./STATE-TRACKING.md) - Dual-state tracking guide
- [MIGRATION-v2.md](./MIGRATION-v2.md) - Migration from v1.x to v2.0
- [architecture.md](./architecture.md) - FABER architecture overview
- Example config: `plugins/faber/config/faber.example.json`
