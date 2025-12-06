# Autonomy Evaluation Logic

This document defines the evaluation logic for the two-dimensional autonomy model: check-in frequency and tolerance thresholds.

## Overview

The autonomy model controls two aspects of workflow execution:

1. **Check-in Frequency**: When the workflow pauses for user review
2. **Tolerance Thresholds**: What severity of issues to tolerate before stopping

---

## Configuration Loading

### Migration from Legacy Levels

When loading autonomy configuration, first check for legacy `level` field and migrate:

```pseudocode
FUNCTION loadAutonomyConfig(config):
  # Check for legacy level
  IF config.level exists AND config.check_in_frequency is null THEN
    # Migrate to new model
    migrated = migrateFromLegacy(config.level)
    LOG "Migrating legacy autonomy level '{config.level}' to new model"

    # Merge with any explicit new settings (explicit wins)
    RETURN {
      check_in_frequency: config.check_in_frequency ?? migrated.check_in_frequency,
      warning_tolerance: config.warning_tolerance ?? migrated.warning_tolerance,
      error_tolerance: config.error_tolerance ?? migrated.error_tolerance,
      limits: config.limits ?? DEFAULT_LIMITS
    }

  # Apply defaults for new model
  RETURN {
    check_in_frequency: config.check_in_frequency ?? "per-phase",
    warning_tolerance: config.warning_tolerance ?? "low",
    error_tolerance: config.error_tolerance ?? "none",
    limits: config.limits ?? DEFAULT_LIMITS
  }


FUNCTION migrateFromLegacy(level: string):
  SWITCH level:
    CASE "dry-run":
      RETURN {
        check_in_frequency: "per-step",
        warning_tolerance: "none",
        error_tolerance: "none"
      }

    CASE "assist":
      RETURN {
        check_in_frequency: "per-phase",
        warning_tolerance: "none",
        error_tolerance: "none"
      }

    CASE "guarded":
      RETURN {
        check_in_frequency: "per-phase",
        warning_tolerance: "low",
        error_tolerance: "none"
      }

    CASE "autonomous":
      RETURN {
        check_in_frequency: "end-only",
        warning_tolerance: "medium",
        error_tolerance: "low"
      }

    DEFAULT:
      # Unknown level, use safe defaults
      RETURN {
        check_in_frequency: "per-phase",
        warning_tolerance: "low",
        error_tolerance: "none"
      }
```

### Default Limits

```pseudocode
DEFAULT_LIMITS = {
  max_total_warnings: 50,
  max_total_errors: 20,
  on_limit_reached: "stop"
}
```

---

## Check-in Frequency Evaluation

### When to Check In

```pseudocode
FUNCTION shouldCheckIn(context):
  frequency = context.autonomy.check_in_frequency
  event_type = context.event_type  # "step_complete", "phase_complete", "workflow_complete"

  SWITCH frequency:
    CASE "per-step":
      # Check in after every step
      RETURN event_type == "step_complete"

    CASE "per-phase":
      # Check in after each phase
      RETURN event_type == "phase_complete"

    CASE "end-only":
      # Check in only at workflow end
      RETURN event_type == "workflow_complete"

  RETURN false
```

### Check-in Display

At each check-in point, display accumulated responses since last check-in:

```pseudocode
FUNCTION performCheckIn(context):
  # Get responses since last check-in
  responses = getResponsesSinceLastCheckIn(context.run_id, context.last_check_in_timestamp)

  # Aggregate warnings and errors
  warnings = aggregateWarnings(responses)
  errors = aggregateErrors(responses)

  # Build check-in report
  report = buildCheckInReport(
    phase: context.current_phase,
    step: context.current_step,
    warnings: warnings,
    errors: errors,
    artifacts: context.artifacts
  )

  # Display to user
  displayCheckInReport(report)

  # Ask for continuation
  IF warnings.count > 0 OR errors.count > 0 THEN
    response = AskUserQuestion:
      question: "Check-in: {context.current_phase} complete. Continue?"
      options:
        - "Continue"
        - "Review issues"
        - "Stop workflow"

    SWITCH response:
      CASE "Review issues":
        displayDetailedIssues(warnings, errors)
        # Ask again after review
        RETURN performCheckIn(context)
      CASE "Stop workflow":
        RETURN { action: "stop" }

  # Update last check-in timestamp
  updateLastCheckIn(context.run_id)

  RETURN { action: "continue" }
```

---

## Tolerance Evaluation

### Severity Comparison

Tolerance levels map to maximum tolerated severity:

| Tolerance | Tolerates Low | Tolerates Medium | Tolerates High |
|-----------|---------------|------------------|----------------|
| none      | No            | No               | No             |
| low       | Yes           | No               | No             |
| medium    | Yes           | Yes              | No             |
| high      | Yes           | Yes              | Yes            |

```pseudocode
FUNCTION severityExceedsTolerance(severity: string, tolerance: string): boolean
  severity_rank = getSeverityRank(severity)  # low=1, medium=2, high=3
  tolerance_rank = getToleranceRank(tolerance)  # none=0, low=1, medium=2, high=3

  RETURN severity_rank > tolerance_rank


FUNCTION getSeverityRank(severity: string): number
  SWITCH severity:
    CASE "low": RETURN 1
    CASE "medium": RETURN 2
    CASE "high": RETURN 3
    DEFAULT: RETURN 2  # Unknown defaults to medium


FUNCTION getToleranceRank(tolerance: string): number
  SWITCH tolerance:
    CASE "none": RETURN 0
    CASE "low": RETURN 1
    CASE "medium": RETURN 2
    CASE "high": RETURN 3
    DEFAULT: RETURN 1  # Unknown defaults to low
```

### Evaluating Response Against Tolerance

```pseudocode
FUNCTION evaluateResponse(response, autonomy):
  result = {
    should_stop: false,
    stop_reason: null,
    collected_warnings: [],
    collected_errors: []
  }

  # Process warnings
  FOR each warning in response.warnings:
    # Ensure warning has severity (auto-detect if needed)
    warning_obj = normalizeWarning(warning)

    IF severityExceedsTolerance(warning_obj.severity, autonomy.warning_tolerance) THEN
      # Warning exceeds tolerance - trigger result_handling
      result.should_stop = true
      result.stop_reason = "Warning exceeds tolerance: " + warning_obj.text
      result.exceeds_warning = warning_obj
    ELSE
      # Within tolerance - collect for report
      result.collected_warnings.push(warning_obj)

  # Process errors
  FOR each error in response.errors:
    # Ensure error has severity (auto-detect if needed)
    error_obj = normalizeError(error)

    IF severityExceedsTolerance(error_obj.severity, autonomy.error_tolerance) THEN
      # Error exceeds tolerance - stop
      result.should_stop = true
      result.stop_reason = "Error exceeds tolerance: " + error_obj.text
      result.exceeds_error = error_obj
    ELSE
      # Within tolerance - collect for report
      result.collected_errors.push(error_obj)

  RETURN result
```

### Integration with Result Handling

Tolerance evaluation integrates with existing result_handling configuration:

```pseudocode
FUNCTION handleStepResult(step, result, autonomy):
  # First: evaluate against tolerance
  tolerance_result = evaluateResponse(result, autonomy)

  IF tolerance_result.should_stop THEN
    # Issue exceeds tolerance - apply result_handling behavior
    IF tolerance_result.exceeds_error THEN
      # Error case - always stop for steps
      RETURN applyResultHandling(result, step.result_handling, "on_failure")
    ELSE IF tolerance_result.exceeds_warning THEN
      # Warning case - check result_handling config
      RETURN applyResultHandling(result, step.result_handling, "on_warning")

  # All issues within tolerance
  # Collect for end-of-workflow report
  collectResponses(tolerance_result.collected_warnings, tolerance_result.collected_errors)

  # Check if we should check-in based on frequency
  IF shouldCheckIn(context) THEN
    RETURN performCheckIn(context)

  # Continue to next step
  RETURN { action: "continue" }
```

---

## Global Limits

### Tracking Totals

```pseudocode
FUNCTION trackGlobalLimits(run_id, warnings, errors, limits):
  # Get current totals from state
  state = readState(run_id)
  current_warnings = state.response_totals.warnings ?? 0
  current_errors = state.response_totals.errors ?? 0

  # Add new items
  new_warning_count = current_warnings + warnings.length
  new_error_count = current_errors + errors.length

  # Check limits
  warning_limit_reached = new_warning_count >= limits.max_total_warnings
  error_limit_reached = new_error_count >= limits.max_total_errors

  IF warning_limit_reached OR error_limit_reached THEN
    limit_type = warning_limit_reached ? "warnings" : "errors"
    limit_value = warning_limit_reached ? limits.max_total_warnings : limits.max_total_errors

    IF limits.on_limit_reached == "stop" THEN
      RETURN {
        action: "stop",
        reason: "Global limit reached: {new_count}/{limit_value} {limit_type}"
      }
    ELSE  # "truncate"
      LOG "Limit reached, truncating collection: {limit_type}"
      # Continue but stop collecting new items
      RETURN {
        action: "continue",
        truncated: true,
        truncated_type: limit_type
      }

  # Update state with new totals
  updateState(run_id, {
    response_totals: {
      warnings: new_warning_count,
      errors: new_error_count
    }
  })

  RETURN { action: "continue" }
```

---

## Phase Overrides

Phases can override global autonomy settings:

```pseudocode
FUNCTION getPhaseAutonomy(global_autonomy, phase):
  IF global_autonomy.overrides is null THEN
    RETURN global_autonomy

  phase_override = global_autonomy.overrides[phase]
  IF phase_override is null THEN
    RETURN global_autonomy

  # Merge override with global (override wins)
  RETURN {
    check_in_frequency: phase_override.check_in_frequency ?? global_autonomy.check_in_frequency,
    warning_tolerance: phase_override.warning_tolerance ?? global_autonomy.warning_tolerance,
    error_tolerance: phase_override.error_tolerance ?? global_autonomy.error_tolerance,
    limits: global_autonomy.limits  # Limits are always global
  }
```

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
- Evaluate phase: Check in per-step, don't tolerate any warnings

---

## Complete Evaluation Flow

```pseudocode
FUNCTION evaluateStepCompletion(step, result, context):
  # 1. Get effective autonomy for this phase
  autonomy = getPhaseAutonomy(context.global_autonomy, context.current_phase)

  # 2. Normalize response (add severity/category if missing)
  normalized = normalizeResponse(result)

  # 3. Evaluate against tolerance
  tolerance_result = evaluateResponse(normalized, autonomy)

  # 4. Check global limits
  limits_result = trackGlobalLimits(
    context.run_id,
    tolerance_result.collected_warnings,
    tolerance_result.collected_errors,
    autonomy.limits
  )

  IF limits_result.action == "stop" THEN
    RETURN { action: "stop", reason: limits_result.reason }

  # 5. Handle tolerance violations
  IF tolerance_result.should_stop THEN
    # Apply result_handling behavior
    RETURN handleToleranceViolation(step, result, tolerance_result)

  # 6. Log response to fractary-logs
  logStepResponse(context.run_id, step, normalized)

  # 7. Check if check-in needed
  IF shouldCheckIn(context) THEN
    check_in_result = performCheckIn(context)
    IF check_in_result.action == "stop" THEN
      RETURN check_in_result

  # 8. Continue to next step
  RETURN { action: "continue" }
```

---

## Examples

### Example 1: Low Warning with Low Tolerance

```
Config: warning_tolerance = "low"
Warning: { severity: "low", text: "Style issue" }
Result: CONTINUE (low <= low, within tolerance)
```

### Example 2: Medium Warning with Low Tolerance

```
Config: warning_tolerance = "low"
Warning: { severity: "medium", text: "Deprecated API" }
Result: STOP (medium > low, exceeds tolerance)
```

### Example 3: High Error with Low Tolerance

```
Config: error_tolerance = "low"
Error: { severity: "high", text: "Security vulnerability" }
Result: STOP (high > low, exceeds tolerance)
```

### Example 4: Low Error with None Tolerance

```
Config: error_tolerance = "none"
Error: { severity: "low", text: "Minor validation error" }
Result: STOP (low > none, exceeds tolerance)
```

### Example 5: Per-Phase Check-in

```
Config: check_in_frequency = "per-phase"
Event: phase_complete (architect)
Result: PAUSE for check-in, show accumulated issues
```
