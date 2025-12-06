# FABER Autonomy Model

Complete guide to the two-dimensional autonomy model for FABER workflow execution.

## Overview

FABER v2.1 introduces a **two-dimensional autonomy model** that replaces the legacy single-level approach. The new model provides precise control over:

1. **Check-in Frequency**: How often the workflow pauses for user review
2. **Tolerance Thresholds**: What severity of issues to tolerate before stopping

This separation allows workflows to run autonomously while still maintaining control over issue handling.

## Quick Start

### Basic Configuration

```json
{
  "autonomy": {
    "check_in_frequency": "per-phase",
    "warning_tolerance": "low",
    "error_tolerance": "none"
  }
}
```

This configuration:
- Pauses for review after each phase completes
- Tolerates low-severity warnings (continues automatically)
- Stops immediately on any error

### Preset Equivalents

| Use Case | Configuration |
|----------|---------------|
| Conservative | `check_in_frequency: "per-step"`, `warning_tolerance: "none"`, `error_tolerance: "none"` |
| Standard | `check_in_frequency: "per-phase"`, `warning_tolerance: "low"`, `error_tolerance: "none"` |
| Autonomous | `check_in_frequency: "end-only"`, `warning_tolerance: "medium"`, `error_tolerance: "low"` |

---

## Check-in Frequency

Controls when the workflow pauses for user review.

### Values

| Value | Behavior | Use When |
|-------|----------|----------|
| `per-step` | Pause after every step | Debugging, learning, sensitive operations |
| `per-phase` | Pause after each phase (default) | Normal development, balanced oversight |
| `end-only` | Pause only at workflow end | Automated CI/CD, batch processing |

### What Happens at Check-in

At each check-in point:
1. Display accumulated responses since last check-in
2. Show warnings and errors with severity/category
3. Present options: Continue, Review issues, or Stop
4. Wait for user decision

### Example: Per-Phase Check-in

```
┌─────────────────────────────────────────────────────────────┐
│  📋 PHASE CHECK-IN: Build Complete                          │
├─────────────────────────────────────────────────────────────┤
│  Steps Completed: 3/3                                        │
│  Duration: 2m 15s                                            │
│                                                              │
│  ⚠️  Warnings (2):                                           │
│    [medium] Deprecated API in src/api.ts                     │
│    [low] Large commit size (847 lines)                       │
│                                                              │
│  How would you like to proceed?                              │
│    1. Continue to Evaluate phase                             │
│    2. Review issues in detail                                │
│    3. Stop workflow                                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Tolerance Thresholds

Control what severity of issues to tolerate before triggering result handling.

### Warning Tolerance

| Value | Tolerates | Stops On | Recommendation |
|-------|-----------|----------|----------------|
| `none` | Nothing | Any warning | Strictest - for critical workflows |
| `low` | Low severity | Medium or High | Default - good balance |
| `medium` | Low + Medium | High only | Relaxed - for exploratory work |
| `high` | All warnings | Nothing | Most permissive - proceed always |

### Error Tolerance

| Value | Tolerates | Stops On | Recommendation |
|-------|-----------|----------|----------------|
| `none` | Nothing | Any error | Default - recommended for safety |
| `low` | Low severity | Medium or High | Use with caution |
| `medium` | Low + Medium | High only | Risky - may miss issues |
| `high` | All errors | Nothing | Dangerous - not recommended |

### Severity Levels

| Severity | Description | Examples |
|----------|-------------|----------|
| `low` | Informational, safe to ignore | Style issues, minor lint warnings |
| `medium` | Should be addressed eventually | Deprecated APIs, performance hints |
| `high` | Critical, address immediately | Security issues, breaking changes |

### Tolerance Evaluation

When an issue is detected:

```
IF issue.severity > tolerance THEN
  TRIGGER result_handling behavior (stop/prompt)
ELSE
  COLLECT for end-of-workflow report
  CONTINUE automatically
```

---

## Global Limits

Prevent runaway workflows with global limits.

### Configuration

```json
{
  "autonomy": {
    "check_in_frequency": "per-phase",
    "warning_tolerance": "medium",
    "error_tolerance": "low",
    "limits": {
      "max_total_warnings": 50,
      "max_total_errors": 20,
      "on_limit_reached": "stop"
    }
  }
}
```

### Limit Behavior

| Setting | Default | Description |
|---------|---------|-------------|
| `max_total_warnings` | 50 | Maximum warnings before action |
| `max_total_errors` | 20 | Maximum errors before action |
| `on_limit_reached` | `stop` | Action: `stop` or `truncate` |

When `on_limit_reached`:
- `stop`: Halt the workflow immediately
- `truncate`: Stop collecting but continue execution

---

## Phase Overrides

Override autonomy settings for specific phases.

### Example: Stricter Evaluate Phase

```json
{
  "autonomy": {
    "check_in_frequency": "per-phase",
    "warning_tolerance": "medium",
    "error_tolerance": "none",
    "overrides": {
      "evaluate": {
        "warning_tolerance": "none",
        "check_in_frequency": "per-step"
      }
    }
  }
}
```

This configuration:
- Globally: Check in per-phase, tolerate medium warnings
- Evaluate phase only: Check in per-step, don't tolerate any warnings

### Common Override Patterns

**Stricter Release Phase:**
```json
{
  "overrides": {
    "release": {
      "warning_tolerance": "none",
      "check_in_frequency": "per-step"
    }
  }
}
```

**Relaxed Build Phase:**
```json
{
  "overrides": {
    "build": {
      "warning_tolerance": "high"
    }
  }
}
```

---

## Migration from Legacy Levels

### Automatic Migration

Legacy `level` configuration is automatically migrated to the new model:

| Legacy Level | New Configuration |
|--------------|-------------------|
| `dry-run` | `per-step`, `none`, `none` |
| `assist` | `per-phase`, `none`, `none` |
| `guarded` | `per-phase`, `low`, `none` |
| `autonomous` | `end-only`, `medium`, `low` |

### Example Migration

**Before (legacy):**
```json
{
  "autonomy": {
    "level": "guarded"
  }
}
```

**After (new model):**
```json
{
  "autonomy": {
    "check_in_frequency": "per-phase",
    "warning_tolerance": "low",
    "error_tolerance": "none"
  }
}
```

### Backward Compatibility

- Legacy `level` configuration continues to work
- Deprecation warning logged when legacy format detected
- Explicit new settings override migrated values
- Support for legacy format will be removed in FABER v3.0

---

## Integration with Response Aggregation

The autonomy model works together with response aggregation:

### Always-On Collection

All responses are collected regardless of tolerance settings:
- Warnings within tolerance: Collected, workflow continues
- Warnings above tolerance: Collected, then trigger result_handling
- All responses appear in end-of-workflow report

### Check-in Display

At each check-in, display:
- Responses accumulated since last check-in
- Organized by phase/step
- Categorized by severity and type

### End-of-Workflow Report

Regardless of autonomy settings:
- Complete report always generated
- All collected warnings/errors included
- Recommended actions prioritized by severity

---

## Configuration Examples

### Example 1: Strict CI/CD Pipeline

```json
{
  "autonomy": {
    "check_in_frequency": "end-only",
    "warning_tolerance": "none",
    "error_tolerance": "none",
    "limits": {
      "max_total_warnings": 10,
      "max_total_errors": 1,
      "on_limit_reached": "stop"
    }
  }
}
```

- No interruptions during execution
- Stops on any warning or error
- Very strict limits

### Example 2: Exploratory Development

```json
{
  "autonomy": {
    "check_in_frequency": "per-phase",
    "warning_tolerance": "medium",
    "error_tolerance": "low",
    "limits": {
      "max_total_warnings": 100,
      "max_total_errors": 50,
      "on_limit_reached": "truncate"
    }
  }
}
```

- Check in after each phase
- Tolerate most warnings
- Generous limits with truncation

### Example 3: Production Deployment

```json
{
  "autonomy": {
    "check_in_frequency": "per-phase",
    "warning_tolerance": "low",
    "error_tolerance": "none",
    "require_approval_for": ["release"],
    "overrides": {
      "release": {
        "check_in_frequency": "per-step",
        "warning_tolerance": "none"
      }
    }
  }
}
```

- Standard check-in during development phases
- Extra strict for release phase
- Explicit approval required for release

### Example 4: Debugging Workflow

```json
{
  "autonomy": {
    "check_in_frequency": "per-step",
    "warning_tolerance": "none",
    "error_tolerance": "none"
  }
}
```

- Maximum visibility
- Stop on any issue
- Review every step

---

## Best Practices

### 1. Start Conservative

Begin with stricter settings and relax as you gain confidence:
```json
{
  "check_in_frequency": "per-phase",
  "warning_tolerance": "low",
  "error_tolerance": "none"
}
```

### 2. Use Phase Overrides for Critical Phases

Tighten controls for release phase:
```json
{
  "overrides": {
    "release": {
      "warning_tolerance": "none"
    }
  }
}
```

### 3. Set Reasonable Limits

Don't set limits too high - they exist to catch runaway issues:
```json
{
  "limits": {
    "max_total_warnings": 50,
    "max_total_errors": 20
  }
}
```

### 4. Review End-of-Workflow Reports

Even with high tolerance, always review the final report:
- Address collected warnings before merging
- Track patterns in recurring issues
- Adjust tolerance based on experience

### 5. Match Autonomy to Context

- **Feature development**: Standard settings
- **Bug fixes**: Stricter error tolerance
- **Refactoring**: Higher warning tolerance
- **Production releases**: Strictest settings

---

## Related Documentation

- [RESULT-HANDLING.md](./RESULT-HANDLING.md) - How results trigger behaviors
- [RESPONSE-FORMAT.md](./RESPONSE-FORMAT.md) - Skill response format with severity/category
- [configuration.md](./configuration.md) - Complete configuration guide
- [workflow.schema.json](../config/workflow.schema.json) - Schema reference
