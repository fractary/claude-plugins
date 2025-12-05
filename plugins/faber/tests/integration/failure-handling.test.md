# FABER Failure Handling Integration Tests

This document defines integration test scenarios for validating FABER workflow failure handling.

## Test Categories

1. **Result Validation Tests** - Verify result object validation
2. **State Update Error Tests** - Verify state update failure handling
3. **Placeholder Validation Tests** - Verify argument placeholder resolution
4. **Workflow Stop Tests** - Verify workflow stops on failure

---

## Test 1: Result Validation - Null Result

**Scenario**: Step returns null result

**Setup**:
```json
{
  "workflow_id": "test-null-result",
  "phases": {
    "build": {
      "enabled": true,
      "steps": [
        {
          "name": "null-returning-step",
          "prompt": "Return nothing (simulates a broken step)"
        }
      ]
    }
  }
}
```

**Expected Behavior**:
- Result validation catches null result
- Result is transformed to failure with message "Step returned null or undefined result"
- Workflow stops immediately
- State shows step as "failed"

**Verification**:
```bash
# Check state.json shows failure
jq '.phases.build.steps["null-returning-step"].status' .fractary/plugins/faber/runs/{run_id}/state.json
# Expected: "failed"

# Check error message
jq '.phases.build.steps["null-returning-step"].result.errors[0]' .fractary/plugins/faber/runs/{run_id}/state.json
# Expected: Contains "did not return a valid result object"
```

---

## Test 2: Result Validation - Invalid Status

**Scenario**: Step returns result with invalid status value

**Setup**:
```json
{
  "test_step_return": {
    "status": "completed",  // Invalid - should be success/warning/failure
    "message": "Done"
  }
}
```

**Expected Behavior**:
- Result validation catches invalid status
- Result is transformed to failure with message "Step returned invalid result structure"
- Error includes the invalid status value for debugging
- Workflow stops immediately

**Verification**:
```bash
# Check error contains the invalid status
jq '.phases.build.steps["test-step"].result.errors[0]' .fractary/plugins/faber/runs/{run_id}/state.json
# Expected: Contains "without valid status field. Got: \"completed\""
```

---

## Test 3: Result Validation - Failure Without Errors Array

**Scenario**: Step returns failure status but no errors array

**Setup**:
```json
{
  "test_step_return": {
    "status": "failure",
    "message": "Something went wrong"
    // Note: missing "errors" array
  }
}
```

**Expected Behavior**:
- Result validation adds default errors array
- errors = ["Step failed without error details"]
- Workflow stops (failure always stops)

**Verification**:
```bash
# Check default error was added
jq '.phases.build.steps["test-step"].result.errors' .fractary/plugins/faber/runs/{run_id}/state.json
# Expected: ["Step failed without error details"]
```

---

## Test 4: State Update Failure Handling

**Scenario**: State file becomes corrupted or inaccessible

**Setup**:
1. Start a workflow
2. Make state.json read-only mid-execution
```bash
chmod 444 .fractary/plugins/faber/runs/{run_id}/state.json
```

**Expected Behavior**:
- State update fails
- Recovery is attempted via verify-state-integrity
- If recovery fails, workflow aborts with clear error
- Error includes recovery hint about checking state.json

**Verification**:
```bash
# Check workflow output contains recovery hint
# Expected: Contains "Check .fractary/plugins/faber/runs/{run_id}/state.json and restore from backup if needed"
```

---

## Test 5: Placeholder Validation - Undefined Placeholder

**Scenario**: Step arguments reference a placeholder that doesn't exist in context

**Setup**:
```json
{
  "workflow_id": "test-undefined-placeholder",
  "phases": {
    "build": {
      "enabled": true,
      "steps": [
        {
          "name": "deploy-step",
          "skill": "fractary-deploy:deployer",
          "arguments": {
            "environment": "{target_env}",  // This placeholder doesn't exist
            "version": "{app_version}"      // This one either
          }
        }
      ]
    }
  }
}
```

**Context provided**:
```json
{
  "work_id": "123",
  "target": "my-app"
  // Note: target_env and app_version NOT in context
}
```

**Expected Behavior**:
- Placeholder validation fails for both undefined placeholders
- Error message lists all undefined placeholders
- Error includes available context keys for debugging
- Step fails before execution (no partial execution)
- Workflow stops

**Verification**:
```bash
# Check validation errors are specific
jq '.phases.build.steps["deploy-step"].result.errors' .fractary/plugins/faber/runs/{run_id}/state.json
# Expected: Array containing errors for both "target_env" and "app_version"

# Check available keys are listed
jq '.phases.build.steps["deploy-step"].result.details.available_context_keys' .fractary/plugins/faber/runs/{run_id}/state.json
# Expected: ["work_id", "target", ...]
```

---

## Test 6: Workflow Stops on Step Failure

**Scenario**: A step fails and workflow should stop immediately without executing subsequent steps

**Setup**:
```json
{
  "workflow_id": "test-stop-on-failure",
  "phases": {
    "build": {
      "enabled": true,
      "steps": [
        {
          "name": "step-1-succeeds",
          "prompt": "Do something that succeeds"
        },
        {
          "name": "step-2-fails",
          "prompt": "Do something that fails"
        },
        {
          "name": "step-3-never-runs",
          "prompt": "This should never execute"
        }
      ]
    }
  }
}
```

**Expected Behavior**:
- step-1-succeeds: status = "completed"
- step-2-fails: status = "failed"
- step-3-never-runs: status = "pending" (never executed)
- Workflow status = "failed"
- failed_at = "build:step-2-fails"

**Verification**:
```bash
# Check step-3 was never executed
jq '.phases.build.steps["step-3-never-runs"].status' .fractary/plugins/faber/runs/{run_id}/state.json
# Expected: "pending"

# Check workflow failed_at
jq '.failed_at' .fractary/plugins/faber/runs/{run_id}/state.json
# Expected: "build:step-2-fails"
```

---

## Test 7: Resume After Failure

**Scenario**: Workflow can be resumed from the failed step after fixing the issue

**Setup**:
1. Run workflow that fails at step-2
2. Fix the underlying issue
3. Resume with `--resume {run_id}`

**Expected Behavior**:
- Resume loads existing state
- Skips already-completed step-1
- Re-executes step-2 (now fixed)
- Continues to step-3
- Workflow completes successfully

**Verification**:
```bash
# After resume, check all steps completed
jq '.phases.build.steps | to_entries | map(.value.status)' .fractary/plugins/faber/runs/{run_id}/state.json
# Expected: ["completed", "completed", "completed"]
```

---

## Running These Tests

### Manual Testing
```bash
# Test 1-3: Result validation
/fractary-faber:run "test-target" --workflow test-null-result --work-id 999

# Test 5: Placeholder validation
/fractary-faber:run "test-target" --workflow test-undefined-placeholder --work-id 999

# Test 6: Stop on failure
/fractary-faber:run "test-target" --workflow test-stop-on-failure --work-id 999

# Test 7: Resume
/fractary-faber:run "test-target" --resume {run_id}
```

### Automated Testing (Future)
These tests should be automated using:
1. Mock skill responses
2. State file inspection
3. Workflow execution simulation

---

## Success Criteria

All tests pass when:
1. Result validation catches all invalid result structures
2. State update failures are handled gracefully with recovery hints
3. Undefined placeholders are caught before step execution
4. Workflows stop immediately on failure (no subsequent steps run)
5. Resume capability works correctly after fixing issues
