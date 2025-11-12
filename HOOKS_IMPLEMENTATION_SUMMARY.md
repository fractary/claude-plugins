# Unified Hooks and Context Injection System - Implementation Summary

**Date**: 2025-11-12
**Status**: Design Complete, Ready for Implementation

## Overview

I've designed and documented a comprehensive **unified hooks and context injection system** for FABER plugins that enables project-specific customization without requiring wrapper commands.

## What Was Created

### 1. Core Specification

**File**: `docs/specs/SPEC-0026-unified-hooks-context-injection.md`

A complete technical specification covering:
- Problem statement and motivation
- Four hook types (context, prompt, script, skill)
- Configuration format (TOML and JSON)
- Hook execution lifecycle
- Integration patterns
- Examples and use cases
- Open questions and future considerations

**Key Innovation**: **Context and Prompt hooks** that inject project-specific documentation and guidance directly into agent context.

### 2. Hook Executor Skill

**Files**:
- `plugins/faber/skills/hook-executor/SKILL.md` - Main skill definition
- `plugins/faber/skills/hook-executor/scripts/load-context.sh` - Load documentation references
- `plugins/faber/skills/hook-executor/scripts/execute-script-hook.sh` - Execute shell scripts
- `plugins/faber/skills/hook-executor/scripts/format-context-injection.sh` - Format context blocks

The hook executor handles all hook types with proper:
- Environment filtering
- Timeout enforcement
- Failure handling
- Context injection formatting
- Execution order management

### 3. Configuration Examples

**File**: `plugins/faber/config/faber.example-with-hooks.toml`

A complete example `.faber.config.toml` demonstrating:
- Hooks for all 5 FABER phases (Frame, Architect, Build, Evaluate, Release)
- All 4 hook types (context, prompt, script, skill)
- Environment-specific hooks (production warnings)
- Weight/priority system
- Best practices

### 4. Integration Guide

**File**: `plugins/faber/docs/guides/HOOKS_INTEGRATION_GUIDE.md`

Step-by-step guide for integrating hooks into the FABER workflow manager:
- Hook execution pattern for each phase
- Helper function implementations
- Phase modification examples
- Skill modification requirements
- Complete implementation checklist
- Migration path

### 5. User Guide

**File**: `plugins/faber/docs/guides/ELIMINATING_WRAPPER_COMMANDS.md`

Demonstrates how hooks eliminate the need for project-specific wrapper commands:
- Before/after comparisons
- Real-world examples (e-commerce, multi-environment, data pipelines)
- Migration guide from wrapper commands to hooks
- Best practices
- Troubleshooting

### 6. Plugin Standards Update

**File**: `docs/standards/FRACTARY-PLUGIN-STANDARDS.md` (updated)

Added comprehensive "Hook Pattern" section to plugin standards:
- When to use hooks
- Hook types and configuration
- Hook timing and execution order
- Environment filtering
- Failure handling
- Weight/priority system
- Manager and skill integration requirements
- Examples and references

## Hook Types Explained

### 1. Context Hooks (NEW)

**Purpose**: Inject project-specific documentation into agent context

**Example**:
```toml
[[hooks.architect.pre]]
type = "context"
name = "architecture-standards"
prompt = "Follow our architecture patterns."
references = [
  { path = "docs/ARCHITECTURE.md", description = "Architecture standards" }
]
weight = "high"
```

**Result**: Agent receives formatted context with full documentation content

**Use Cases**:
- Coding standards
- Architecture patterns
- Testing requirements
- API design guidelines

### 2. Prompt Hooks (NEW)

**Purpose**: Inject short reminders or critical warnings

**Example**:
```toml
[[hooks.release.pre]]
type = "prompt"
name = "production-warning"
content = "⚠️  PRODUCTION - Extra caution required!"
weight = "critical"
environments = ["prod"]
```

**Result**: Formatted prompt block with appropriate urgency indicators

**Use Cases**:
- Environment-specific warnings
- Critical safety reminders
- Technology constraints

### 3. Script Hooks (Existing, Enhanced)

**Purpose**: Execute shell scripts at lifecycle points

**Example**:
```toml
[[hooks.build.post]]
type = "script"
name = "run-tests"
path = "./scripts/run-tests.sh"
required = true
failureMode = "stop"
```

**Use Cases**:
- Build scripts
- Test execution
- Notifications
- Cleanup

### 4. Skill Hooks (Existing, Enhanced)

**Purpose**: Invoke Claude Code skills for complex operations

**Example**:
```toml
[[hooks.evaluate.post]]
type = "skill"
name = "security-scanner"
required = true
failureMode = "stop"
```

**Use Cases**:
- Complex validation
- Code review
- Security scanning

## Key Features

### Environment Filtering

Hooks can target specific environments:
```toml
environments = ["prod", "production"]  # Only for production
```

### Weight/Priority System

Control context injection priority:
- `critical` - Never pruned, shown first
- `high` - Always included
- `medium` - Default, included
- `low` - May be pruned if context budget tight

### Failure Handling

Fine-grained control over failures:
- `required: true, failureMode: "stop"` → Critical, must pass
- `required: true, failureMode: "warn"` → Log warning, continue
- `required: false` → Optional, always continue

### Hook Timing

Execute at the right moment:
- **Pre-phase hooks**: Before phase execution (setup, context injection)
- **Post-phase hooks**: After phase execution (validation, notifications)

## Benefits

### For Users

✅ **No wrapper commands needed** - Use standard `/faber run` command
✅ **Configuration-driven** - Change behavior via `.faber.config.toml`
✅ **Environment-specific** - Different hooks for dev/staging/prod
✅ **Discoverable** - Explicit in configuration

### For Projects

✅ **Single source of truth** - Standards in docs, referenced via config
✅ **Easy maintenance** - Update docs, config stays the same
✅ **Reusable** - Same plugin works across projects
✅ **Testable** - Pure configuration, no code

### For Plugin Authors

✅ **Separation of concerns** - Core logic separate from project-specific
✅ **Extensibility** - Projects customize without forking
✅ **Consistent pattern** - Same hook system across plugins
✅ **Well-documented** - Standards and examples provided

## Implementation Status

### ✅ Completed

- [x] Full specification (SPEC-0026)
- [x] Hook executor skill implementation
- [x] Supporting scripts (load-context, execute-script-hook, format-context-injection)
- [x] Complete configuration example
- [x] Integration guide for workflow manager
- [x] User guide for eliminating wrapper commands
- [x] Plugin standards documentation
- [x] All scripts made executable

### 🔲 Remaining Work

- [ ] Integrate hooks into FABER workflow-manager.md
- [ ] Modify FABER phase skills to accept injected context
- [ ] Test hook executor skill
- [ ] Add hooks support to faber-app plugin
- [ ] Add hooks support to faber-cloud plugin (extend existing)
- [ ] Add hooks support to primitive plugins (work, repo, file)
- [ ] Create `/faber:hooks` command to list configured hooks
- [ ] Add hook validation command
- [ ] Create migration tooling for projects using wrapper commands

## Next Steps

### 1. Immediate: Integrate into FABER

Follow the integration guide (`HOOKS_INTEGRATION_GUIDE.md`) to:
1. Add hook configuration loading to workflow-manager
2. Add `execute_phase_hooks()` helper function
3. Modify each phase to execute pre/post hooks
4. Modify phase skills to accept `injected_context`

### 2. Testing

Create test projects with:
- Context hooks referencing documentation
- Prompt hooks with environment filtering
- Script hooks for build/test automation
- Skill hooks for validation

### 3. Documentation

Update:
- FABER README with hooks overview
- User guides with real examples
- Migration guide for existing projects

### 4. Plugin Adoption

Extend hooks to:
- `faber-app` - Application development hooks
- `faber-cloud` - Enhance existing hooks with context type
- Primitive plugins - Operation-specific hooks

## Example Use Case

### Before Hooks (Old Pattern)

**Problem**: Project needs to inject architecture standards into FABER workflow

**Solution**: Create wrapper command `.claude/commands/build-with-standards.md`:
```markdown
Build this feature following our architecture standards:
- Microservices pattern
- PostgreSQL for persistence
- Redis for caching
[... 50 lines of standards ...]

Use the FABER workflow for issue {id}
```

**Issues**:
- Standards duplicated in code and docs
- Must update command when standards change
- Not reusable across projects

### After Hooks (New Pattern)

**Problem**: Same - inject architecture standards

**Solution**: Configure hooks in `.faber.config.toml`:
```toml
[[hooks.architect.pre]]
type = "context"
name = "architecture-standards"
references = [
  { path = "docs/ARCHITECTURE.md", description = "Architecture standards" }
]
weight = "high"
```

**Benefits**:
- Standards in docs (single source of truth)
- Update docs, config stays the same
- Reusable across all projects
- Just use `/faber run 123` - standards automatically injected!

## File Locations

### Specification
- `docs/specs/SPEC-0026-unified-hooks-context-injection.md`

### Implementation
- `plugins/faber/skills/hook-executor/SKILL.md`
- `plugins/faber/skills/hook-executor/scripts/load-context.sh`
- `plugins/faber/skills/hook-executor/scripts/execute-script-hook.sh`
- `plugins/faber/skills/hook-executor/scripts/format-context-injection.sh`

### Examples & Guides
- `plugins/faber/config/faber.example-with-hooks.toml`
- `plugins/faber/docs/guides/HOOKS_INTEGRATION_GUIDE.md`
- `plugins/faber/docs/guides/ELIMINATING_WRAPPER_COMMANDS.md`

### Standards
- `docs/standards/FRACTARY-PLUGIN-STANDARDS.md` (Hook Pattern section added)

## Questions & Answers

### Q: How does this eliminate wrapper commands?

**A**: Wrapper commands typically inject project-specific context. With hooks, this context is configured in `.faber.config.toml` and automatically injected at the right phase, eliminating the need for custom commands.

### Q: What's the difference between context and prompt hooks?

**A**:
- **Context hooks**: Load full documentation files, format with references
- **Prompt hooks**: Short text snippets, no file loading

Use context for comprehensive guidance, prompt for quick reminders.

### Q: Can hooks reference multiple documentation files?

**A**: Yes! Context hooks support multiple references:
```toml
references = [
  { path = "docs/ARCHITECTURE.md", description = "Architecture" },
  { path = "docs/API_DESIGN.md", description = "API patterns" },
  { path = "docs/TESTING.md", description = "Testing" }
]
```

### Q: How do environment-specific hooks work?

**A**: Use the `environments` field:
```toml
environments = ["prod"]  # Only for production
```

Hook only executes when `FABER_ENVIRONMENT` matches.

### Q: What happens if a required hook fails?

**A**:
- `failureMode: "stop"` → Workflow halts, error returned
- `failureMode: "warn"` → Warning logged, workflow continues

### Q: Can hooks be tested in dry-run mode?

**A**: Yes! Use `/faber run 123 --autonomy dry-run` to see which hooks would execute without running them.

### Q: Are hooks backward compatible?

**A**: Yes! Hooks are opt-in. Existing projects without hook configuration work exactly as before.

## Summary

This implementation provides a powerful, flexible system for project-specific customization that:

1. **Eliminates wrapper commands** through configuration-driven context injection
2. **Maintains single source of truth** by referencing documentation rather than duplicating
3. **Enables environment-specific behavior** through environment filtering
4. **Provides fine-grained control** through weight/priority and failure handling
5. **Follows consistent patterns** across all plugins
6. **Is fully backward compatible** with existing implementations

The design is complete and ready for implementation. All documentation, examples, and supporting code is in place. The next step is to integrate hooks into the FABER workflow manager following the integration guide.
