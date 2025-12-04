# Migration Guide: FABER v1.x → v2.0

This guide helps domain plugin authors migrate from the multi-agent architecture (v1.x) to the single workflow-manager architecture (v2.0).

## Table of Contents

- [Overview](#overview)
- [What Changed](#what-changed)
- [Migration Checklist](#migration-checklist)
- [For Domain Plugin Authors](#for-domain-plugin-authors)
- [Breaking Changes](#breaking-changes)
- [Examples](#examples)

## Overview

FABER v2.0 introduces a **single workflow-manager architecture** that consolidates the 5 phase managers into one agent with 5 phase skills. This change:

- **Reduces context by ~60%** (from ~98K to ~40K tokens for orchestration)
- **Maintains continuous context** across all phases
- **Enables skill overrides** via configuration
- **Simplifies maintenance** with single orchestration point

## What Changed

### Architecture Changes

**v1.x (Multi-Agent)**:
```
director.md (26K)
├─ frame-manager.md (12K)
├─ architect-manager.md (14K)
├─ build-manager.md (14K)
├─ evaluate-manager.md (16K)
└─ release-manager.md (16K)
Total: ~98K tokens
```

**v2.0 (Single Workflow-Manager)**:
```
director.md (15K) - lightweight router
└─ workflow-manager.md (25K) - all 5 phases
    ├─ frame (skill)
    ├─ architect (skill)
    ├─ build (skill)
    ├─ evaluate (skill)
    └─ release (skill)
Total: ~40K tokens (~60% reduction)
```

### Key Changes

1. **Phase managers → Phase skills**: Each phase is now a skill with `workflow/basic.md`
2. **Director refactored**: Now a lightweight router, delegates to workflow-manager
3. **Continuous context**: workflow-manager maintains context across all phases
4. **Skill overrides**: Domain plugins can override phase implementations via config
5. **Configuration schema**: New `[workflow.skills]` section for customization

## Migration Checklist

### For FABER Core Users (No Action Required)

If you're using FABER without custom domain plugins:

- ✅ **No migration needed** - v2.0 is backward compatible
- ✅ Configuration files work as-is (new fields are optional)
- ✅ Commands use `/fractary-faber:*` prefix (`/fractary-faber:run`, `/fractary-faber:status`, etc.)
- ✅ Session files remain compatible

### For Domain Plugin Authors

If you've created custom domain plugins (e.g., `faber-app`, `faber-cloud`):

- [ ] Review phase manager implementations
- [ ] Create phase skills with `workflow/{domain}.md`
- [ ] Update plugin configuration
- [ ] Test workflow execution
- [ ] Update documentation

## For Domain Plugin Authors

### Step 1: Identify Custom Phase Logic

Review your existing phase managers and identify customizations:

```bash
# Check for custom phase managers in your domain plugin
ls plugins/faber-{domain}/agents/*-manager.md

# Identify which phases have custom logic
# - If using FABER defaults → No migration needed
# - If custom implementation → Create skill override
```

### Step 2: Create Phase Skills

For each custom phase, create a skill with domain-specific workflow:

```bash
# Example: Custom architect phase for "app" domain
mkdir -p plugins/faber-app/skills/architect/workflow/
touch plugins/faber-app/skills/architect/SKILL.md
touch plugins/faber-app/skills/architect/workflow/app.md
```

**File structure**:
```
plugins/faber-app/
├─ skills/
│  └─ architect/
│     ├─ SKILL.md              # Skill metadata and integration
│     └─ workflow/
│        └─ app.md             # Domain-specific implementation
```

**Example `SKILL.md`**:
```markdown
---
name: architect
domain: app
description: Application-specific architecture phase
workflow-file: workflow/app.md
---

# Architect Skill (App Domain)

This skill provides application-specific architecture patterns.

## What's Different from Basic

- Uses app-specific spec templates
- Includes database schema generation
- Adds API endpoint planning
- Integrates with app frameworks

## Invocation

The workflow-manager invokes this skill when:
- `workflow.skills.architect = "app"`
- Work domain is "engineering" or "app"

## Workflow

See [workflow/app.md](workflow/app.md) for implementation steps.
```

**Example `workflow/app.md`**:
```markdown
# Architect Workflow - App Domain

<WORKFLOW>

## Step 1: Load Context

Retrieve Frame phase context:
- Work item details
- Branch name
- Work type classification

## Step 2: Generate App Spec

Create application specification including:
1. Feature requirements
2. Database schema (if needed)
3. API endpoints
4. UI components
5. Integration points

Use template: `plugins/faber-app/templates/spec-app.md`

## Step 3: Commit Spec

Use @agent-fractary-repo:repo-manager to:
1. Commit spec file
2. Push to feature branch

## Step 4: Update Session

Record architect phase completion:
- spec_file path
- spec_url (if uploaded)
- database_changes (if any)
- api_changes (if any)

</WORKFLOW>
```

### Step 3: Update Plugin Configuration

Add skill overrides to your domain plugin's preset:

```toml
# plugins/faber-app/presets/app-development.toml

[workflow.skills]
frame = "basic"        # Use FABER default
architect = "app"      # Use app-domain override
build = "app"          # Use app-domain override
evaluate = "app"       # Use app-domain override
release = "basic"      # Use FABER default
```

### Step 4: Update Plugin Metadata

Update `.claude-plugin/plugin.json`:

```json
{
  "name": "fractary-faber-app",
  "version": "2.0.0",
  "description": "FABER workflows for application development",
  "skills": "./skills/",
  "requires": [
    "fractary-faber@^2.0.0"
  ],
  "provides": {
    "workflow_skills": {
      "architect": "app",
      "build": "app",
      "evaluate": "app"
    }
  }
}
```

### Step 5: Archive Old Phase Managers

Move old phase managers to archived directory:

```bash
mkdir -p plugins/faber-app/agents/archived/
mv plugins/faber-app/agents/*-manager.md plugins/faber-app/agents/archived/
```

### Step 6: Test Migration

Test your domain plugin with FABER v2.0:

```bash
# 1. Update configuration to use domain skills
cat > .faber.config.toml <<EOF
[defaults]
preset = "app-development"

[workflow.skills]
architect = "app"
build = "app"
evaluate = "app"
EOF

# 2. Run workflow
/fractary-faber:run --work-id 123

# 3. Verify each phase uses domain skills
# Check session file: .faber/sessions/{work_id}.json
# Confirm skills used in each phase
```

## Breaking Changes

### 1. Phase Manager Invocation (Removed)

**v1.x**:
```
director invokes frame-manager directly
director invokes architect-manager directly
...
```

**v2.0**:
```
director invokes workflow-manager
workflow-manager invokes frame skill
workflow-manager invokes architect skill
...
```

**Migration**: Don't invoke phase managers directly. Use workflow-manager instead.

### 2. Phase Manager Agents (Archived)

**v1.x**: `agents/frame-manager.md`, `agents/architect-manager.md`, etc.

**v2.0**: Moved to `agents/archived/` (preserved for reference)

**Migration**: Create phase skills instead of phase managers.

### 3. Configuration Schema (Extended)

**v1.x**: No skill overrides

**v2.0**: New `[workflow.skills]` section

```toml
[workflow.skills]
frame = "basic"
architect = "basic"
build = "basic"
evaluate = "basic"
release = "basic"
```

**Migration**: Add `[workflow.skills]` to config files (optional, defaults to "basic").

### 4. Context Passing (Improved)

**v1.x**: Each phase manager receives only prior phase outputs

**v2.0**: workflow-manager maintains **continuous context** across all phases

**Migration**: Skills receive richer context. No changes needed, but can leverage more context.

## Examples

### Example 1: App Development Domain

**Before (v1.x)**:
```
plugins/faber-app/
├─ agents/
│  ├─ architect-manager-app.md  # Custom architect for apps
│  ├─ build-manager-app.md      # Custom build for apps
│  └─ evaluate-manager-app.md   # Custom evaluate for apps
```

**After (v2.0)**:
```
plugins/faber-app/
├─ skills/
│  ├─ architect/
│  │  ├─ SKILL.md
│  │  └─ workflow/app.md
│  ├─ build/
│  │  ├─ SKILL.md
│  │  └─ workflow/app.md
│  └─ evaluate/
│     ├─ SKILL.md
│     └─ workflow/app.md
├─ agents/
│  └─ archived/                 # Old managers preserved
│     ├─ architect-manager-app.md
│     ├─ build-manager-app.md
│     └─ evaluate-manager-app.md
```

**Configuration**:
```toml
[workflow.skills]
frame = "basic"
architect = "app"
build = "app"
evaluate = "app"
release = "basic"
```

### Example 2: Cloud Infrastructure Domain

**Before (v1.x)**:
```
plugins/faber-cloud/
├─ agents/
│  ├─ frame-manager-cloud.md
│  ├─ architect-manager-cloud.md
│  ├─ build-manager-cloud.md
│  ├─ evaluate-manager-cloud.md
│  └─ release-manager-cloud.md
```

**After (v2.0)**:
```
plugins/faber-cloud/
├─ skills/
│  ├─ frame/
│  │  ├─ SKILL.md
│  │  └─ workflow/cloud.md
│  ├─ architect/
│  │  ├─ SKILL.md
│  │  └─ workflow/cloud.md
│  ├─ build/
│  │  ├─ SKILL.md
│  │  └─ workflow/cloud.md
│  ├─ evaluate/
│  │  ├─ SKILL.md
│  │  └─ workflow/cloud.md
│  └─ release/
│     ├─ SKILL.md
│     └─ workflow/cloud.md
```

**Configuration**:
```toml
[workflow.skills]
frame = "cloud"
architect = "cloud"
build = "cloud"
evaluate = "cloud"
release = "cloud"
```

### Example 3: Hybrid Approach

Use FABER defaults for some phases, custom for others:

```toml
[workflow.skills]
frame = "basic"        # Use FABER default
architect = "cloud"    # Use cloud-specific
build = "cloud"        # Use cloud-specific
evaluate = "cloud"     # Use cloud-specific
release = "basic"      # Use FABER default
```

## Benefits of v2.0

### For All Users

1. **60% context reduction** - Faster execution, lower costs
2. **Continuous context** - Better decision making across phases
3. **Simpler architecture** - Easier to understand and debug
4. **Backward compatible** - Existing workflows continue to work

### For Domain Plugin Authors

1. **Skill-based overrides** - Fine-grained customization
2. **Mix and match** - Combine basic and custom skills
3. **Easier maintenance** - Single orchestration point
4. **Better extensibility** - Add domain skills without touching core

## Support

### Questions?

- Review [architecture.md](architecture.md) for technical details
- Check [CLAUDE.md](../CLAUDE.md) for development guidance
- See [examples](../examples/) for reference implementations

### Issues?

- Report bugs: https://github.com/fractary/claude-plugins/issues
- Label: `faber-v2-migration`

## Next Steps

1. ✅ Read this migration guide
2. ✅ Identify custom phase logic in your domain plugin
3. ✅ Create phase skills with `workflow/{domain}.md`
4. ✅ Update configuration files
5. ✅ Test with FABER v2.0
6. ✅ Update documentation
7. ✅ Release updated domain plugin

Welcome to FABER v2.0! 🎉
