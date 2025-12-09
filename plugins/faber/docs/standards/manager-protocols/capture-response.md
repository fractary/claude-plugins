# Response Capture Workflow

This document defines how step and hook responses are captured, normalized, and persisted to fractary-logs.

## Overview

After every step and hook execution, the response is:
1. Validated against the skill-response schema
2. Normalized (severity/category added if missing)
3. Evaluated against tolerance thresholds
4. Persisted to fractary-logs as `step-response` log type
5. Aggregated for the end-of-workflow report

---

## Capture Trigger Points

### After Step Execution

```pseudocode
FUNCTION afterStepExecution(step, result, context):
  # 1. Validate result structure
  validated_result = validateResult(result)

  # 2. Normalize warnings and errors
  normalized = normalizeResponse(validated_result)

  # 3. Build step-response log entry
  log_entry = buildStepResponseLog(step, normalized, context)

  # 4. Persist to fractary-logs
  log_id = persistLog(log_entry)

  # 5. Update state with log reference
  updateStateWithLogRef(context.run_id, log_id)

  # 6. Evaluate tolerance and check-in
  RETURN evaluateStepCompletion(step, normalized, context)
```

### After Hook Execution

```pseudocode
FUNCTION afterHookExecution(hook, result, context):
  # Same flow as steps, but with type="hook"
  validated_result = validateResult(result)
  normalized = normalizeResponse(validated_result)

  log_entry = buildHookResponseLog(hook, normalized, context)
  log_id = persistLog(log_entry)

  updateStateWithLogRef(context.run_id, log_id)

  RETURN evaluateHookCompletion(hook, normalized, context)
```

---

## Response Normalization

### Normalize Warnings

Convert string warnings to structured objects:

```pseudocode
FUNCTION normalizeWarnings(warnings: array): array
  normalized = []

  FOR each warning in warnings:
    IF typeof warning == "string" THEN
      # Auto-detect severity and category
      detected = detectSeverityAndCategory(warning)
      normalized.push({
        text: warning,
        severity: detected.severity,
        category: detected.category
      })
    ELSE
      # Already structured - fill missing fields
      detected = detectSeverityAndCategory(warning.text)
      normalized.push({
        text: warning.text,
        severity: warning.severity ?? detected.severity,
        category: warning.category ?? detected.category,
        suggested_fix: warning.suggested_fix  # Keep if present
      })

  RETURN normalized
```

### Normalize Errors

Same pattern as warnings:

```pseudocode
FUNCTION normalizeErrors(errors: array): array
  normalized = []

  FOR each error in errors:
    IF typeof error == "string" THEN
      detected = detectSeverityAndCategory(error)
      normalized.push({
        text: error,
        severity: detected.severity,
        category: detected.category
      })
    ELSE
      detected = detectSeverityAndCategory(error.text)
      normalized.push({
        text: error.text,
        severity: error.severity ?? detected.severity,
        category: error.category ?? detected.category,
        suggested_fix: error.suggested_fix
      })

  RETURN normalized
```

### Normalize Messages

Messages are informational only (no severity needed):

```pseudocode
FUNCTION normalizeMessages(messages: array): array
  normalized = []

  FOR each message in messages:
    IF typeof message == "string" THEN
      normalized.push({
        text: message
      })
    ELSE
      normalized.push({
        text: message.text,
        category: message.category
      })

  RETURN normalized
```

### Complete Normalization

```pseudocode
FUNCTION normalizeResponse(response):
  RETURN {
    status: response.status,
    message: response.message,
    details: response.details ?? {},
    warnings: normalizeWarnings(response.warnings ?? []),
    errors: normalizeErrors(response.errors ?? []),
    messages: normalizeMessages(response.messages ?? []),
    warning_analysis: response.warning_analysis,
    error_analysis: response.error_analysis,
    suggested_fixes: normalizeSuggestedFixes(response.suggested_fixes ?? [])
  }
```

---

## Building Log Entry

### Step Response Log

```pseudocode
FUNCTION buildStepResponseLog(step, response, context):
  RETURN {
    log_type: "step-response",
    response_id: generateUUID(),
    run_id: context.run_id,
    workflow_id: context.workflow_id,
    work_id: context.work_id,
    step_id: "{context.current_phase}:{step.name}",
    step_name: step.name,
    phase: context.current_phase,
    type: "step",
    attempt: context.current_attempt ?? 1,
    status: response.status,
    message: response.message,
    details: response.details,
    warnings: response.warnings,
    errors: response.errors,
    messages: response.messages,
    warning_analysis: response.warning_analysis,
    error_analysis: response.error_analysis,
    suggested_fixes: response.suggested_fixes,
    timestamp: getCurrentTimestamp(),
    duration_ms: context.step_duration_ms
  }
```

### Hook Response Log

```pseudocode
FUNCTION buildHookResponseLog(hook, response, context):
  hook_timing = context.is_pre_hook ? "pre" : "post"

  RETURN {
    log_type: "step-response",
    response_id: generateUUID(),
    run_id: context.run_id,
    workflow_id: context.workflow_id,
    work_id: context.work_id,
    step_id: "hook:{hook_timing}_{context.current_phase}:{hook.name}",
    step_name: hook.name,
    phase: context.current_phase,
    type: "hook",
    hook_timing: hook_timing,
    attempt: 1,  # Hooks don't retry
    status: response.status,
    message: response.message,
    details: response.details,
    warnings: response.warnings,
    errors: response.errors,
    messages: response.messages,
    warning_analysis: response.warning_analysis,
    error_analysis: response.error_analysis,
    suggested_fixes: response.suggested_fixes,
    timestamp: getCurrentTimestamp()
  }
```

---

## Persisting to fractary-logs

### Log Storage

```pseudocode
FUNCTION persistLog(log_entry):
  # Use fractary-logs skill to write
  result = Invoke Skill: fractary-logs:log-writer
    Operation: write
    Parameters:
      log_type: log_entry.log_type
      entry: log_entry

  IF result.status == "failure" THEN
    LOG "WARNING: Failed to persist log: {result.message}"
    # Continue - don't fail workflow due to logging failure

  RETURN result.details.log_id
```

### State Update

```pseudocode
FUNCTION updateStateWithLogRef(run_id, log_id):
  state = readState(run_id)

  # Initialize logs array if needed
  IF state.logs is null THEN
    state.logs = { step_responses: [] }

  # Add log reference
  state.logs.step_responses.push(log_id)

  # Update totals
  updateResponseTotals(state)

  writeState(run_id, state)
```

---

## Retry Handling

When a step is retried, each attempt gets its own log entry:

```pseudocode
FUNCTION handleRetry(step, previous_result, context):
  # Previous attempt already logged

  # Increment attempt counter
  context.current_attempt = (context.current_attempt ?? 1) + 1

  # Log retry event
  Bash: plugins/faber/skills/run-manager/scripts/emit-event.sh \
    --run-id "{context.run_id}" \
    --type "step_retry" \
    --phase "{context.current_phase}" \
    --step "{step.name}" \
    --message "Retrying step (attempt {context.current_attempt})"

  # Execute step again
  retry_result = executeStep(step, context)

  # New attempt logged with incremented attempt number
  RETURN afterStepExecution(step, retry_result, context)
```

---

## Aggregation for Report

### Collecting Warnings/Errors

After each response is captured, update running totals:

```pseudocode
FUNCTION updateResponseTotals(state):
  totals = {
    warnings: 0,
    errors: 0,
    by_severity: { low: 0, medium: 0, high: 0 },
    by_category: {}
  }

  # Count from all logged responses
  FOR each log_id in state.logs.step_responses:
    log = readLog(log_id)

    FOR each warning in log.warnings:
      totals.warnings += 1
      totals.by_severity[warning.severity] += 1
      totals.by_category[warning.category] = (totals.by_category[warning.category] ?? 0) + 1

    FOR each error in log.errors:
      totals.errors += 1
      totals.by_severity[error.severity] += 1
      totals.by_category[error.category] = (totals.by_category[error.category] ?? 0) + 1

  state.response_totals = totals
```

### Phase Summary

Build per-phase statistics:

```pseudocode
FUNCTION buildPhaseSummary(run_id, phase):
  logs = getPhaseLogsFromState(run_id, phase)

  summary = {
    status: "success",
    steps_total: 0,
    steps_succeeded: 0,
    warnings: 0,
    errors: 0,
    duration_ms: 0
  }

  FOR each log in logs:
    summary.steps_total += 1
    summary.duration_ms += log.duration_ms ?? 0

    IF log.status == "success" THEN
      summary.steps_succeeded += 1
    ELSE IF log.status == "warning" THEN
      summary.steps_succeeded += 1  # Warning = succeeded with issues
      summary.status = "warning"
    ELSE IF log.status == "failure" THEN
      summary.status = "failure"

    summary.warnings += log.warnings.length
    summary.errors += log.errors.length

  RETURN summary
```

---

## Workflow Execution Log

At workflow completion, generate aggregated summary:

```pseudocode
FUNCTION generateWorkflowExecutionLog(context):
  state = readState(context.run_id)

  # Determine final status
  final_status = determineFinalStatus(state)

  # Build phases summary
  phases_summary = {}
  FOR each phase in ["frame", "architect", "build", "evaluate", "release"]:
    phases_summary[phase] = buildPhaseSummary(context.run_id, phase)

  # Aggregate all warnings and errors
  aggregated_warnings = []
  aggregated_errors = []

  FOR each log_id in state.logs.step_responses:
    log = readLog(log_id)

    FOR each warning in log.warnings:
      aggregated_warnings.push({
        phase: log.phase,
        step_id: log.step_id,
        text: warning.text,
        severity: warning.severity,
        category: warning.category,
        analysis: log.warning_analysis,
        suggested_fix: warning.suggested_fix,
        timestamp: log.timestamp
      })

    FOR each error in log.errors:
      aggregated_errors.push({
        phase: log.phase,
        step_id: log.step_id,
        text: error.text,
        severity: error.severity,
        category: error.category,
        analysis: log.error_analysis,
        suggested_fix: error.suggested_fix,
        timestamp: log.timestamp
      })

  # Build workflow execution log
  workflow_log = {
    log_type: "workflow-execution",
    execution_id: generateUUID(),
    run_id: context.run_id,
    workflow_id: context.workflow_id,
    work_id: context.work_id,
    target: context.target,
    started_at: state.started_at,
    completed_at: getCurrentTimestamp(),
    duration_ms: calculateDuration(state.started_at),
    final_status: final_status,
    autonomy: context.autonomy,
    phases_summary: phases_summary,
    totals: state.response_totals,
    aggregated_warnings: aggregated_warnings,
    aggregated_errors: aggregated_errors,
    step_response_refs: state.logs.step_responses,
    artifacts: state.artifacts,
    recommended_actions: buildRecommendedActions(aggregated_warnings, aggregated_errors)
  }

  # Persist workflow execution log
  log_id = persistLog(workflow_log)

  # Update state with workflow execution log reference
  state.logs.workflow_execution = log_id
  writeState(context.run_id, state)

  RETURN workflow_log
```

---

## Error Handling

### Logging Failures

If log persistence fails, continue workflow:

```pseudocode
FUNCTION safelyPersistLog(log_entry):
  TRY
    RETURN persistLog(log_entry)
  CATCH error
    LOG "ERROR: Failed to persist log: {error.message}"
    LOG "Log entry: {JSON.stringify(log_entry)}"

    # Store in fallback location
    writeFallbackLog(log_entry)

    RETURN null
```

### Fallback Storage

```pseudocode
FUNCTION writeFallbackLog(log_entry):
  fallback_path = ".fractary/plugins/faber/runs/{run_id}/fallback-logs/"
  filename = "{log_entry.step_id}-{timestamp}.json"

  writeFile(fallback_path + filename, JSON.stringify(log_entry, null, 2))
```

---

## Integration Points

### Skills Used

- `fractary-logs:log-writer` - Persist log entries
- `faber-state` - Read/write workflow state
- `faber-config` - Get log type configuration

### Events Emitted

- `response_captured` - After each response is logged
- `limit_reached` - When global limits are hit
- `workflow_execution_logged` - After workflow summary is created
