# Step Response Log Standards

## Purpose

Step response logs capture individual step and hook execution results during FABER workflow execution. Each step or hook generates one log entry, enabling fine-grained tracking, debugging, and aggregated reporting.

**Use for**:
- Individual step execution results (success, warning, failure)
- Hook execution results (pre-phase, post-phase)
- Retry attempt tracking
- Severity and category classification
- Suggested fix documentation
- Duration and timing metrics

**Do NOT use for**:
- Aggregated workflow summaries (use `workflow-execution` type)
- Build compilation logs (use `build` type)
- Test execution details (use `test` type)
- General operational logs (use `operational` type)

---

## Required Sections

Every step response log MUST include:

1. **Identity Fields**
   - `log_type: step-response`
   - `response_id` - UUID for this specific response
   - `run_id` - Parent workflow run identifier
   - `step_id` - Full step ID (format: `phase:step-name`)

2. **Execution Context**
   - `phase` - FABER phase (frame, architect, build, evaluate, release)
   - `type` - Execution type (step, hook, primitive)
   - `attempt` - Attempt number for retries

3. **Result Data**
   - `status` - Outcome (success, warning, failure)
   - `message` - Human-readable summary
   - `timestamp` - When execution started

---

## Severity Levels

All warnings and errors MUST have a severity level:

| Level | Description | Tolerance Meaning |
|-------|-------------|-------------------|
| `low` | Informational, safe to ignore | Continue past with minimal concern |
| `medium` | Should be addressed eventually | May require attention before release |
| `high` | Critical, should be addressed now | Should trigger stop or prompt |

### Severity Auto-Detection Heuristics

When a skill doesn't explicitly specify severity:

**High Severity Indicators:**
- Keywords: "critical", "security", "breaking", "fail", "error", "crash"
- Patterns: Authentication failures, data loss risks, security vulnerabilities

**Medium Severity Indicators:**
- Keywords: "deprecated", "warning", "should", "consider", "recommend"
- Patterns: API deprecations, performance concerns, missing documentation

**Low Severity Indicators:**
- Keywords: "style", "minor", "optional", "info", "note", "hint"
- Patterns: Code style issues, cosmetic improvements, informational notices

---

## Categories

All warnings and errors MUST have a category:

| Category | Description | Examples |
|----------|-------------|----------|
| `deprecation` | Deprecated API/feature usage | "useCallback deprecated in v3.0" |
| `performance` | Performance concerns | "Large bundle size", "Slow query" |
| `security` | Security issues | "Weak password", "SQL injection risk" |
| `style` | Code style/formatting | "Line too long", "Missing semicolon" |
| `compatibility` | Compatibility concerns | "IE11 not supported", "Node 14 required" |
| `validation` | Validation failures | "Invalid schema", "Missing field" |
| `configuration` | Configuration issues | "Missing env var", "Invalid config" |
| `other` | Uncategorized | Everything else |

### Category Auto-Detection Heuristics

**Deprecation:**
- "deprecated", "removed in", "obsolete", "will be removed", "legacy"

**Performance:**
- "slow", "performance", "memory", "cpu", "latency", "timeout", "large"

**Security:**
- "security", "vulnerability", "auth", "permission", "credential", "secret"

**Style:**
- "style", "format", "lint", "convention", "naming", "spacing"

**Validation:**
- "invalid", "validation", "schema", "required", "missing", "type error"

---

## Capture Rules

### ALWAYS Capture

- **Step identity**: run_id, step_id, phase, type
- **Execution result**: status, message
- **Timestamps**: start and end times
- **Duration**: execution time in milliseconds
- **Warnings/Errors**: with severity and category
- **Suggested fixes**: actionable recovery options
- **Attempt number**: for retry tracking

### NEVER Capture

- **Secrets or credentials**: API keys, passwords, tokens
- **PII data**: User emails, personal information
- **Full file contents**: Log paths and summaries, not full files
- **Stack traces with secrets**: Redact sensitive data from traces

---

## Naming Conventions

Step response log files follow this pattern:

```
step-response-{run_id}-{step_id}-{attempt}-{timestamp}.json
```

**Examples**:
- `step-response-abc123-build:implement-1-20251206T100000Z.json`
- `step-response-abc123-hook:pre-evaluate:lint-1-20251206T100500Z.json`

---

## Relationship to Workflow Execution Logs

Step response logs are the granular records that feed into workflow execution summaries:

```
workflow-execution (aggregated summary)
  └── step-response (individual records)
      ├── step-response (frame:fetch-work)
      ├── step-response (architect:generate-spec)
      ├── step-response (build:implement)
      ├── step-response (evaluate:test)
      └── step-response (release:create-pr)
```

The `workflow-execution` log references step responses via `step_response_refs`.

---

## Example Step Response Log

```json
{
  "log_type": "step-response",
  "response_id": "550e8400-e29b-41d4-a716-446655440000",
  "workflow_id": "workflow-237-20251206T100000Z",
  "run_id": "fractary/claude-plugins/abc123",
  "step_id": "build:implement",
  "step_name": "Implement Feature",
  "phase": "build",
  "type": "step",
  "attempt": 1,
  "status": "warning",
  "message": "Implementation completed with deprecated API usage",
  "details": {
    "files_modified": 5,
    "lines_added": 247,
    "lines_removed": 12
  },
  "warnings": [
    {
      "text": "Deprecated API: useCallback will be removed in v3.0",
      "severity": "medium",
      "category": "deprecation",
      "suggested_fix": "Replace useCallback with useMemo"
    },
    {
      "text": "Large commit size (247 lines added)",
      "severity": "low",
      "category": "style",
      "suggested_fix": "Consider breaking into smaller commits"
    }
  ],
  "errors": [],
  "warning_analysis": "The deprecated API should be addressed before v3.0 release",
  "suggested_fixes": [
    {
      "description": "Replace useCallback with useMemo for memoization",
      "command": "npx codemod deprecate-use-callback"
    }
  ],
  "duration_ms": 45230,
  "timestamp": "2025-12-06T10:00:00Z",
  "completed_at": "2025-12-06T10:00:45Z"
}
```

---

## Integration with Autonomy Model

Step responses are evaluated against the autonomy configuration:

```
FOR each warning in response.warnings:
  IF warning.severity > config.warning_tolerance:
    TRIGGER result_handling.on_warning behavior
  ELSE:
    COLLECT warning, CONTINUE

FOR each error in response.errors:
  IF error.severity > config.error_tolerance:
    TRIGGER result_handling.on_failure behavior
  ELSE:
    COLLECT error, CONTINUE
```

This enables tolerance-based continuation through workflows while still aggregating all issues for end-of-workflow reporting.

---

## Best Practices

1. **Be specific**: Include enough detail to understand what happened
2. **Classify accurately**: Use correct severity and category
3. **Suggest fixes**: Provide actionable suggestions when possible
4. **Include commands**: If a fix has a command, include it
5. **Track attempts**: Always record attempt number for retries
6. **Measure duration**: Record how long each step took
7. **Reference artifacts**: Note files created or modified
