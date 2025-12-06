# FABER Hooks Guide

> **⚠️ DEPRECATED in v2.2**: Hooks are deprecated in favor of `pre_steps` and `post_steps` in workflow definitions.
> See [MIGRATION-v2.2.md](./MIGRATION-v2.2.md) for migration instructions.
>
> **Use instead**:
> - `pre_steps` - Steps that run before phase main steps
> - `post_steps` - Steps that run after phase main steps
>
> The hook system will be removed in FABER v3.0.

---

Complete guide to phase-level hooks in FABER workflow.

## Overview

FABER v2.0 provides **10 phase-level hooks** (pre/post for each of 5 phases) for workflow customization. Hooks allow you to inject custom behavior at specific points in the workflow without modifying core FABER logic.

**v2.2 Replacement**: Use `pre_steps` and `post_steps` in workflow definitions instead:

```json
{
  "phases": {
    "build": {
      "pre_steps": [
        { "id": "load-standards", "prompt": "Read docs/STANDARDS.md for context" }
      ],
      "steps": [...],
      "post_steps": [
        { "id": "notify", "skill": "my-plugin:slack-notifier" }
      ]
    }
  }
}
```

## Hook Structure

Hooks are defined in `.fractary/plugins/faber/config.json`:

```json
{
  "hooks": {
    "pre_frame": [],
    "post_frame": [],
    "pre_architect": [],
    "post_architect": [],
    "pre_build": [],
    "post_build": [],
    "pre_evaluate": [],
    "post_evaluate": [],
    "pre_release": [],
    "post_release": []
  }
}
```

## Hook Types

### 1. Document Hooks

Load a document into context before/after a phase.

```json
{
  "type": "document",
  "name": "architecture-standards",
  "path": "docs/architecture/STANDARDS.md",
  "description": "Load architecture standards for design phase"
}
```

**Use cases**:
- Load coding standards before build
- Load architecture guidelines before architect
- Load deployment checklist before release

### 2. Skill Hooks

Invoke a skill before/after a phase.

```json
{
  "type": "skill",
  "name": "code-review",
  "skill": "fractary-review:code-reviewer",
  "description": "Automated code review before release"
}
```

**Use cases**:
- Run security scans before release
- Generate documentation after build
- Perform code review before release

### 3. Script Hooks

Execute a shell script before/after a phase.

```json
{
  "type": "script",
  "name": "notify-team",
  "path": "./scripts/notify-release.sh",
  "description": "Notify team of release completion"
}
```

**Use cases**:
- Send notifications
- Update external systems
- Run custom validation scripts

## Hook Execution

Hooks execute at specific points in the workflow:

```
workflow_start
  ↓
[pre_frame hooks]
  ↓
Frame Phase
  ↓
[post_frame hooks]
  ↓
[pre_architect hooks]
  ↓
Architect Phase
  ↓
[post_architect hooks]
  ↓
[pre_build hooks]
  ↓
Build Phase
  ↓
[post_build hooks]
  ↓
[pre_evaluate hooks]
  ↓
Evaluate Phase
  ↓
[post_evaluate hooks]
  ↓
[pre_release hooks]
  ↓
Release Phase
  ↓
[post_release hooks]
  ↓
workflow_complete
```

## Common Hook Patterns

### Load Standards Before Design

```json
{
  "pre_architect": [
    {
      "type": "document",
      "name": "architecture-standards",
      "path": "docs/ARCHITECTURE.md",
      "description": "Load architecture standards"
    }
  ]
}
```

### Load Coding Standards Before Implementation

```json
{
  "pre_build": [
    {
      "type": "document",
      "name": "coding-standards",
      "path": "docs/CODING_STANDARDS.md",
      "description": "Load coding standards"
    }
  ]
}
```

### Security Scan Before Release

```json
{
  "pre_release": [
    {
      "type": "skill",
      "name": "security-scan",
      "skill": "fractary-security:scanner",
      "description": "Run security scan before release"
    }
  ]
}
```

### Team Notification After Release

```json
{
  "post_release": [
    {
      "type": "script",
      "name": "notify-team",
      "path": "./scripts/notify.sh",
      "description": "Notify team of release"
    }
  ]
}
```

## Hook Result Handling

Hooks support the same `result_handling` configuration as steps, with one key difference: hooks can optionally continue on failure for informational hooks.

### Default Hook Result Handling

If `result_handling` is not specified, these defaults are applied:

```json
{
  "on_success": "continue",
  "on_warning": "continue",
  "on_failure": "stop"
}
```

### Informational Hooks (Continue on Failure)

For hooks that provide optional functionality (notifications, telemetry, etc.), you can configure them to continue on failure:

```json
{
  "type": "script",
  "name": "notify-team",
  "path": "./scripts/notify.sh",
  "description": "Send team notification",
  "result_handling": {
    "on_failure": "continue"
  }
}
```

This ensures notification failures don't block the workflow.

### Warning Prompt for Hooks

To prompt users when hooks complete with warnings:

```json
{
  "type": "skill",
  "name": "security-scan",
  "skill": "fractary-security:scanner",
  "description": "Run security scan",
  "result_handling": {
    "on_warning": "prompt"
  }
}
```

For complete result handling documentation, see [RESULT-HANDLING.md](./RESULT-HANDLING.md).

## Best Practices

1. **Use phase-level hooks** - Don't try to hook at sub-step level (not supported in v2.0)
2. **Keep hooks lightweight** - Long-running operations should be async
3. **Use descriptive names** - Make it clear what each hook does
4. **Document purpose** - Always include meaningful descriptions
5. **Test hooks separately** - Ensure scripts work before adding to workflow
6. **Handle errors gracefully** - Scripts should return appropriate exit codes
7. **Use `on_failure: "continue"`** for informational hooks that shouldn't block workflow

## Hook Logging

All hook executions are logged to `fractary-logs` with event type `hook_execute`:

```json
{
  "event_type": "hook_execute",
  "timestamp": "2025-11-19T10:40:45Z",
  "phase": "frame",
  "position": "pre",
  "hook_name": "load-context",
  "hook_type": "document",
  "message": "Executing pre_frame hook: load-context"
}
```

## See Also

- [CONFIGURATION.md](./configuration.md) - Complete configuration guide
- [RESULT-HANDLING.md](./RESULT-HANDLING.md) - Complete result handling guide
- [STATE-TRACKING.md](./STATE-TRACKING.md) - Dual-state tracking guide
- Example config: `plugins/faber/config/faber.example.json`
