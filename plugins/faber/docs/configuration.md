# FABER Configuration Guide (v2.0)

Complete guide to configuring FABER workflow for your projects using the new JSON-based configuration.

## Table of Contents

- [Quick Start](#quick-start)
- [Configuration File Location](#configuration-file-location)
- [Configuration Structure](#configuration-structure)
- [Configuration Sections](#configuration-sections)
- [Templates](#templates)
- [Examples](#examples)
- [Migration from v1.x](#migration-from-v1x)

## Quick Start

### Option 1: Auto-Initialize (Recommended)

```bash
# Auto-detect project type and generate config
/fractary-faber:init

# This creates .fractary/plugins/faber/config.json with appropriate settings
```

### Option 2: Specify Project Type

```bash
# Use specific template
/fractary-faber:init --type software
/fractary-faber:init --type infrastructure
/fractary-faber:init --type application
```

### Option 3: Manual Configuration

```bash
# Copy example configuration
cp plugins/faber/config/faber.example.json .fractary/plugins/faber/config.json

# Edit to match your project
vim .fractary/plugins/faber/config.json
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

```json
{
  "$schema": "https://fractary.io/schemas/faber-config-v1.json",
  "schema_version": "1.0",
  "project": { ... },
  "workflow": { ... },
  "phases": {
    "frame": { ... },
    "architect": { ... },
    "build": { ... },
    "evaluate": { ... },
    "release": { ... }
  },
  "hooks": { ... },
  "autonomy": { ... },
  "logging": { ... },
  "integrations": { ... },
  "safety": { ... }
}
```

## Configuration Sections

See the example configuration for complete details: `plugins/faber/config/faber.example.json`

## See Also

- [HOOKS.md](./HOOKS.md) - Complete guide to phase-level hooks
- [STATE-TRACKING.md](./STATE-TRACKING.md) - Dual-state tracking guide
- [MIGRATION-v2.md](./MIGRATION-v2.md) - Migration from v1.x to v2.0
- [architecture.md](./architecture.md) - FABER architecture overview
- Example config: `plugins/faber/config/faber.example.json`
- Templates: `plugins/faber/config/templates/*.json`
