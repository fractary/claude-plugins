# FABER Result Handling Guide

Complete guide to step and hook result handling in FABER workflow.

## Overview

FABER v2.1 introduces **default result handling configuration** for steps and hooks. This allows workflow configurations to be more concise by omitting result_handling when using standard defaults.

## Default Configuration

When a step or hook does not specify `result_handling`, these defaults are applied:

### Step Defaults

```json
{
  "on_success": "continue",
  "on_warning": "continue",
  "on_failure": "stop"
}
```

| Field | Default | Description |
|-------|---------|-------------|
| `on_success` | `"continue"` | Proceed automatically to next step |
| `on_warning` | `"continue"` | Log warning and proceed |
| `on_failure` | `"stop"` | **IMMUTABLE** - Always stops workflow |

**Important**: `on_failure` is **IMMUTABLE** for steps. It is always enforced as `"stop"` regardless of what is configured. This ensures workflow integrity.

### Hook Defaults

```json
{
  "on_success": "continue",
  "on_warning": "continue",
  "on_failure": "stop"
}
```

| Field | Default | Description |
|-------|---------|-------------|
| `on_success` | `"continue"` | Proceed automatically |
| `on_warning` | `"continue"` | Log warning and proceed |
| `on_failure` | `"stop"` | Default; can be `"continue"` for informational hooks |

**Note**: Unlike steps, hooks CAN set `on_failure: "continue"` for informational hooks that should not block workflow execution.

## Result Types

Steps and hooks return a standardized result structure using the **FABER Response Format**.

**Schema Reference**: `plugins/faber/config/schemas/skill-response.schema.json`
**Full Documentation**: `plugins/faber/docs/RESPONSE-FORMAT.md`
**Best Practices**: `docs/standards/SKILL-RESPONSE-BEST-PRACTICES.md`

```json
{
  "status": "success" | "warning" | "failure",
  "message": "Human-readable summary",
  "details": {},
  "errors": [],
  "warnings": [],
  "error_analysis": "Root cause explanation (recommended for failures)",
  "warning_analysis": "Impact assessment (recommended for warnings)",
  "suggested_fixes": ["Actionable fix suggestions"]
}
```

### Status: Success

Step completed successfully without issues.

**Behaviors:**
- `on_success: "continue"` (default) - Proceed to next step automatically
- `on_success: "prompt"` - Ask user before proceeding

### Status: Warning

Step completed but with warnings that may need attention.

**Behaviors:**
- `on_warning: "continue"` (default) - Log warnings, proceed automatically
- `on_warning: "prompt"` - Show intelligent warning prompt with options
- `on_warning: "stop"` - Treat as failure and stop workflow

### Status: Failure

Step failed to complete successfully.

**Behaviors:**
- `on_failure: "stop"` (default, IMMUTABLE for steps) - Show intelligent failure prompt
- `on_failure: "continue"` (hooks only) - Log failure, proceed anyway

## Intelligent Prompts

When `on_warning: "prompt"` or a failure occurs, FABER displays intelligent prompts with analysis and options.

### Warning Prompt

```
┌─────────────────────────────────────────────────────────────┐
│  ⚠️  STEP WARNING                                           │
├─────────────────────────────────────────────────────────────┤
│  Step: implement                                            │
│  Phase: build                                               │
│  Status: Completed with warnings                            │
├─────────────────────────────────────────────────────────────┤
│  WARNINGS:                                                  │
│    • Deprecated API usage detected                          │
│    • Missing type annotations in 2 functions                │
├─────────────────────────────────────────────────────────────┤
│  ANALYSIS:                                                  │
│  The deprecated API will be removed in v3.0. Consider       │
│  updating to the new API now to avoid future issues.        │
├─────────────────────────────────────────────────────────────┤
│  SUGGESTED ACTIONS:                                         │
│  • Update to new API: Replace callOldAPI() with callNewAPI()│
│  • Add type annotations to exported functions               │
└─────────────────────────────────────────────────────────────┘
```

**Options (in order):**
1. **Ignore and continue** (default) - Acknowledge warnings and proceed
2. **Fix: {suggested_fix}** (if available) - Apply fix and retry
3. **Stop workflow** - Conservative choice to halt

### Failure Prompt

```
┌─────────────────────────────────────────────────────────────┐
│  ❌  STEP FAILURE                                           │
├─────────────────────────────────────────────────────────────┤
│  Step: test                                                 │
│  Phase: evaluate                                            │
│  Status: Failed                                             │
├─────────────────────────────────────────────────────────────┤
│  ERROR:                                                     │
│    5 tests failed in authentication module                  │
├─────────────────────────────────────────────────────────────┤
│  DETAILS:                                                   │
│    • test_login_invalid_credentials: AssertionError         │
│    • test_logout_session_cleanup: TimeoutError              │
│    • test_token_refresh_expired: KeyError                   │
├─────────────────────────────────────────────────────────────┤
│  ANALYSIS & SUGGESTIONS:                                    │
│  The failures appear related to session handling. Check     │
│  that session cleanup properly awaits async operations.     │
│                                                             │
│  Suggested fixes:                                           │
│    • Add await to session.cleanup() call in logout handler  │
│    • Check token expiry calculation in refresh function     │
└─────────────────────────────────────────────────────────────┘
```

**Options (in priority order - NOT RECOMMENDED option is LAST):**
1. **Fix: {suggested_fix}** (if available) - Apply suggested fix
2. **Diagnose: {diagnostic_command}** (if available) - Run diagnostic
3. **Continue anyway (NOT RECOMMENDED)** - Explicitly discouraged
4. **Stop workflow (recommended)** - Default action

## Configuration Examples

### Minimal Configuration (Uses Defaults)

```json
{
  "steps": [
    {
      "name": "implement",
      "description": "Implement solution",
      "prompt": "Implement based on specification"
    },
    {
      "name": "commit",
      "description": "Create commit",
      "skill": "fractary-repo:commit-creator"
    }
  ]
}
```

Both steps use default result_handling: continue on success/warning, stop on failure.

### Custom Warning Behavior

```json
{
  "steps": [
    {
      "name": "security-scan",
      "description": "Run security scan",
      "skill": "fractary-security:scanner",
      "result_handling": {
        "on_warning": "prompt"
      }
    }
  ]
}
```

Only `on_warning` is customized. `on_success` and `on_failure` use defaults.

### Strict Warning Mode

```json
{
  "steps": [
    {
      "name": "lint",
      "description": "Run linter",
      "prompt": "Run project linter",
      "result_handling": {
        "on_warning": "stop"
      }
    }
  ]
}
```

Warnings are treated as failures - workflow stops immediately.

### Informational Hook (Continue on Failure)

```json
{
  "hooks": {
    "post_release": [
      {
        "type": "script",
        "name": "notify-team",
        "path": "./scripts/notify.sh",
        "description": "Send team notification",
        "result_handling": {
          "on_failure": "continue"
        }
      }
    ]
  }
}
```

Notification failure doesn't block the workflow.

## Best Practices

### 1. Use Defaults When Possible

```json
// ✅ Good - uses defaults
{
  "name": "implement",
  "description": "Implement solution"
}

// ❌ Verbose - explicitly specifies defaults
{
  "name": "implement",
  "description": "Implement solution",
  "result_handling": {
    "on_success": "continue",
    "on_warning": "continue",
    "on_failure": "stop"
  }
}
```

### 2. Customize Only What You Need

```json
// ✅ Good - only overrides on_warning
{
  "name": "test",
  "result_handling": {
    "on_warning": "prompt"
  }
}

// ❌ Verbose - specifies all fields unnecessarily
{
  "name": "test",
  "result_handling": {
    "on_success": "continue",
    "on_warning": "prompt",
    "on_failure": "stop"
  }
}
```

### 3. Use Prompt for Critical Steps

For steps where warnings might indicate serious issues:

```json
{
  "name": "deploy",
  "description": "Deploy to production",
  "result_handling": {
    "on_warning": "prompt"
  }
}
```

### 4. Use Continue for Informational Hooks

For hooks that provide optional functionality:

```json
{
  "name": "telemetry",
  "type": "script",
  "path": "./scripts/send-metrics.sh",
  "description": "Send usage metrics",
  "result_handling": {
    "on_failure": "continue"
  }
}
```

## Recovery Tracking

When users interact with failure/warning prompts, their choices are tracked in workflow state:

```json
{
  "failure_recoveries": [
    {
      "step": "build:implement",
      "timestamp": "2025-12-05T10:30:00Z",
      "action": "suggested_fix",
      "outcome": "retry_attempted"
    },
    {
      "step": "evaluate:test",
      "timestamp": "2025-12-05T10:35:00Z",
      "action": "force_continue",
      "acknowledged": true,
      "outcome": "continued_despite_failure"
    }
  ]
}
```

This provides an audit trail of how failures were handled during workflow execution.

## Migration from Explicit Configuration

If your workflow files have explicit result_handling that matches the defaults, you can safely remove them:

**Before:**
```json
{
  "name": "implement",
  "description": "Implement solution",
  "result_handling": {
    "on_success": "continue",
    "on_warning": "continue",
    "on_failure": "stop"
  }
}
```

**After:**
```json
{
  "name": "implement",
  "description": "Implement solution"
}
```

Existing configurations with explicit result_handling will continue to work unchanged (backward compatibility).

## See Also

- [configuration.md](./configuration.md) - Complete configuration guide
- [HOOKS.md](./HOOKS.md) - Phase-level hooks guide
- [STATE-TRACKING.md](./STATE-TRACKING.md) - Workflow state tracking
- Schema: `plugins/faber/config/workflow.schema.json`
